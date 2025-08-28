# SelectoComponents URL Shortening Plan

## Overview
Currently SelectoComponents uses UUIDs for filter sets in URLs, creating long and unwieldy URLs. This plan outlines an approach to shorten URLs by replacing UUIDs with more compact, human-readable identifiers while maintaining functionality and avoiding collisions.

## Current State Analysis

### Current URL Structure
```
/pagila?view_type=aggregate&filter_set_id=550e8400-e29b-41d4-a716-446655440000&domain=PagilaDomain
```

### Problems with Current Approach
- URLs are extremely long (36+ characters just for UUID)
- Not human-readable or memorable
- Difficult to share or communicate verbally
- Poor SEO and analytics tracking
- Challenges with URL length limits in some contexts

## Proposed Solution: Hierarchical Short IDs

### New URL Structure Options

**Option 1: Base62 Encoding**
```
/pagila?view_type=aggregate&fs=7kxM2p&domain=PagilaDomain
```

**Option 2: Contextual Short IDs**
```
/pagila?view_type=aggregate&fs=film-ratings-2024&domain=PagilaDomain
```

**Option 3: Hybrid Approach (Recommended)**
```
/pagila?view_type=aggregate&fs=fr24-7kx&domain=PagilaDomain
```

## Implementation Strategy

### Phase 1: Short ID Generation System

#### 1.1 Base62 Encoder/Decoder
```elixir
defmodule SelectoComponents.ShortId do
  @alphabet "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
  @base 62

  def encode(number) when is_integer(number) do
    encode(number, "")
  end

  defp encode(0, acc), do: if(acc == "", do: "0", else: acc)
  defp encode(number, acc) do
    remainder = rem(number, @base)
    char = String.at(@alphabet, remainder)
    encode(div(number, @base), char <> acc)
  end

  def decode(string) do
    string
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.with_index()
    |> Enum.reduce(0, fn {char, index}, acc ->
      position = :binary.match(@alphabet, char) |> elem(0)
      acc + position * :math.pow(@base, index)
    end)
    |> trunc()
  end

  def generate_short_id(filter_set_id) when is_binary(filter_set_id) do
    filter_set_id
    |> String.replace("-", "")
    |> String.slice(0, 8)
    |> Integer.parse(16)
    |> elem(0)
    |> encode()
  end
end
```

#### 1.2 Context-Aware Prefixes
```elixir
defmodule SelectoComponents.ContextPrefix do
  @domain_prefixes %{
    "PagilaDomain" => "pg",
    "PagilaDomainFilms" => "pf",
    "BlogDomain" => "bg",
    "TestDomain" => "ts"
  }

  @view_type_prefixes %{
    "aggregate" => "a",
    "detail" => "d",
    "graph" => "g"
  }

  def generate_prefix(domain, view_type, filter_context \\ nil) do
    domain_prefix = @domain_prefixes[domain] || "gn"
    view_prefix = @view_type_prefixes[view_type] || "v"
    
    context_prefix = case filter_context do
      %{primary_filter: filter} when is_binary(filter) ->
        filter |> String.slice(0, 2) |> String.downcase()
      _ -> ""
    end

    "#{domain_prefix}#{view_prefix}#{context_prefix}"
  end
end
```

### Phase 2: URL Management System

#### 2.1 Short URL Registry
```elixir
defmodule SelectoComponents.ShortUrlRegistry do
  use GenServer
  
  # ETS table for fast lookups
  @table :short_url_registry

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    :ets.new(@table, [:named_table, :public, read_concurrency: true])
    {:ok, %{}}
  end

  def register_filter_set(filter_set_id, context) do
    short_id = generate_unique_short_id(filter_set_id, context)
    :ets.insert(@table, {short_id, filter_set_id})
    :ets.insert(@table, {filter_set_id, short_id})
    short_id
  end

  def lookup_filter_set(short_id) do
    case :ets.lookup(@table, short_id) do
      [{^short_id, filter_set_id}] -> {:ok, filter_set_id}
      [] -> {:error, :not_found}
    end
  end

  def lookup_short_id(filter_set_id) do
    case :ets.lookup(@table, filter_set_id) do
      [{^filter_set_id, short_id}] -> {:ok, short_id}
      [] -> {:error, :not_found}
    end
  end

  defp generate_unique_short_id(filter_set_id, context, attempt \\ 0) do
    base_short_id = SelectoComponents.ShortId.generate_short_id(filter_set_id)
    prefix = SelectoComponents.ContextPrefix.generate_prefix(
      context.domain, 
      context.view_type, 
      context.filter_context
    )
    
    suffix = if attempt > 0, do: "-#{attempt}", else: ""
    candidate = "#{prefix}-#{base_short_id}#{suffix}"

    case :ets.lookup(@table, candidate) do
      [] -> candidate
      _ -> generate_unique_short_id(filter_set_id, context, attempt + 1)
    end
  end
end
```

