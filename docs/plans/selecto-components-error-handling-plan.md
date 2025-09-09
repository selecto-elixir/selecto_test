# SelectoComponents Enhanced Error Handling Plan

## Overview

Implement comprehensive error reporting and handling in SelectoComponents to provide clear feedback when queries fail, with detailed debugging information in development environments and user-friendly messages in production.

## Current State Analysis

### Existing Error Handling Limitations
- Basic error display with minimal information
- No distinction between development and production error messages
- Limited error context (no SQL query, parameters, or stack traces shown)
- Generic error messages that don't help users understand what went wrong
- No retry mechanisms for transient errors
- Poor visibility of error states in the UI

### Current Error Display
The existing error display in `form.ex` shows:
- Basic error message
- Some details in dev mode (query, params)
- Red background alert box

## Requirements

### User Experience Requirements
1. **Clear Error Indication**
   - Prominent visual indication when ANY error occurs
   - Error state should be immediately obvious
   - Preserve user's work/configuration when errors occur
   - Show errors for all failure points, not just query execution

2. **Informative Error Messages**
   - User-friendly explanations of what went wrong
   - Actionable suggestions for resolution
   - Different messaging for dev vs production environments
   - Clear indication of error source (query, rendering, data processing, etc.)

3. **Error Recovery**
   - Allow users to retry failed operations
   - Preserve form state during errors
   - Provide alternative actions when appropriate
   - Graceful degradation when possible

### Technical Requirements
1. **Development Environment**
   - Full error details for ALL error types
   - Complete stack traces
   - Component state at time of error
   - Data processing errors
   - Rendering errors
   - LiveView lifecycle errors
   - Full SQL query display (when applicable)
   - Query parameters
   - Database error details
   - Execution timing information
   - Connection details

2. **Production Environment**
   - Sanitized error messages
   - No sensitive information exposure
   - Generic but helpful user messages
   - Error tracking/logging capabilities
   - Acknowledgment of error occurrence

3. **Error Categorization**
   - **Query Errors:**
     - Connection errors
     - Query syntax errors
     - Permission/authorization errors
     - Timeout errors
     - Resource limit errors
   - **Data Processing Errors:**
     - Data transformation failures
     - Encoding/decoding errors
     - Type conversion errors
     - Aggregation errors
     - Subselect processing errors
   - **Rendering Errors:**
     - Component initialization failures
     - Template rendering errors
     - JavaScript hook errors
     - Asset loading failures
   - **LiveView Errors:**
     - Socket connection errors
     - Event handling failures
     - State management errors
     - Navigation errors
   - **Configuration Errors:**
     - Invalid domain configuration
     - Missing required parameters
     - Invalid view configuration
     - Schema mismatch errors

## Architecture Design

### Domain Configuration for Query Display

```elixir
# In domain configuration (e.g., PagilaDomain)
defmodule MyApp.Domains.PagilaDomain do
  use Selecto.Domain
  
  # New debug configuration options
  def debug_config do
    %{
      # Control query/params display in dev mode
      show_query: true,           # Show SQL queries (default: true in dev)
      show_params: true,          # Show query parameters (default: true in dev)
      show_timing: true,          # Show execution timing (default: true)
      show_row_count: true,       # Show result row counts (default: true)
      
      # Advanced debug options
      show_query_plan: false,     # Show EXPLAIN output (default: false)
      show_stack_trace: true,     # Show stack traces on errors (default: true in dev)
      show_component_state: true, # Show component state on errors (default: true in dev)
      
      # Query display formatting
      format_sql: true,           # Pretty-print SQL (default: true)
      truncate_params: 100,       # Max length for param display (nil = no truncation)
      
      # Control per view type
      view_debug: %{
        aggregate: %{show_query: true, show_params: true},
        detail: %{show_query: true, show_params: false},
        graph: %{show_query: false, show_params: false}
      }
    }
  end
  
  # Alternative: Simple toggle
  def debug_config do
    %{
      debug_mode: :full,  # :full, :minimal, :off
      # :full - Show everything
      # :minimal - Show errors only
      # :off - No debug info even in dev
    }
  end
end
```

