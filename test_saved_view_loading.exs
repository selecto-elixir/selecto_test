#!/usr/bin/env elixir

# Test script to verify saved view loading with order_by dir settings

IO.puts("""
Testing Saved View Loading with Order By Direction

Steps to test:
1. Navigate to http://localhost:4085/pagila
2. Click 'View Configuration' to open the form
3. Go to the Detail view tab
4. Add a column to Order By list
5. Set it to Descending
6. Save the view configuration with a name
7. Reload the page
8. Load the saved view
9. Check if the Descending radio button is selected

Watch the console output for debug messages showing:
- The order_by params being loaded
- The resulting view_config structure

Expected: The dir field should be preserved and the correct radio button should be selected.
""")
