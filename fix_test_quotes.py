#!/usr/bin/env python3
import re
import sys

def fix_quotes_in_test(content):
    """Fix quoted identifiers in test assertions to match new quoting policy"""
    
    # Fix patterns like \"selecto_root\" -> selecto_root
    content = re.sub(r'\\"selecto_root\\"', 'selecto_root', content)
    
    # Fix patterns like \"title\" -> title (for normal column names)
    # But keep quotes for reserved words and special chars
    normal_columns = [
        'title', 'rating', 'release_year', 'special_features', 'film_id',
        'description', 'category_id', 'name', 'actor_id', 'first_name',
        'last_name', 'customer_id', 'rental_id', 'inventory_id', 'store_id',
        'feature', 'film_titles', 'unique_ratings', 'films_chronological',
        'title_list', 'total_features', 'feature_count', 'dimensions',
        'genres', 'enhanced_features', 'features_no_trailers', 'features_text',
        'description_words', 'film_list', 'film_count'
    ]
    
    for col in normal_columns:
        # Fix patterns like \"column\" -> column
        content = re.sub(rf'\\"({col})\\"', r'\1', content)
    
    # Fix patterns that got messed up like \"title\\ -> title\"
    content = re.sub(r'\\\\(["\'` ])', r'\1', content)
    
    # Fix group by patterns
    content = re.sub(r'group by \\"([^"]+)\\"', r'group by \1', content)
    
    return content

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python fix_test_quotes.py <file>")
        sys.exit(1)
    
    filename = sys.argv[1]
    with open(filename, 'r') as f:
        content = f.read()
    
    fixed_content = fix_quotes_in_test(content)
    
    with open(filename, 'w') as f:
        f.write(fixed_content)
    
    print(f"Fixed {filename}")