### Component Structure
```
vendor/selecto_components/lib/selecto_components/
├── error_handling/
│   ├── error_handler.ex          # Main error handling module
│   ├── error_display.ex          # Error display component
│   ├── error_categorizer.ex      # Categorize errors by type
│   ├── error_sanitizer.ex        # Sanitize errors for production
│   └── error_recovery.ex         # Recovery strategies
├── debug/
│   ├── query_display.ex          # Query display component
│   ├── debug_panel.ex            # Debug information panel
│   └── config_reader.ex          # Read debug config from domain
├── components/
│   └── error_alert.ex            # Reusable error alert component
└── form.ex                       # Enhanced error integration
```

### Debug Panel Component

```elixir
defmodule SelectoComponents.Debug.DebugPanel do
  use Phoenix.LiveComponent
  alias SelectoComponents.Debug.ConfigReader
  
  def render(assigns) do
    # Read debug config from domain
    debug_config = ConfigReader.get_debug_config(assigns.selecto)
    assigns = assign(assigns, :debug_config, debug_config)
    
    ~H"""
    <%= if should_show_debug?(@debug_config) do %>
      <div class="debug-panel mt-4 p-4 bg-gray-100 dark:bg-gray-800 rounded-lg">
        <details class="text-xs">
          <summary class="cursor-pointer font-medium text-gray-700 dark:text-gray-300">
            Debug Information
            <%= if @execution_time do %>
              <span class="ml-2 text-green-600">(<%= @execution_time %>ms)</span>
            <% end %>
          </summary>
          
          <div class="mt-2 space-y-3">
            <!-- SQL Query Display -->
            <%= if should_show_query?(@debug_config, @view_type) do %>
              <div class="bg-gray-900 text-gray-100 p-3 rounded overflow-x-auto">
                <div class="flex justify-between items-center mb-2">
                  <p class="font-bold text-sm">SQL Query:</p>
                  <button
                    type="button"
                    phx-click="copy_query"
                    phx-value-query={@query}
                    class="text-xs px-2 py-1 bg-gray-700 hover:bg-gray-600 rounded"
                  >
                    Copy
                  </button>
                </div>
                <pre><code class="language-sql"><%= format_sql(@query, @debug_config) %></code></pre>
              </div>
            <% end %>
            
            <!-- Parameters Display -->
            <%= if should_show_params?(@debug_config, @view_type) and @params && length(@params) > 0 do %>
              <div class="bg-blue-50 dark:bg-blue-900 p-3 rounded">
                <p class="font-bold text-sm mb-2">Parameters:</p>
                <pre class="text-xs"><%= format_params(@params, @debug_config) %></pre>
              </div>
            <% end %>
            
            <!-- Timing Information -->
            <%= if should_show_timing?(@debug_config) and @timing do %>
              <div class="bg-green-50 dark:bg-green-900 p-3 rounded">
                <p class="font-bold text-sm mb-2">Performance:</p>
                <ul class="text-xs space-y-1">
                  <li>Query Execution: <%= @timing.query_time %>ms</li>
                  <li>Data Processing: <%= @timing.processing_time %>ms</li>
                  <li>Total Time: <%= @timing.total_time %>ms</li>
                  <%= if should_show_row_count?(@debug_config) do %>
                    <li>Rows Returned: <%= @timing.row_count %></li>
                  <% end %>
                </ul>
              </div>
            <% end %>
            
            <!-- Query Plan (if enabled) -->
            <%= if should_show_query_plan?(@debug_config) and @query_plan do %>
              <div class="bg-yellow-50 dark:bg-yellow-900 p-3 rounded">
                <p class="font-bold text-sm mb-2">Query Plan:</p>
                <pre class="text-xs overflow-x-auto"><%= @query_plan %></pre>
              </div>
            <% end %>
            
            <!-- Toggle Controls -->
            <div class="flex gap-2 mt-3 pt-3 border-t border-gray-300 dark:border-gray-600">
              <button
                type="button"
                phx-click="toggle_debug_option"
                phx-value-option="show_query"
                class={[
                  "text-xs px-2 py-1 rounded",
                  if @debug_config.show_query do
                    "bg-blue-500 text-white"
                  else
                    "bg-gray-300 text-gray-700"
                  end
                ]}
              >
                Query
              </button>
              <button
                type="button"
                phx-click="toggle_debug_option"
                phx-value-option="show_params"
                class={[
                  "text-xs px-2 py-1 rounded",
                  if @debug_config.show_params do
                    "bg-blue-500 text-white"
                  else
                    "bg-gray-300 text-gray-700"
                  end
                ]}
              >
                Params
              </button>
              <button
                type="button"
                phx-click="toggle_debug_option"
                phx-value-option="show_timing"
                class={[
                  "text-xs px-2 py-1 rounded",
                  if @debug_config.show_timing do
                    "bg-blue-500 text-white"
                  else
                    "bg-gray-300 text-gray-700"
                  end
                ]}
              >
                Timing
              </button>
            </div>
          </div>
        </details>
      </div>
    <% end %>
    """
  end
  
  # Helper functions
  defp should_show_debug?(config) do
    dev_mode?() and config[:debug_mode] != :off
  end
  
  defp should_show_query?(config, view_type) do
    case config[:view_debug] do
      %{^view_type => %{show_query: show}} -> show
      _ -> config[:show_query] != false
    end
  end
  
  defp should_show_params?(config, view_type) do
    case config[:view_debug] do
      %{^view_type => %{show_params: show}} -> show
      _ -> config[:show_params] != false
    end
  end
  
  defp format_sql(query, config) do
    if config[:format_sql] != false do
      # Pretty-print SQL with proper indentation
      query
      |> String.replace(~r/\bSELECT\b/i, "SELECT\n  ")
      |> String.replace(~r/\bFROM\b/i, "\nFROM")
      |> String.replace(~r/\bWHERE\b/i, "\nWHERE")
      |> String.replace(~r/\bGROUP BY\b/i, "\nGROUP BY")
      |> String.replace(~r/\bORDER BY\b/i, "\nORDER BY")
      |> String.replace(~r/\bLIMIT\b/i, "\nLIMIT")
      |> String.replace(~r/,(?=\s*[a-zA-Z_])/i, ",\n  ")
    else
      query
    end
  end
  
  defp format_params(params, config) do
    case config[:truncate_params] do
      nil -> inspect(params, pretty: true)
      max_length ->
        params
        |> Enum.map(fn param ->
          param_str = inspect(param)
          if String.length(param_str) > max_length do
            String.slice(param_str, 0, max_length) <> "..."
          else
            param_str
          end
        end)
        |> inspect(pretty: true)
    end
  end
end
```

