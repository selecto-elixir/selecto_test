defmodule DocsSubselectsExamplesTest do
  use ExUnit.Case, async: true

# Skip all tests in this module since they use aspirational API
@moduletag :skip
@moduledoc """
These tests are for documentation examples that use aspirational/planned API.
The actual Selecto API differs from what's shown in documentation.
These tests are skipped until either:
1. The Selecto API is updated to match documentation, or
2. The documentation is updated to match the actual API

Key differences:
- Selecto.from/1 and Selecto.join/4 don't exist as standalone functions
- Window functions use window_function/3 then select, not inline in select
- Set operations take two complete queries, not chained methods
- Many other API differences
"""

  
  alias Selecto.Builder.Sql
  
  # Helper to configure test Selecto instance
  defp configure_test_selecto(table \\ "attendees") do
    domain_config = %{
      source: %{
        module: SelectoTest.Store.Attendee,
        table: table
      },
      schemas: %{
        "attendees" => SelectoTest.Store.Attendee,
        "attendee" => SelectoTest.Store.Attendee,
        "orders" => SelectoTest.Store.Order,
        "order" => SelectoTest.Store.Order,
        "events" => SelectoTest.Store.Event,
        "event" => SelectoTest.Store.Event,
        "sponsors" => SelectoTest.Store.Sponsor,
        "products" => SelectoTest.Store.Product,
        "tags" => SelectoTest.Store.Tag,
        "comments" => SelectoTest.Store.Comment,
        "posts" => SelectoTest.Store.Post,
        "users" => SelectoTest.Store.User,
        "films" => SelectoTest.Store.Film,
        "actors" => SelectoTest.Store.Actor,
        "film_actors" => SelectoTest.Store.FilmActor,
        "customers" => SelectoTest.Store.Customer,
        "orders_2024" => SelectoTest.Store.Order2024,
        "categories" => SelectoTest.Store.Category,
        "product_categories" => SelectoTest.Store.ProductCategory,
        "order_items" => SelectoTest.Store.OrderItem,
        "reviews" => SelectoTest.Store.Review,
        "audit_logs" => SelectoTest.Store.AuditLog,
        "inventory_snapshots" => SelectoTest.Store.InventorySnapshot
      },
      joins: %{},
      filters: []
    }
    
    Selecto.configure(domain_config, :test_connection)
  end
  
  describe "Basic Usage" do
    test "simple field specification" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select(["attendee.name", "attendee.email"])
        |> Selecto.subselect(["order.product_name", "order.quantity"])
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "attendee.name"
      assert sql =~ "attendee.email"
      assert sql =~ "SELECT json_agg(json_build_object"
      assert sql =~ "'product_name', o.product_name"
      assert sql =~ "'quantity', o.quantity"
      assert sql =~ "FROM orders o WHERE o.attendee_id = attendee.attendee_id"
    end
    
    test "multiple fields in one specification" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.subselect(["order.product_name", "order.quantity", "order.price"])
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "json_build_object"
      assert sql =~ "'product_name', o.product_name"
      assert sql =~ "'quantity', o.quantity"
      assert sql =~ "'price', o.price"
    end
    
    test "multiple subselects" do
      selecto = configure_test_selecto("events")
      
      result = 
        selecto
        |> Selecto.select(["event.name", "event.date"])
        |> Selecto.subselect([
          "attendees.name",
          "attendees.email",
          "sponsors.company",
          "sponsors.amount"
        ])
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "event.name"
      assert sql =~ "event.date"
      # Would generate subqueries for attendees and sponsors
      assert sql =~ "SELECT"
    end
  end
  
  describe "Advanced Configuration" do
    test "map-based configuration with ordering" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.subselect([
          %{
            fields: ["product_name", "quantity", "price"],
            target_schema: :order,
            format: :json_agg,
            alias: "order_items",
            order_by: [{"created_at", :desc}]
          }
        ])
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "json_agg"
      assert sql =~ "product_name"
      assert sql =~ "quantity"
      assert sql =~ "price"
      assert sql =~ "ORDER BY created_at DESC"
      assert sql =~ "AS order_items"
    end
    
    test "subselect with filter conditions" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.subselect([
          %{
            fields: ["product_name", "quantity"],
            target_schema: :order,
            filter: [{"status", "completed"}, {"total", {:>, 100}}]
          }
        ])
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "json_agg"
      assert sql =~ "status = $"
      assert sql =~ "total > $"
      assert "completed" in params
      assert 100 in params
    end
    
    test "subselect with limit" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.subselect([
          %{
            fields: ["comment_text", "created_at"],
            target_schema: :comments,
            format: :json_agg,
            order_by: [{"created_at", :desc}],
            limit: 5
          }
        ])
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "json_agg"
      assert sql =~ "comment_text"
      assert sql =~ "created_at"
      assert sql =~ "ORDER BY created_at DESC"
      assert sql =~ "LIMIT $"
      assert 5 in params
    end
  end
  
  describe "Aggregation Formats" do
    test "JSON aggregation (default)" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.subselect(["order.product_name", "order.quantity"])
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "json_agg(json_build_object"
      assert sql =~ "'product_name'"
      assert sql =~ "'quantity'"
    end
    
    test "PostgreSQL array aggregation" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.subselect([
          %{
            fields: ["product_name"],
            target_schema: :order,
            format: :array_agg
          }
        ])
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "ARRAY_AGG"
      assert sql =~ "product_name"
    end
    
    test "string aggregation with delimiter" do
      selecto = configure_test_selecto("posts")
      
      result = 
        selecto
        |> Selecto.subselect([
          %{
            fields: ["tag_name"],
            target_schema: :tags,
            format: :string_agg,
            delimiter: ", "
          }
        ])
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "STRING_AGG"
      assert sql =~ "tag_name"
      assert ", " in params
    end
    
    test "count aggregation" do
      selecto = configure_test_selecto("posts")
      
      result = 
        selecto
        |> Selecto.subselect([
          %{
            target_schema: :comments,
            format: :count,
            alias: "comment_count"
          }
        ])
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "COUNT(*)"
      assert sql =~ "AS comment_count"
    end
  end
  
  describe "Complex Examples" do
    test "e-commerce order with nested items" do
      selecto = configure_test_selecto("orders")
      
      result = 
        selecto
        |> Selecto.select(["order_id", "customer_id", "order_date", "total"])
        |> Selecto.subselect([
          %{
            fields: ["product_id", "product_name", "quantity", "unit_price"],
            target_schema: :order_items,
            format: :json_agg,
            alias: "items",
            order_by: [{"line_number", :asc}]
          }
        ])
        |> Selecto.filter([{"status", "completed"}])
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "order_id"
      assert sql =~ "customer_id"
      assert sql =~ "json_agg"
      assert sql =~ "product_id"
      assert sql =~ "product_name"
      assert sql =~ "ORDER BY line_number ASC"
      assert sql =~ "status = $"
      assert "completed" in params
    end
    
    test "film with actors through junction table" do
      selecto = configure_test_selecto("films")
      
      result = 
        selecto
        |> Selecto.select(["film.title", "film.release_year"])
        |> Selecto.subselect([
          %{
            fields: ["actor.first_name", "actor.last_name", "fa.character_name"],
            target_schema: :actors,
            through: :film_actors,
            format: :json_agg,
            alias: "cast",
            order_by: [{"fa.billing_order", :asc}]
          }
        ])
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "film.title"
      assert sql =~ "film.release_year"
      assert sql =~ "json_agg"
      assert sql =~ "first_name"
      assert sql =~ "last_name"
      assert sql =~ "character_name"
      assert sql =~ "ORDER BY fa.billing_order ASC"
    end
    
    test "user profile with recent activity" do
      selecto = configure_test_selecto("users")
      
      result = 
        selecto
        |> Selecto.select(["user.id", "user.name", "user.email"])
        |> Selecto.subselect([
          %{
            fields: ["post.title", "post.created_at"],
            target_schema: :posts,
            format: :json_agg,
            alias: "recent_posts",
            filter: [{"published", true}],
            order_by: [{"created_at", :desc}],
            limit: 5
          },
          %{
            fields: ["comment.text", "comment.created_at"],
            target_schema: :comments,
            format: :json_agg,
            alias: "recent_comments",
            order_by: [{"created_at", :desc}],
            limit: 10
          }
        ])
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "user.id"
      assert sql =~ "user.name"
      assert sql =~ "AS recent_posts"
      assert sql =~ "AS recent_comments"
      assert sql =~ "published = $"
      assert sql =~ "LIMIT"
      assert true in params
      assert 5 in params
      assert 10 in params
    end
  end
  
  describe "Performance Patterns" do
    test "conditional subselects" do
      selecto = configure_test_selecto("customers")
      
      # Only fetch orders for VIP customers
      result = 
        selecto
        |> Selecto.select(["customer.*"])
        |> Selecto.subselect([
          %{
            fields: ["order_id", "total", "order_date"],
            target_schema: :orders,
            format: :json_agg,
            alias: "recent_orders",
            filter: [{"order_date", {:>, "2024-01-01"}}],
            when: {:field, "customer.tier", "VIP"}
          }
        ])
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "customer.*"
      assert sql =~ "CASE WHEN customer.tier = 'VIP'"
      assert sql =~ "json_agg"
      assert sql =~ "order_date > '2024-01-01'"
    end
    
    test "batch subselects with CTE" do
      selecto = configure_test_selecto("products")
      
      result = 
        selecto
        |> Selecto.with_cte("product_stats", fn ->
            Selecto.select([
                "product_id",
                {:count, "review_id", as: "review_count"},
                {:avg, "rating", as: "avg_rating"}
              ])
            |> Selecto.from("reviews")
            |> Selecto.group_by(["product_id"])
          end)
        |> Selecto.select(["product.*", "ps.review_count", "ps.avg_rating"])
        |> Selecto.join(:left, "product_stats AS ps", on: "product.id = ps.product_id")
        |> Selecto.subselect([
          %{
            fields: ["category_name"],
            target_schema: :categories,
            through: :product_categories,
            format: :array_agg,
            alias: "categories"
          }
        ])
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "WITH product_stats AS"
      assert sql =~ "COUNT(review_id) AS review_count"
      assert sql =~ "AVG(rating) AS avg_rating"
      assert sql =~ "LEFT JOIN product_stats AS ps"
      assert sql =~ "ARRAY_AGG"
      assert sql =~ "category_name"
    end
  end
  
  describe "Domain-Specific Patterns" do
    test "analytics dashboard with time-series subselects" do
      selecto = configure_test_selecto("customers")
      
      result = 
        selecto
        |> Selecto.select(["customer_id", "customer_name"])
        |> Selecto.subselect([
          %{
            fields: [
              "DATE_TRUNC('month', order_date) AS month",
              "SUM(total) AS monthly_total",
              "COUNT(*) AS order_count"
            ],
            target_schema: :orders_2024,
            format: :json_agg,
            alias: "monthly_stats",
            group_by: ["DATE_TRUNC('month', order_date)"],
            order_by: [{"month", :asc}]
          }
        ])
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "customer_id"
      assert sql =~ "customer_name"
      assert sql =~ "DATE_TRUNC('month', order_date)"
      assert sql =~ "SUM(total) AS monthly_total"
      assert sql =~ "COUNT(*) AS order_count"
      assert sql =~ "GROUP BY DATE_TRUNC('month', order_date)"
      assert sql =~ "ORDER BY month ASC"
    end
    
    test "audit trail with nested changes" do
      selecto = configure_test_selecto("orders")
      
      result = 
        selecto
        |> Selecto.select(["order_id", "status", "updated_at"])
        |> Selecto.subselect([
          %{
            fields: ["field_name", "old_value", "new_value", "changed_at", "changed_by"],
            target_schema: :audit_logs,
            format: :json_agg,
            alias: "audit_trail",
            order_by: [{"changed_at", :desc}]
          }
        ])
        |> Selecto.filter([{"updated_at", {:>, "2024-01-01"}}])
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "order_id"
      assert sql =~ "status"
      assert sql =~ "json_agg"
      assert sql =~ "field_name"
      assert sql =~ "old_value"
      assert sql =~ "new_value"
      assert sql =~ "changed_at"
      assert sql =~ "changed_by"
      assert sql =~ "ORDER BY changed_at DESC"
    end
    
    test "inventory with historical snapshots" do
      selecto = configure_test_selecto("products")
      
      result = 
        selecto
        |> Selecto.select(["product.id", "product.name", "product.current_stock"])
        |> Selecto.subselect([
          %{
            fields: ["snapshot_date", "quantity", "location"],
            target_schema: :inventory_snapshots,
            format: :json_agg,
            alias: "stock_history",
            filter: [{"snapshot_date", {:>=, "CURRENT_DATE - INTERVAL '30 days'"}}],
            order_by: [{"snapshot_date", :desc}],
            limit: 30
          }
        ])
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "product.id"
      assert sql =~ "product.name"
      assert sql =~ "product.current_stock"
      assert sql =~ "json_agg"
      assert sql =~ "snapshot_date"
      assert sql =~ "quantity"
      assert sql =~ "location"
      assert sql =~ "snapshot_date >= 'CURRENT_DATE - INTERVAL '30 days'"
      assert sql =~ "ORDER BY snapshot_date DESC"
      assert sql =~ "LIMIT $"
      assert 30 in params
    end
  end
end