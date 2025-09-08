# SelectoCone LiveView Implementation Plan

## Overview
Create a single-file LiveView system that demonstrates SelectoCone's nested form capabilities using real database data from the Pagila database.

## Selected Use Case: Customer Rental Management
We'll build a form for managing customer rentals with nested data:
- **Main Entity**: Customer (view/edit customer details)
- **Nested Association**: Rentals (add/edit/remove rentals)
- **Provider Data**: Available inventory items from the store

## Implementation Steps

### 1. LiveView Module Structure
**File**: `lib/selecto_test_web/live/customer_rental_cone_live.ex`

```elixir
defmodule SelectoTestWeb.CustomerRentalConeLive do
  use SelectoTestWeb, :live_view
  
  # Core functionality:
  - mount/3: Load customer, setup provider & cone
  - render/1: Display form with nested rentals
  - handle_event/3: Validate, add/remove rentals, save
end
```

### 2. Route Configuration
**File**: `lib/selecto_test_web/router.ex`
```elixir
live "/customers/:customer_id/rentals", CustomerRentalConeLive, :edit
```

### 3. Provider Domain Setup
The provider will supply available inventory:
```elixir
def create_inventory_provider(store_id) do
  domain = %{
    source: %{
      source_table: "inventory",
      fields: [:inventory_id, :film_id, :store_id],
      joins: %{
        film: %{
          type: :inner,
          table: "film",
          fields: [:title, :rating, :rental_rate]
        }
      }
    },
    schemas: %{},
    name: "InventoryProvider"
  }
  
  Provider.init(domain, Repo, %{store_id: store_id}, :public)
  |> Provider.set_data_query(fn selecto ->
    # Query available inventory with film details
    selecto
    |> Selecto.filter([{:store_id, {:eq, store_id}}])
    |> Selecto.filter([{:"inventory.inventory_id", {:not_in, {:subquery, rented_inventory_subquery()}}}])
    |> Selecto.select([:inventory_id, :film_id, "film.title", "film.rating", "film.rental_rate"])
  end)
end
```

### 4. Cone Domain Setup
The cone defines the customer-rental structure:
```elixir
def create_customer_rental_cone(provider) do
  domain = %{
    source: %{
      source_table: "customer",
      schema_module: SelectoTest.Store.Customer,
      fields: [:customer_id, :first_name, :last_name, :email, :active],
      associations: %{
        rentals: %{
          queryable: SelectoTest.Store.Rental,
          cardinality: :many,
          fields: [:rental_id, :rental_date, :inventory_id, :return_date]
        }
      }
    },
    schemas: %{
      rentals: %{
        source_table: "rental",
        fields: [:rental_id, :rental_date, :inventory_id, :return_date],
        columns: %{
          rental_date: %{type: :utc_datetime, required: true},
          inventory_id: %{type: :integer, required: true},
          return_date: %{type: :utc_datetime}
        }
      }
    },
    name: "CustomerRentalCone"
  }
  
  Cone.init(domain, Repo, provider,
    validations: [
      {:rentals, :inventory_id, {:validate_with, :available_inventory}}
    ],
    depth_limit: 2
  )
end
```

### 5. LiveView Implementation Details

#### Mount Function
```elixir
def mount(%{"customer_id" => customer_id}, _session, socket) do
  customer = Repo.get!(Customer, customer_id) |> Repo.preload(:rentals)
  
  # Setup provider with available inventory
  provider = create_inventory_provider(customer.store_id || 1)
  {inventory_data, provider} = Provider.get_all_data(provider)
  
  # Setup cone for form structure
  cone = create_customer_rental_cone(provider)
  
  # Create changeset from existing data
  changeset = Cone.changeset(cone, customer, %{})
  
  {:ok,
   socket
   |> assign(:customer, customer)
   |> assign(:cone, cone)
   |> assign(:available_inventory, inventory_data.inventory)
   |> assign_form(changeset)}
end
```

#### Form Rendering
```elixir
def render(assigns) do
  ~H"""
  <div class="max-w-4xl mx-auto p-6">
    <h1 class="text-2xl font-bold mb-6">Edit Customer Rentals</h1>
    
    <.form for={@form} phx-change="validate" phx-submit="save">
      <%!-- Customer Details --%>
      <div class="bg-white rounded-lg shadow p-6 mb-6">
        <h2 class="text-lg font-semibold mb-4">Customer Information</h2>
        <div class="grid grid-cols-2 gap-4">
          <.input field={@form[:first_name]} label="First Name" />
          <.input field={@form[:last_name]} label="Last Name" />
          <.input field={@form[:email]} label="Email" type="email" />
          <.input field={@form[:active]} label="Active" type="checkbox" />
        </div>
      </div>
      
      <%!-- Rentals Section --%>
      <div class="bg-white rounded-lg shadow p-6">
        <h2 class="text-lg font-semibold mb-4">Rentals</h2>
        
        <.inputs_for :let={rental_form} field={@form[:rentals]}>
          <div class="border rounded p-4 mb-4">
            <div class="grid grid-cols-3 gap-4">
              <.input 
                field={rental_form[:inventory_id]} 
                type="select"
                label="Film"
                options={inventory_options(@available_inventory)}
                prompt="Select a film"
              />
              <.input 
                field={rental_form[:rental_date]} 
                type="datetime-local"
                label="Rental Date"
              />
              <.input 
                field={rental_form[:return_date]} 
                type="datetime-local"
                label="Return Date"
              />
            </div>
            <button 
              type="button"
              phx-click="remove_rental"
              phx-value-index={rental_form.index}
              class="mt-2 text-red-600 hover:text-red-800"
            >
              Remove Rental
            </button>
          </div>
        </.inputs_for>
        
        <button 
          type="button"
          phx-click="add_rental"
          class="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600"
        >
          Add Rental
        </button>
      </div>
      
      <div class="mt-6">
        <.button type="submit">Save Changes</.button>
      </div>
    </.form>
  </div>
  """
end
```