### Config Reader Module

```elixir
defmodule SelectoComponents.Debug.ConfigReader do
  @doc """
  Read debug configuration from domain or use defaults
  """
  def get_debug_config(selecto) do
    domain = selecto.domain
    
    # Try to get debug config from domain
    debug_config = 
      if function_exported?(domain.__struct__, :debug_config, 0) do
        apply(domain.__struct__, :debug_config, [])
      else
        default_debug_config()
      end
    
    # Merge with environment-based defaults
    merge_with_defaults(debug_config)
  end
  
  defp default_debug_config do
    if dev_mode?() do
      %{
        show_query: true,
        show_params: true,
        show_timing: true,
        show_row_count: true,
        show_query_plan: false,
        show_stack_trace: true,
        show_component_state: true,
        format_sql: true,
        truncate_params: nil,
        debug_mode: :full
      }
    else
      %{
        debug_mode: :off,
        show_query: false,
        show_params: false,
        show_timing: false,
        show_row_count: false,
        show_query_plan: false,
        show_stack_trace: false,
        show_component_state: false
      }
    end
  end
  
  defp merge_with_defaults(config) do
    Map.merge(default_debug_config(), config)
  end
  
  defp dev_mode? do
    Application.get_env(:selecto_components, :environment, :dev) in [:dev, :test]
  end
end
```

### Enhanced Error Display Component