#### 2.2 URL Parameter Shortening
```elixir
defmodule SelectoComponents.UrlShortener do
  @param_mappings %{
    "view_type" => "vt",
    "filter_set_id" => "fs",
    "domain" => "d",
    "aggregate_by" => "ab",
    "sort_by" => "sb",
    "sort_direction" => "sd",
    "page" => "p",
    "per_page" => "pp"
  }

  def shorten_params(params) do
    params
    |> Enum.map(fn {key, value} -> 
      short_key = @param_mappings[key] || key
      {short_key, shorten_value(key, value)}
    end)
    |> Enum.into(%{})
  end

  def expand_params(params) do
    reverse_mappings = Enum.map(@param_mappings, fn {k, v} -> {v, k} end) |> Enum.into(%{})
    
    params
    |> Enum.map(fn {key, value} -> 
      long_key = reverse_mappings[key] || key
      {long_key, expand_value(long_key, value)}
    end)
    |> Enum.into(%{})
  end

  defp shorten_value("filter_set_id", uuid) when is_binary(uuid) do
    case SelectoComponents.ShortUrlRegistry.lookup_short_id(uuid) do
      {:ok, short_id} -> short_id
      {:error, :not_found} -> uuid
    end
  end

  defp shorten_value(_key, value), do: value

  defp expand_value("filter_set_id", short_id) when is_binary(short_id) do
    case SelectoComponents.ShortUrlRegistry.lookup_filter_set(short_id) do
      {:ok, filter_set_id} -> filter_set_id
      {:error, :not_found} -> short_id
    end
  end

  defp expand_value(_key, value), do: value
end
```

### Phase 3: LiveView Integration

#### 3.1 Modified Route Handling
```elixir
defmodule SelectoTestWeb.PagilaLive do
  use SelectoTestWeb, :live_view

  def mount(params, _session, socket) do
    # Expand shortened parameters
    expanded_params = SelectoComponents.UrlShortener.expand_params(params)
    
    # Existing mount logic with expanded_params
    {:ok, assign(socket, :params, expanded_params)}
  end

  def handle_params(params, uri, socket) do
    # Expand parameters before processing
    expanded_params = SelectoComponents.UrlShortener.expand_params(params)
    
    # Register new filter sets with short IDs
    if expanded_params["filter_set_id"] do
      context = build_context(expanded_params)
      SelectoComponents.ShortUrlRegistry.register_filter_set(
        expanded_params["filter_set_id"], 
        context
      )
    end
    
    # Continue with existing logic
    handle_expanded_params(expanded_params, uri, socket)
  end

  defp build_context(params) do
    %{
      domain: params["domain"],
      view_type: params["view_type"],
      filter_context: extract_filter_context(params)
    }
  end
end
```

#### 3.2 URL Generation Helper
```elixir
defmodule SelectoComponents.UrlHelper do
  def build_short_url(base_path, params, context \\ %{}) do
    # Register filter set if present
    params_with_short_ids = case params["filter_set_id"] do
      nil -> params
      filter_set_id ->
        short_id = SelectoComponents.ShortUrlRegistry.register_filter_set(
          filter_set_id, 
          context
        )
        Map.put(params, "filter_set_id", short_id)
    end
    
    # Shorten all parameters
    short_params = SelectoComponents.UrlShortener.shorten_params(params_with_short_ids)
    
    # Build query string
    query_string = URI.encode_query(short_params)
    "#{base_path}?#{query_string}"
  end

  def parse_short_url(url) do
    uri = URI.parse(url)
    params = URI.decode_query(uri.query || "")
    SelectoComponents.UrlShortener.expand_params(params)
  end
end
```

### Phase 4: Backward Compatibility

#### 4.1 UUID Fallback System
```elixir
defmodule SelectoComponents.BackwardCompatibility do
  def is_uuid?(string) do
    case Ecto.UUID.cast(string) do
      {:ok, _} -> true
      :error -> false
    end
  end

  def handle_filter_set_param(param) do
    cond do
      is_uuid?(param) -> 
        # Legacy UUID - use as is
        {:uuid, param}
      
      String.contains?(param, "-") && String.length(param) < 20 ->
        # Short ID format
        case SelectoComponents.ShortUrlRegistry.lookup_filter_set(param) do
          {:ok, uuid} -> {:short_id, uuid}
          {:error, :not_found} -> {:invalid, param}
        end
      
      true ->
        {:invalid, param}
    end
  end
end
```

