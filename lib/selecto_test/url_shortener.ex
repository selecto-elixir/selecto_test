defmodule SelectoTest.UrlShortener do
  @moduledoc """
  URL shortening service for sharing complex view configurations.
  Generates short codes and manages URL mappings with expiration.
  """

  alias SelectoTest.Repo
  alias SelectoTest.ShortenedUrl
  import Ecto.Query

  @short_code_length 8
  @default_expiry_days 30

  @doc """
  Generates a short URL for the given long URL.
  """
  def shorten(long_url, opts \\ []) do
    custom_code = Keyword.get(opts, :custom_code)
    expires_at = calculate_expiry(Keyword.get(opts, :expires_in_days, @default_expiry_days))
    metadata = Keyword.get(opts, :metadata, %{})

    with {:ok, validated_url} <- validate_url(long_url),
         code <- generate_code(custom_code),
         {:ok, shortened} <- create_shortened_url(code, validated_url, expires_at, metadata) do
      {:ok, shortened}
    end
  end

  @doc """
  Resolves a short code to its original URL.
  """
  def resolve(short_code) do
    query =
      from s in ShortenedUrl,
        where: s.short_code == ^short_code,
        where: s.expires_at > ^DateTime.utc_now() or is_nil(s.expires_at)

    case Repo.one(query) do
      nil ->
        {:error, :not_found}

      shortened ->
        # Update click count
        Repo.update_all(
          from(s in ShortenedUrl, where: s.id == ^shortened.id),
          inc: [click_count: 1],
          set: [last_accessed_at: DateTime.utc_now()]
        )

        {:ok, shortened}
    end
  end

  @doc """
  Generates multiple short URLs in bulk.
  """
  def bulk_shorten(urls, opts \\ []) do
    expires_at = calculate_expiry(Keyword.get(opts, :expires_in_days, @default_expiry_days))

    urls
    |> Enum.map(fn url ->
      case validate_url(url) do
        {:ok, validated_url} ->
          %{
            short_code: generate_code(nil),
            long_url: validated_url,
            expires_at: expires_at,
            click_count: 0,
            inserted_at: DateTime.utc_now(),
            updated_at: DateTime.utc_now()
          }

        {:error, _} ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> case do
      [] ->
        {:error, :no_valid_urls}

      valid_urls ->
        {count, urls} = Repo.insert_all(ShortenedUrl, valid_urls, returning: true)
        {:ok, urls}
    end
  end

  @doc """
  Generates a QR code for the given short code.
  """
  def generate_qr_code(short_code, base_url) do
    short_url = "#{base_url}/s/#{short_code}"
    
    qr_code = short_url |> EQRCode.encode() |> EQRCode.svg(width: 200)
    
    {:ok, qr_code}
  rescue
    _ -> {:error, :qr_generation_failed}
  end

  @doc """
  Gets analytics for a short URL.
  """
  def get_analytics(short_code) do
    query =
      from s in ShortenedUrl,
        where: s.short_code == ^short_code

    case Repo.one(query) do
      nil ->
        {:error, :not_found}

      shortened ->
        analytics = %{
          short_code: shortened.short_code,
          long_url: shortened.long_url,
          created_at: shortened.inserted_at,
          expires_at: shortened.expires_at,
          click_count: shortened.click_count,
          last_accessed_at: shortened.last_accessed_at,
          metadata: shortened.metadata
        }

        {:ok, analytics}
    end
  end

  @doc """
  Cleans up expired URLs.
  """
  def cleanup_expired do
    query =
      from s in ShortenedUrl,
        where: s.expires_at < ^DateTime.utc_now()

    {count, _} = Repo.delete_all(query)
    {:ok, count}
  end

  @doc """
  Validates a custom short code is available.
  """
  def validate_custom_code(code) do
    query =
      from s in ShortenedUrl,
        where: s.short_code == ^code

    case Repo.one(query) do
      nil -> {:ok, code}
      _ -> {:error, :code_taken}
    end
  end

  # Private functions

  defp validate_url(url) when is_binary(url) do
    uri = URI.parse(url)

    if uri.scheme in ["http", "https"] and uri.host do
      {:ok, url}
    else
      {:error, :invalid_url}
    end
  end

  defp validate_url(_), do: {:error, :invalid_url}

  defp generate_code(nil) do
    code = :crypto.strong_rand_bytes(@short_code_length)
           |> Base.url_encode64()
           |> binary_part(0, @short_code_length)

    # Check for collision
    case Repo.get_by(ShortenedUrl, short_code: code) do
      nil -> code
      _ -> generate_code(nil)  # Regenerate if collision
    end
  end

  defp generate_code(custom_code) when is_binary(custom_code) do
    # Sanitize custom code
    String.replace(custom_code, ~r/[^a-zA-Z0-9_-]/, "")
  end

  defp calculate_expiry(nil), do: nil
  defp calculate_expiry(days) when is_integer(days) do
    DateTime.utc_now()
    |> DateTime.add(days * 24 * 60 * 60, :second)
  end

  defp create_shortened_url(code, long_url, expires_at, metadata) do
    %ShortenedUrl{}
    |> ShortenedUrl.changeset(%{
      short_code: code,
      long_url: long_url,
      expires_at: expires_at,
      metadata: metadata,
      click_count: 0
    })
    |> Repo.insert()
  end
end