```elixir
defmodule SelectoComponents.ErrorHandling.ErrorDisplay do
  use Phoenix.LiveComponent
  
  def render(assigns) do
    ~H"""
    <div class="error-container" data-error-type={@error.type}>
      <!-- Main Error Alert -->
      <div class={[
        "rounded-lg p-4 mb-4",
        error_severity_class(@error)
      ]}>
        <div class="flex">
          <div class="flex-shrink-0">
            <.icon name={error_icon(@error)} class="h-5 w-5" />
          </div>
          
          <div class="ml-3 flex-1">
            <h3 class="text-sm font-medium">
              <%= error_title(@error) %>
            </h3>
            
            <div class="mt-2 text-sm">
              <%= error_message(@error) %>
            </div>
            
            <!-- Suggestions -->
            <%= if has_suggestions?(@error) do %>
              <div class="mt-3 text-sm">
                <p class="font-medium">Suggested Actions:</p>
                <ul class="list-disc list-inside mt-1">
                  <%= for suggestion <- error_suggestions(@error) do %>
                    <li><%= suggestion %></li>
                  <% end %>
                </ul>
              </div>
            <% end %>
            
            <!-- Dev Mode Details (respecting domain debug config) -->
            <%= if dev_mode?() and has_details?(@error) and should_show_error_details?(@debug_config) do %>
              <details class="mt-4 text-xs">
                <summary class="cursor-pointer font-medium">
                  Show Technical Details
                </summary>
                
                <div class="mt-2 space-y-2">
                  <!-- SQL Query (if allowed by config) -->
                  <%= if @error.query and should_show_query_in_error?(@debug_config) do %>
                    <div class="bg-gray-900 text-gray-100 p-3 rounded overflow-x-auto">
                      <p class="font-bold mb-1">SQL Query:</p>
                      <pre><code class="language-sql"><%= format_sql(@error.query, @debug_config) %></code></pre>
                    </div>
                  <% end %>
                  
                  <!-- Parameters (if allowed by config) -->
                  <%= if @error.params && length(@error.params) > 0 and should_show_params_in_error?(@debug_config) do %>
                    <div class="bg-gray-100 p-3 rounded">
                      <p class="font-bold mb-1">Parameters:</p>
                      <pre><%= format_params(@error.params, @debug_config) %></pre>
                    </div>
                  <% end %>
                  
                  <!-- Database Error -->
                  <%= if @error.db_error do %>
                    <div class="bg-red-50 p-3 rounded">
                      <p class="font-bold mb-1">Database Error:</p>
                      <pre class="whitespace-pre-wrap"><%= @error.db_error %></pre>
                    </div>
                  <% end %>
                  
                  <!-- Stack Trace -->
                  <%= if @error.stacktrace do %>
                    <div class="bg-gray-100 p-3 rounded">
                      <p class="font-bold mb-1">Stack Trace:</p>
                      <pre class="text-xs whitespace-pre-wrap"><%= format_stacktrace(@error.stacktrace) %></pre>
                    </div>
                  <% end %>
                  
                  <!-- Timing Information -->
                  <%= if @error.timing do %>
                    <div class="bg-blue-50 p-3 rounded">
                      <p class="font-bold mb-1">Performance:</p>
                      <ul class="text-xs">
                        <li>Query Time: <%= @error.timing.query_time %>ms</li>
                        <li>Total Time: <%= @error.timing.total_time %>ms</li>
                        <%= if @error.timing.row_count do %>
                          <li>Rows Processed: <%= @error.timing.row_count %></li>
                        <% end %>
                      </ul>
                    </div>
                  <% end %>
                </div>
              </details>
            <% end %>
            
            <!-- Action Buttons -->
            <div class="mt-4 flex gap-2">
              <%= if can_retry?(@error) do %>
                <button
                  type="button"
                  phx-click="retry_query"
                  class="btn btn-sm btn-primary"
                >
                  <.icon name="arrow-path" class="h-4 w-4" />
                  Retry
                </button>
              <% end %>
              
              <%= if dev_mode?() do %>
                <button
                  type="button"
                  phx-click="copy_error_details"
                  phx-value-error={Jason.encode!(@error)}
                  class="btn btn-sm btn-outline"
                >
                  <.icon name="clipboard-document" class="h-4 w-4" />
                  Copy Details
                </button>
              <% end %>
              
              <button
                type="button"
                phx-click="dismiss_error"
                class="btn btn-sm btn-ghost"
              >
                Dismiss
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
```

### Error Categorization

