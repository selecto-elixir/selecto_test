# TASK-001: Saved View Configurations

**Status:** Phase 1 Complete - Generator Created
**Priority:** High
**Created:** 2025-09-16
**Updated:** 2025-09-16
**Assigned:** In Progress

## Overview

Create a comprehensive saved view configuration system that allows users to save and load different view configurations (detail, aggregate, graph) independently. Each view type should maintain its own saved configurations without interfering with other view types.

## Problem Statement

Currently, the saved views system saves the entire params but doesn't distinguish between different view types. This means:
- A saved aggregate view could interfere with a detail view
- Users can't have different saved configurations for different view modes
- No way to save view-specific settings (e.g., column order for detail, group-by for aggregate, chart type for graph)

## Requirements

### Functional Requirements

1. **View Type Separation**
   - Save configurations separately for each view type (detail, aggregate, graph)
   - Each view type maintains its own list of saved configurations
   - Loading a saved detail view should not affect aggregate or graph views

2. **Saved Configuration Contents**
   - **Detail View:** Selected columns, column order, filters, sort order, page size
   - **Aggregate View:** Group-by fields, aggregate functions, filters, sort order
   - **Graph View:** Chart type, axes configuration, data series, filters

3. **User Management**
   - Optional user_id field to track who created the view
   - Support for both global (shared) and user-specific saved views
   - Description field for documenting what the saved view shows

4. **Persistence**
   - Store in database with proper indexing
   - Support for export/import of saved view configurations
   - Version tracking for future migration needs

### Technical Requirements

1. **Database Schema**
   ```sql
   saved_view_configs {
     id: integer (primary key)
     name: string (required)
     context: string (required) -- e.g., "/pagila", "/pagila_films"
     view_type: string (required) -- "detail", "aggregate", "graph"
     params: jsonb (required) -- view-specific configuration
     user_id: string (optional)
     description: text (optional)
     is_public: boolean (default: false)
     version: integer (default: 1)
     created_at: timestamp
     updated_at: timestamp
   }

   Indexes:
   - unique(name, context, view_type, user_id)
   - index(view_type, context)
   - index(user_id)
   - index(is_public)
   ```

2. **Mix Task Generator**
   - Enhance or create new `mix selecto.gen.saved_view_configs`
   - Generate migration with all required fields
   - Generate schema with proper validations
   - Generate context module with CRUD operations

3. **API Design**
   ```elixir
   # Save a view configuration
   save_view_config(name, context, view_type, params, opts \\ [])
   # opts can include: user_id, description, is_public

   # Load a view configuration
   get_view_config(name, context, view_type, opts \\ [])
   # opts can include: user_id

   # List available configurations
   list_view_configs(context, view_type, opts \\ [])
   # opts can include: user_id, include_public

   # Delete a configuration
   delete_view_config(name, context, view_type, opts \\ [])

   # Update a configuration
   update_view_config(name, context, view_type, params, opts \\ [])
   ```

## Implementation Plan

### Phase 1: Generator Enhancement
1. Create/enhance mix task `selecto.gen.saved_view_configs`
2. Add support for view_type field in migration
3. Add user_id and description fields
4. Update schema with proper validations
5. Create comprehensive changeset validations

### Phase 2: Context Module
1. Create SavedViewConfig context with use macro
2. Implement CRUD operations
3. Add query builders for filtering by view_type
4. Add support for user-specific vs global views
5. Implement access control logic

### Phase 3: Integration with SelectoComponents
1. Update Form.ex to use view_type when saving/loading
2. Modify UI to show saved views filtered by current view_type
3. Add dropdown/list component for saved view selection
4. Add save dialog with name and description fields
5. Implement load confirmation to prevent accidental overwrites

### Phase 4: UI Components
1. Create SavedViewManager LiveComponent
2. Add save button with modal dialog
3. Add load dropdown with preview
4. Add delete functionality with confirmation
5. Add import/export buttons

### Phase 5: Testing & Documentation
1. Write tests for all CRUD operations
2. Test view_type isolation
3. Test user-specific views
4. Write documentation for the feature
5. Add usage examples

## UI Mockup

```
[Detail View Tab]
┌─────────────────────────────────────┐
│ Saved Views: [Dropdown ▼] [Save] [⚙] │
│   • My Daily Report (detail)        │
│   • Customer List (detail)          │
│   • Product Inventory (detail)      │
└─────────────────────────────────────┘

[Save Dialog]
┌─────────────────────────────────────┐
│ Save Current View Configuration     │
│                                     │
│ Name: [________________]            │
│                                     │
│ Description:                        │
│ [________________________________]  │
│ [________________________________]  │
│                                     │
│ □ Make this view public            │
│                                     │
│ [Cancel] [Save]                    │
└─────────────────────────────────────┘
```

## Migration Strategy

For existing saved_views:
1. Add migration to add new columns with defaults
2. Set view_type = "detail" for all existing records
3. Migrate params structure if needed
4. Update unique constraints

## Success Criteria

- [ ] Users can save configurations for each view type independently
- [ ] Saved detail views don't affect aggregate or graph views
- [ ] Users can see only relevant saved views for current view type
- [ ] Saved views can have descriptions
- [ ] System tracks which user created each view
- [ ] Mix task generates all necessary files correctly
- [ ] All tests pass
- [ ] Documentation is complete

## Notes

- Consider adding a "default" saved view per view_type
- Future: Add sharing functionality (share via link)
- Future: Add version history for saved views
- Future: Add categories/tags for organizing saved views
- Keep backwards compatibility with existing saved_views table

## Code Examples

### Using the generated context:

```elixir
defmodule MyApp.Domains.UserDomain do
  use MyApp.SavedViewConfigContext

  # Domain configuration...
end

# In LiveView
def handle_event("save_view", %{"name" => name, "description" => desc}, socket) do
  view_type = socket.assigns.view_config.view_mode
  params = view_config_to_params(socket.assigns.view_config)

  MyApp.Domains.UserDomain.save_view_config(
    name,
    socket.assigns.saved_view_context,
    view_type,
    params,
    user_id: socket.assigns.current_user.id,
    description: desc
  )

  {:noreply, socket}
end
```

### Loading saved views:

```elixir
def load_saved_views(socket) do
  view_type = socket.assigns.view_config.view_mode

  configs = MyApp.Domains.UserDomain.list_view_configs(
    socket.assigns.saved_view_context,
    view_type,
    user_id: socket.assigns.current_user.id,
    include_public: true
  )

  assign(socket, :available_saved_views, configs)
end
```