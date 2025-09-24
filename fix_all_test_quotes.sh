#!/bin/bash

# Function to fix quotes in a single file
fix_file() {
    local file="$1"
    echo "Fixing $file"
    
    # Replace \"selecto_root\".\" with selecto_root.
    sed -i 's/\\"selecto_root\\"\\.\\"/selecto_root\\./g' "$file"
    
    # Fix group by clauses
    sed -i 's/group by \\"selecto_root\\"\\.\\"/group by selecto_root\\./g' "$file"
    sed -i 's/group by \\"/group by /g' "$file"
    
    # Remove quotes from normal column names
    # Keep this simple - just remove quotes from common column names
    sed -i 's/\\"\(title\|rating\|release_year\|special_features\|film_id\)\\"/\1/g' "$file"
    sed -i 's/\\"\(description\|category_id\|name\|actor_id\|first_name\)\\"/\1/g' "$file"
    sed -i 's/\\"\(last_name\|customer_id\|rental_id\|inventory_id\|store_id\)\\"/\1/g' "$file"
    sed -i 's/\\"\(feature\|film_titles\|unique_ratings\|films_chronological\)\\"/\1/g' "$file"
    sed -i 's/\\"\(title_list\|total_features\|feature_count\|dimensions\|genres\)\\"/\1/g' "$file"
    sed -i 's/\\"\(enhanced_features\|features_no_trailers\|features_text\)\\"/\1/g' "$file"
    sed -i 's/\\"\(description_words\|film_list\|film_count\)\\"/\1/g' "$file"
    
    # Fix any \\ that were created by mistake
    sed -i 's/\\\\ @>/\\" @>/g' "$file"
    sed -i 's/\\\\ </\\" </g' "$file"
    sed -i 's/\\\\ &/\\" \&/g' "$file"
    sed -i 's/\\\\ =/\\" =/g' "$file"
    sed -i 's/\\\\ ORDER/\\" ORDER/g' "$file"
    sed -i 's/\\\\ DESC/\\" DESC/g' "$file"
    sed -i 's/\\\\ ASC/\\" ASC/g' "$file"
}

# Find and fix all test files in selecto_test (excluding vendor)
for file in test/*.exs; do
    if grep -q 'assert.*sql.*\\"selecto_root\\"' "$file" 2>/dev/null; then
        fix_file "$file"
    fi
done

# Find and fix all test files in vendor/selecto
for file in vendor/selecto/test/*.exs; do
    if grep -q 'assert.*sql.*\\"' "$file" 2>/dev/null; then
        fix_file "$file"
    fi
done

echo "All test files fixed!"