```elixir
defmodule SelectoComponents.ErrorHandling.ErrorCategorizer do
  @error_patterns %{
    # Query-related errors
    connection: [
      ~r/connection refused/i,
      ~r/could not connect/i,
      ~r/connection timeout/i,
      ~r/socket/i
    ],
    syntax: [
      ~r/syntax error/i,
      ~r/invalid column/i,
      ~r/unknown table/i,
      ~r/ambiguous column/i
    ],
    permission: [
      ~r/permission denied/i,
      ~r/access denied/i,
      ~r/unauthorized/i,
      ~r/insufficient privileges/i
    ],
    timeout: [
      ~r/timeout/i,
      ~r/statement timeout/i,
      ~r/query timeout/i
    ],
    constraint: [
      ~r/constraint violation/i,
      ~r/foreign key/i,
      ~r/unique constraint/i,
      ~r/check constraint/i
    ],
    resource: [
      ~r/out of memory/i,
      ~r/disk full/i,
      ~r/too many connections/i,
      ~r/resource limit/i
    ],
    
    # Data processing errors
    data_processing: [
      ~r/cannot decode/i,
      ~r/invalid.*format/i,
      ~r/json.*error/i,
      ~r/encoding.*failed/i,
      ~r/type.*mismatch/i,
      ~r/aggregation.*failed/i,
      ~r/subselect.*error/i
    ],
    
    # Rendering errors
    rendering: [
      ~r/undefined.*function/i,
      ~r/component.*not.*found/i,
      ~r/template.*error/i,
      ~r/render.*failed/i,
      ~r/hook.*undefined/i,
      ~r/asset.*not.*found/i
    ],
    
    # LiveView errors
    liveview: [
      ~r/socket.*disconnected/i,
      ~r/channel.*timeout/i,
      ~r/websocket.*error/i,
      ~r/push.*failed/i,
      ~r/handle_event.*error/i,
      ~r/mount.*failed/i,
      ~r/update.*failed/i
    ],
    
    # Configuration errors
    configuration: [
      ~r/invalid.*configuration/i,
      ~r/missing.*required/i,
      ~r/domain.*not.*found/i,
      ~r/schema.*mismatch/i,
      ~r/invalid.*parameter/i,
      ~r/undefined.*field/i
    ]
  }
  
  def categorize(error) do
    # Handle different error types
    case error do
      %Selecto.Error{} ->
        categorize_selecto_error(error)
      
      %Phoenix.LiveView.Socket{} ->
        :liveview
        
      %ArgumentError{} ->
        :configuration
        
      %KeyError{} ->
        :data_processing
        
      %Jason.DecodeError{} ->
        :data_processing
        
      _ ->
        categorize_by_message(error)
    end
  end
  
  defp categorize_selecto_error(error) do
    error_message = extract_error_message(error)
    categorize_by_message(error_message)
  end
  
  defp categorize_by_message(error) when is_binary(error) do
    Enum.find_value(@error_patterns, :unknown, fn {category, patterns} ->
      if Enum.any?(patterns, &Regex.match?(&1, error)) do
        category
      end
    end)
  end
  
  defp categorize_by_message(error) do
    error_message = extract_error_message(error)
    categorize_by_message(error_message)
  end
  
  def get_suggestions(error_type, error) do
    case error_type do
      :connection ->
        [
          "Check your database connection settings",
          "Verify the database server is running",
          "Check network connectivity",
          "Verify firewall settings"
        ]
        
      :syntax ->
        [
          "Review the field names and ensure they exist in the selected tables",
          "Check for typos in filter values",
          "Verify join relationships are correctly configured",
          "Try simplifying your query"
        ]
        
      :permission ->
        [
          "Contact your administrator for access",
          "Verify your database credentials",
          "Check if you have the necessary permissions for this operation"
        ]
        
      :timeout ->
        [
          "Try reducing the amount of data being queried",
          "Add more specific filters to limit results",
          "Consider using pagination for large datasets",
          "Contact your administrator if this persists"
        ]
        
      :constraint ->
        [
          "Check that your filter values are valid",
          "Verify data relationships are correct",
          "Review any custom constraints on the data"
        ]
        
      :resource ->
        [
          "Try querying less data",
          "Contact your system administrator",
          "Wait a few moments and try again"
        ]
        
      :data_processing ->
        [
          "Check the data format in your results",
          "Verify that all selected fields return valid data",
          "Try removing complex aggregations or calculations",
          "Check for null or invalid values in the data",
          "Try selecting fewer columns"
        ]
        
      :rendering ->
        [
          "Refresh the page to reload components",
          "Check browser console for JavaScript errors",
          "Clear browser cache and reload",
          "Verify all required assets are loaded",
          "Try a simpler view configuration"
        ]
        
      :liveview ->
        [
          "Check your internet connection",
          "Refresh the page to reconnect",
          "Check if the server is responding",
          "Try clearing browser cache",
          "Check for browser compatibility issues"
        ]
        
      :configuration ->
        [
          "Verify your domain configuration is correct",
          "Check that all required fields are provided",
          "Review the view configuration for errors",
          "Ensure schemas match the database structure",
          "Check for typos in configuration parameters"
        ]
        
      _ ->
        [
          "Try simplifying your query",
          "Check your configuration",
          "Refresh the page and try again",
          "Contact support if the issue persists"
        ]
    end
  end
  
  def get_error_title(error_type) do
    case error_type do
      :connection -> "Database Connection Error"
      :syntax -> "Query Syntax Error"
      :permission -> "Permission Denied"
      :timeout -> "Query Timeout"
      :constraint -> "Data Constraint Violation"
      :resource -> "Resource Limit Exceeded"
      :data_processing -> "Data Processing Error"
      :rendering -> "Display Error"
      :liveview -> "Connection Lost"
      :configuration -> "Configuration Error"
      _ -> "Unexpected Error"
    end
  end
end
```