#### Event Handlers
```elixir
def handle_event("validate", %{"customer" => params}, socket) do
  changeset = 
    socket.assigns.cone
    |> Cone.changeset(socket.assigns.customer, params)
    |> Cone.validate_with_provider(socket.assigns.cone)
    |> Map.put(:action, :validate)
  
  {:noreply, assign_form(socket, changeset)}
end

def handle_event("add_rental", _, socket) do
  # Add new rental to form
  existing = get_field(socket.assigns.form.source, :rentals) || []
  new_rental = %Rental{rental_date: DateTime.utc_now()}
  updated_rentals = existing ++ [new_rental]
  
  changeset = 
    socket.assigns.cone
    |> Cone.changeset(socket.assigns.customer, %{
      "rentals" => serialize_rentals(updated_rentals)
    })
  
  {:noreply, assign_form(socket, changeset)}
end

def handle_event("remove_rental", %{"index" => index}, socket) do
  # Remove rental at index
  {index, _} = Integer.parse(index)
  rentals = get_field(socket.assigns.form.source, :rentals) || []
  updated_rentals = List.delete_at(rentals, index)
  
  changeset = 
    socket.assigns.cone
    |> Cone.changeset(socket.assigns.customer, %{
      "rentals" => serialize_rentals(updated_rentals)
    })
  
  {:noreply, assign_form(socket, changeset)}
end

def handle_event("save", %{"customer" => params}, socket) do
  case update_customer_with_rentals(socket.assigns.customer, params) do
    {:ok, customer} ->
      {:noreply,
       socket
       |> put_flash(:info, "Customer and rentals updated successfully!")
       |> push_navigate(to: ~p"/customers/#{customer.customer_id}/rentals")}
    
    {:error, changeset} ->
      {:noreply, assign_form(socket, changeset)}
  end
end
```

### 6. Key Features to Implement

1. **Real-time Validation**
   - Validate inventory availability as user selects
   - Show which films are already rented
   - Prevent duplicate inventory selections

2. **Smart Defaults**
   - Auto-fill rental_date with current time
   - Calculate suggested return date based on rental period

3. **Visual Feedback**
   - Highlight validation errors inline
   - Show available inventory count
   - Display film details (rating, rental rate) on selection

4. **Business Rules**
   - Maximum rentals per customer
   - Check customer active status
   - Validate rental dates (can't be in future, return after rental)

### 7. Testing Strategy

1. **Manual Testing Steps**:
   ```bash
   # Start server
   iex -S mix phx.server
   
   # Navigate to:
   http://localhost:4000/customers/1/rentals
   ```

2. **Test Scenarios**:
   - Load existing customer with rentals
   - Add new rental with valid inventory
   - Try to add already-rented inventory (should fail)
   - Remove rental
   - Save changes and verify in database

### 8. Database Queries Needed

```sql
-- Find available inventory (not currently rented)
SELECT i.inventory_id, f.title, f.rating, f.rental_rate
FROM inventory i
JOIN film f ON i.film_id = f.film_id
WHERE i.store_id = 1
  AND i.inventory_id NOT IN (
    SELECT inventory_id FROM rental 
    WHERE return_date IS NULL
  );

-- Get customer with current rentals
SELECT c.*, r.*, i.*, f.title
FROM customer c
LEFT JOIN rental r ON c.customer_id = r.customer_id
LEFT JOIN inventory i ON r.inventory_id = i.inventory_id
LEFT JOIN film f ON i.film_id = f.film_id
WHERE c.customer_id = 1
  AND r.return_date IS NULL;
```

### 9. UI/UX Enhancements

1. **Film Selection Display**:
   - Show film title, rating, and rental rate
   - Group by genre or alphabetically
   - Search/filter capability for large inventories

2. **Rental Status Indicators**:
   - Active rentals (no return date)
   - Overdue rentals (past expected return)
   - Returned rentals (grayed out)

3. **Responsive Design**:
   - Mobile-friendly form layout
   - Collapsible rental cards on small screens
   - Touch-friendly controls

### 10. Extension Ideas

1. **Multi-Store Support**: Switch between stores to see different inventory
2. **Batch Operations**: Select multiple films to rent at once
3. **History View**: Show past rentals in a separate tab
4. **Payment Integration**: Add payment form as another nested section
5. **Staff Assignment**: Select which staff member is processing the rental

## File Structure Summary

```
lib/selecto_test_web/
├── live/
│   └── customer_rental_cone_live.ex  # Main LiveView implementation
└── router.ex                          # Route addition

test/selecto_test_web/live/
└── customer_rental_cone_live_test.exs # LiveView tests
```

## Success Criteria

✅ User can navigate to `/customers/:id/rentals`
✅ Form loads with customer data and current rentals
✅ Available inventory is fetched and displayed in dropdown
✅ User can add/remove rental entries
✅ Validation prevents selecting already-rented items
✅ Changes save to database correctly
✅ UI provides clear feedback for all actions

## Tomorrow's Development Order

1. **Morning**: Create basic LiveView with route
2. **Mid-Morning**: Implement Provider and Cone domains
3. **Late Morning**: Add form rendering and basic interactions
4. **Afternoon**: Implement validation and save functionality
5. **Late Afternoon**: Add UI polish and test with real data
6. **End of Day**: Document and demo the working system

This plan provides a complete, working example of SelectoCone's capabilities in a real-world scenario!