## Testing Strategy

### Unit Tests
```elixir
defmodule SelectoComponents.ShortIdTest do
  use ExUnit.Case

  describe "encode/decode" do
    test "round trip encoding" do
      number = 12345678
      encoded = SelectoComponents.ShortId.encode(number)
      decoded = SelectoComponents.ShortId.decode(encoded)
      assert decoded == number
    end

    test "generates shorter strings than UUIDs" do
      uuid = "550e8400-e29b-41d4-a716-446655440000"
      short_id = SelectoComponents.ShortId.generate_short_id(uuid)
      assert String.length(short_id) < 10
    end
  end
end

defmodule SelectoComponents.UrlShortenerTest do
  use ExUnit.Case

  test "shortens and expands parameters" do
    original_params = %{
      "view_type" => "aggregate",
      "filter_set_id" => "550e8400-e29b-41d4-a716-446655440000",
      "domain" => "PagilaDomain"
    }

    shortened = SelectoComponents.UrlShortener.shorten_params(original_params)
    expanded = SelectoComponents.UrlShortener.expand_params(shortened)

    # Keys should be shortened
    assert Map.has_key?(shortened, "vt")
    assert Map.has_key?(shortened, "fs")
    assert Map.has_key?(shortened, "d")

    # Expansion should restore original structure
    assert expanded["view_type"] == "aggregate"
    assert expanded["domain"] == "PagilaDomain"
  end
end
```

### Integration Tests
```elixir
defmodule SelectoTestWeb.ShortUrlIntegrationTest do
  use SelectoTestWeb.ConnCase, async: false

  test "short URLs work end-to-end", %{conn: conn} do
    # Create a filter set
    filter_set_id = Ecto.UUID.generate()
    
    # Build short URL
    context = %{domain: "PagilaDomain", view_type: "aggregate"}
    short_url = SelectoComponents.UrlHelper.build_short_url(
      "/pagila",
      %{"filter_set_id" => filter_set_id, "view_type" => "aggregate"},
      context
    )
    
    # Short URL should be significantly shorter
    assert String.length(short_url) < 100
    
    # Accessing short URL should work
    conn = get(conn, short_url)
    assert html_response(conn, 200)
  end
end
```

## Migration Strategy

### Phase A: Dual System Support (Weeks 1-2)
- Implement short ID generation alongside existing UUIDs
- Add URL shortening as opt-in feature
- Maintain full backward compatibility

### Phase B: Progressive Adoption (Weeks 3-4)
- Enable short URLs by default for new filter sets
- Add UI toggle for URL format preference
- Monitor performance and collision rates

### Phase C: Legacy Migration (Weeks 5-6)
- Migrate existing saved views to short URLs
- Deprecation warnings for long URL usage
- Performance optimization and cleanup

## Success Metrics

### URL Length Reduction
- **Target**: 60-80% reduction in URL length
- **Measurement**: Average character count comparison
- **Baseline**: Current URLs ~120-150 characters
- **Goal**: Short URLs ~30-50 characters

### Performance Impact
- **Target**: < 5ms overhead for URL processing
- **Measurement**: Response time monitoring
- **Registry Lookup**: < 1ms average
- **Memory Usage**: < 10MB for registry

### User Experience
- **URL Shareability**: User feedback on URL sharing
- **Copy/Paste Success**: Reduced truncation issues
- **Analytics Tracking**: Improved URL categorization

### System Reliability
- **Collision Rate**: < 0.01% short ID collisions
- **Backward Compatibility**: 100% legacy URL support
- **Registry Availability**: 99.9% uptime target

## Future Enhancements

### Custom Short IDs
Allow users to define memorable aliases:
```
/pagila?fs=my-favorite-films&vt=a&d=pf
```

### QR Code Integration
Generate QR codes for easy mobile sharing:
```elixir
defmodule SelectoComponents.QRCode do
  def generate_qr_url(short_url) do
    # Generate QR code for the short URL
  end
end
```

### Analytics Integration
Track URL usage patterns:
```elixir
defmodule SelectoComponents.UrlAnalytics do
  def track_url_usage(short_id, user_agent, referrer) do
    # Track usage metrics
  end
end
```

## Implementation Timeline

**Week 1**: Core short ID system and registry
**Week 2**: LiveView integration and URL helpers  
**Week 3**: Testing and backward compatibility
**Week 4**: Performance optimization and monitoring
**Week 5**: Documentation and migration tools
**Week 6**: Production deployment and validation

## Conclusion

This plan provides a comprehensive approach to shortening SelectoComponents URLs while maintaining functionality, performance, and backward compatibility. The hierarchical short ID system offers significant URL length reduction while providing context-aware organization and collision avoidance.