### Error Recovery Strategies

```elixir
defmodule SelectoComponents.ErrorHandling.ErrorRecovery do
  def can_retry?(error_type) do
    error_type in [:connection, :timeout, :resource]
  end
  
  def recovery_strategy(error_type) do
    case error_type do
      :connection -> {:retry, delay: 1000, max_attempts: 3}
      :timeout -> {:retry, delay: 2000, max_attempts: 2}
      :resource -> {:retry, delay: 5000, max_attempts: 2}
      :syntax -> {:modify_query, suggestions: true}
      :permission -> {:escalate, show_contact: true}
      _ -> {:show_error, dismissible: true}
    end
  end
  
  def apply_recovery(strategy, socket) do
    case strategy do
      {:retry, opts} ->
        Process.send_after(self(), {:retry_query, opts}, opts[:delay])
        assign(socket, retrying: true, retry_opts: opts)
        
      {:modify_query, _opts} ->
        assign(socket, show_query_builder: true)
        
      {:escalate, _opts} ->
        assign(socket, show_contact_info: true)
        
      {:show_error, _opts} ->
        socket
    end
  end
end
```

## Implementation Phases

### Phase 1: Enhanced Error Display (Day 1-2)
- [ ] Create error handling module structure
- [ ] Implement error categorization
- [ ] Build enhanced error display component
- [ ] Add dev/prod environment detection
- [ ] Integrate with existing form component

### Phase 2: Error Context & Details (Day 3-4)
- [ ] Capture full query context
- [ ] Add SQL formatting for readability
- [ ] Implement parameter display
- [ ] Add timing information
- [ ] Create copy-to-clipboard functionality

### Phase 3: Error Recovery (Day 5)
- [ ] Implement retry mechanisms
- [ ] Add recovery strategies
- [ ] Create error dismissal with state preservation
- [ ] Add alternative action suggestions

### Phase 4: Testing & Documentation (Day 6-7)
- [ ] Unit tests for error categorization
- [ ] Integration tests for error display
- [ ] Documentation for error handling
- [ ] Error message catalog

## Success Metrics

- [ ] 100% of query errors are properly displayed
- [ ] Development environment shows full error context
- [ ] Production environment never exposes sensitive data
- [ ] Users can successfully retry transient errors
- [ ] Error messages provide actionable suggestions
- [ ] Error states are visually distinct and clear

## Security Considerations

1. **Information Disclosure**
   - Never show SQL queries in production
   - Sanitize all error messages for user display
   - Log full errors server-side only

2. **Error Message Sanitization**
   - Remove table names from production errors
   - Replace column names with user-friendly labels
   - Generic messages for permission errors

3. **Rate Limiting**
   - Limit retry attempts
   - Implement exponential backoff
   - Track repeated errors per session

## Testing Strategy

1. **Query Error Simulation**
   - Test with disconnected database
   - Invalid SQL syntax
   - Permission denied scenarios
   - Timeout conditions
   - Resource exhaustion

2. **Data Processing Error Simulation**
   - Invalid JSON in results
   - Type conversion failures
   - Null value handling
   - Large dataset processing
   - Subselect failures
   - Aggregation errors

3. **Rendering Error Simulation**
   - Missing components
   - JavaScript hook failures
   - Template compilation errors
   - Asset loading failures
   - Component state errors

4. **LiveView Error Simulation**
   - WebSocket disconnection
   - Event handler failures
   - Navigation errors
   - State synchronization issues
   - Concurrent update conflicts

