#!/bin/bash

# Fix all MySQL test setup blocks to properly skip when MySQL is not available
for file in test/*mysql*_test.exs test/selecto_mysql_integration_test.exs; do
    if [ -f "$file" ]; then
        echo "Fixing $file"
        
        # Add moduletag if missing (except for unit tests)
        if [[ "$file" != *"unit_test.exs" ]] && ! grep -q "@moduletag :mysql_integration" "$file"; then
            sed -i '3a\  @moduletag :mysql_integration' "$file"
        fi
        
        # Fix setup blocks that try to connect
        sed -i '/setup do$/,/^    end$/{
            s/{:ok, conn} = MySQL\.connect/@mysql_config/
            s/@mysql_config/@mysql_config)\n      case MySQL.connect(@mysql_config) do\n        {:ok, conn} ->/
            s/on_exit(fn -> MySQL\.disconnect(conn) end)/on_exit(fn -> if conn, do: MySQL.disconnect(conn) end)/
            /{:ok, conn: conn}$/a\        {:error, _} ->\n          :skip\n      end
        }' "$file"
    fi
done

echo "Done fixing MySQL tests"