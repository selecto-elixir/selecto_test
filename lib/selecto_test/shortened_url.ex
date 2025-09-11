defmodule SelectoTest.ShortenedUrl do
  @moduledoc """
  Schema for shortened URLs with analytics and expiration.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "shortened_urls" do
    field :short_code, :string
    field :long_url, :string
    field :expires_at, :utc_datetime
    field :click_count, :integer, default: 0
    field :last_accessed_at, :utc_datetime
    field :metadata, :map, default: %{}
    field :creator_id, :binary_id
    field :is_public, :boolean, default: true

    timestamps()
  end

  @required_fields [:short_code, :long_url]
  @optional_fields [:expires_at, :click_count, :last_accessed_at, :metadata, :creator_id, :is_public]

  @doc false
  def changeset(shortened_url, attrs) do
    shortened_url
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:short_code, min: 3, max: 50)
    |> validate_format(:short_code, ~r/^[a-zA-Z0-9_-]+$/)
    |> unique_constraint(:short_code)
    |> validate_url(:long_url)
  end

  defp validate_url(changeset, field) do
    validate_change(changeset, field, fn _, value ->
      uri = URI.parse(value)
      
      if uri.scheme in ["http", "https"] and uri.host do
        []
      else
        [{field, "must be a valid HTTP(S) URL"}]
      end
    end)
  end
end