5. **Configuration Error Simulation**
   - Missing required fields
   - Invalid domain configuration
   - Schema mismatches
   - Invalid view configurations
   - Parameter type errors

6. **Environment Testing**
   - **Development Mode:**
     - Verify ALL error types show full details
     - Check stack traces are complete
     - Ensure component state is displayed
     - Verify query details are shown
     - Test error copying functionality
   - **Production Mode:**
     - Confirm ALL error types are sanitized
     - No sensitive info exposed for any error
     - User-friendly messages for all errors
     - Proper error acknowledgment
   - Test error recovery mechanisms for all types

7. **User Experience Testing**
   - Error visibility and clarity for all error types
   - Recovery action effectiveness
   - Form state preservation during all errors
   - Error dismissal and retry functionality
   - Multiple concurrent errors handling

## Usage Examples

### Domain Configuration Examples

```elixir
# Example 1: Disable query display for sensitive data
defmodule MyApp.Domains.SensitiveDomain do
  use Selecto.Domain
  
  def debug_config do
    %{
      show_query: false,      # Never show SQL
      show_params: false,     # Never show parameters
      show_timing: true,      # Performance info is OK
      show_row_count: true    # Row counts are OK
    }
  end
end

# Example 2: Different settings per view type
defmodule MyApp.Domains.MixedDomain do
  use Selecto.Domain
  
  def debug_config do
    %{
      # Global defaults
      show_query: true,
      show_params: true,
      
      # Override per view type
      view_debug: %{
        # Show everything for aggregate views
        aggregate: %{show_query: true, show_params: true},
        # Hide params for detail views (might contain PII)
        detail: %{show_query: true, show_params: false},
        # Minimal debug for graph views
        graph: %{show_query: false, show_params: false}
      }
    }
  end
end

# Example 3: Production-like settings in dev
defmodule MyApp.Domains.ProductionTestDomain do
  use Selecto.Domain
  
  def debug_config do
    %{
      debug_mode: :minimal,  # Only show errors, no query info
    }
  end
end

# Example 4: Enhanced debugging with truncation
defmodule MyApp.Domains.VerboseDomain do
  use Selecto.Domain
  
  def debug_config do
    %{
      show_query: true,
      show_params: true,
      show_query_plan: true,     # Also show EXPLAIN output
      format_sql: true,          # Pretty-print SQL
      truncate_params: 200,      # Truncate long parameters
      show_stack_trace: true,
      show_component_state: true
    }
  end
end
```

### Integration in LiveView

```elixir
defmodule MyAppWeb.DataLive do
  use Phoenix.LiveView
  use SelectoComponents.Form
  
  def mount(_params, _session, socket) do
    # The debug panel will automatically read config from domain
    socket = 
      socket
      |> assign(:selecto, MyApp.Domains.MyDomain.new())
      |> assign(:show_debug, true)  # Can be toggled by user
    
    {:ok, socket}
  end
  
  def render(assigns) do
    ~H"""
    <div>
      <!-- Main form component -->
      <.live_component
        module={SelectoComponents.Form}
        id="selecto-form"
        selecto={@selecto}
        view_config={@view_config}
      />
      
      <!-- Debug panel (respects domain config) -->
      <%= if @show_debug do %>
        <.live_component
          module={SelectoComponents.Debug.DebugPanel}
          id="debug-panel"
          selecto={@selecto}
          query={@last_query}
          params={@last_params}
          timing={@last_timing}
          view_type={@view_config.view_mode}
        />
      <% end %>
    </div>
    """
  end
  
  # Handle debug toggle
  def handle_event("toggle_debug", _params, socket) do
    {:noreply, update(socket, :show_debug, &(!&1))}
  end
  
  # Handle debug option changes (overrides domain config temporarily)
  def handle_event("toggle_debug_option", %{"option" => option}, socket) do
    debug_config = 
      socket.assigns.selecto
      |> SelectoComponents.Debug.ConfigReader.get_debug_config()
      |> Map.update(String.to_atom(option), false, &(!&1))
    
    # Store override in session or socket assigns
    {:noreply, assign(socket, :debug_config_override, debug_config)}
  end
end
```

## Documentation Requirements

- [ ] Error type reference guide
- [ ] Common error resolution guide
- [ ] Developer debugging guide
- [ ] Production error monitoring setup
- [ ] User-facing error documentation
- [ ] Debug configuration guide with examples
- [ ] Migration guide for existing domains