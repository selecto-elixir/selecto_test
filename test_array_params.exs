alias Selecto.Advanced.ArrayOperations

# Test creating and converting to SQL
spec = ArrayOperations.create_array_operation(:array_append, "special_features", value: "Extended Cut", as: "enhanced_features")
IO.inspect(spec, label: "Spec")

{sql, params} = ArrayOperations.to_sql(spec, [])
IO.inspect({sql, params}, label: "SQL and Params")
