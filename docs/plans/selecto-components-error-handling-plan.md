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
   - Prominent visual indication when queries fail
   - Error state should be immediately obvious
   - Preserve user's work/configuration when errors occur

2. **Informative Error Messages**
   - User-friendly explanations of what went wrong
   - Actionable suggestions for resolution
   - Different messaging for dev vs production environments

3. **Error Recovery**
   - Allow users to retry failed operations
   - Preserve form state during errors
   - Provide alternative actions when appropriate

### Technical Requirements
1. **Development Environment**
   - Full SQL query display
   - Query parameters
   - Database error details
   - Stack traces
   - Execution timing information
   - Connection details

2. **Production Environment**
   - Sanitized error messages
   - No sensitive information exposure
   - Generic but helpful user messages
   - Error tracking/logging capabilities

3. **Error Categorization**
   - Connection errors
   - Query syntax errors
   - Permission/authorization errors
   - Timeout errors
   - Data validation errors
   - Resource limit errors

## Architecture Design

### Component Structure
```
vendor/selecto_components/lib/selecto_components/
├── error_handling/
│   ├── error_handler.ex          # Main error handling module
│   ├── error_display.ex          # Error display component
│   ├── error_categorizer.ex      # Categorize errors by type
│   ├── error_sanitizer.ex        # Sanitize errors for production
│   └── error_recovery.ex         # Recovery strategies
├── components/
│   └── error_alert.ex            # Reusable error alert component
└── form.ex                       # Enhanced error integration
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
            
            <!-- Dev Mode Details -->
            <%= if dev_mode?() and has_details?(@error) do %>
              <details class="mt-4 text-xs">
                <summary class="cursor-pointer font-medium">
                  Show Technical Details
                </summary>
                
                <div class="mt-2 space-y-2">
                  <!-- SQL Query -->
                  <%= if @error.query do %>
                    <div class="bg-gray-900 text-gray-100 p-3 rounded overflow-x-auto">
                      <p class="font-bold mb-1">SQL Query:</p>
                      <pre><code class="language-sql"><%= format_sql(@error.query) %></code></pre>
                    </div>
                  <% end %>
                  
                  <!-- Parameters -->
                  <%= if @error.params && length(@error.params) > 0 do %>
                    <div class="bg-gray-100 p-3 rounded">
                      <p class="font-bold mb-1">Parameters:</p>
                      <pre><%= inspect(@error.params, pretty: true) %></pre>
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
    ]
  }
  
  def categorize(error) do
    error_message = extract_error_message(error)
    
    Enum.find_value(@error_patterns, :unknown, fn {category, patterns} ->
      if Enum.any?(patterns, &Regex.match?(&1, error_message)) do
        category
      end
    end)
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
        
      _ ->
        [
          "Try simplifying your query",
          "Check your configuration",
          "Contact support if the issue persists"
        ]
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

1. **Error Simulation**
   - Test with disconnected database
   - Invalid SQL syntax
   - Permission denied scenarios
   - Timeout conditions
   - Resource exhaustion

2. **Environment Testing**
   - Verify dev mode shows full details
   - Confirm production hides sensitive info
   - Test error recovery mechanisms

3. **User Experience Testing**
   - Error visibility and clarity
   - Recovery action effectiveness
   - Form state preservation

## Documentation Requirements

- [ ] Error type reference guide
- [ ] Common error resolution guide
- [ ] Developer debugging guide
- [ ] Production error monitoring setup
- [ ] User-facing error documentation