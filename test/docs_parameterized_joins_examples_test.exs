defmodule DocsParameterizedJoinsExamplesTest do
  use ExUnit.Case, async: true
  
  alias Selecto.Builder.Sql
  
  # Helper to configure test Selecto instance
  defp configure_test_selecto(table \\ "orders") do
    domain_config = %{
      source: %{
        module: SelectoTest.Store.Order,
        table: table
      },
      schemas: %{
        "orders" => SelectoTest.Store.Order,
        "customers" => SelectoTest.Store.Customer,
        "payments" => SelectoTest.Store.Payment,
        "order_items" => SelectoTest.Store.OrderItem,
        "products" => SelectoTest.Store.Product,
        "audit_logs" => SelectoTest.Store.AuditLog,
        "internal_notes" => SelectoTest.Store.InternalNote,
        "team_assignments" => SelectoTest.Store.TeamAssignment,
        "customer_accessible" => SelectoTest.Store.CustomerAccessible,
        "current_inventory" => SelectoTest.Store.CurrentInventory,
        "inventory_history" => SelectoTest.Store.InventoryHistory,
        "demand_forecast" => SelectoTest.Store.DemandForecast,
        "ml_recommendations" => SelectoTest.Store.MLRecommendation,
        "reviews" => SelectoTest.Store.Review,
        "users" => SelectoTest.Store.User,
        "user_profiles" => SelectoTest.Store.UserProfile,
        "user_preferences" => SelectoTest.Store.UserPreference,
        "user_activity" => SelectoTest.Store.UserActivity,
        "hierarchy" => SelectoTest.Store.Hierarchy,
        "friendships" => SelectoTest.Store.Friendship,
        "comments" => SelectoTest.Store.Comment,
        "posts" => SelectoTest.Store.Post,
        "videos" => SelectoTest.Store.Video,
        "images" => SelectoTest.Store.Image
      },
      joins: %{},
      filters: []
    }
    
    Selecto.configure(domain_config, :test_connection)
  end
  
  describe "Basic Parameterized Joins" do
    test "simple parameter substitution" do
      selecto = configure_test_selecto()
      
      # Join with dynamic conditions
      result = 
        selecto
        |> Selecto.join(:inner, "customers", 
            on: "orders.customer_id = customers.id AND customers.status = 'active'")
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "INNER JOIN customers"
      assert sql =~ "orders.customer_id = customers.id"
      assert sql =~ "customers.status = 'active'"
    end
    
    test "multiple dynamic joins" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.join(:left, "payments", on: "orders.id = payments.order_id")
        |> Selecto.join(:inner, "customers", on: "orders.customer_id = customers.id")
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "LEFT JOIN payments"
      assert sql =~ "INNER JOIN customers"
    end
    
    test "conditional join application" do
      selecto = configure_test_selecto()
      
      include_payments = true
      include_items = false
      
      result = selecto
      result = if include_payments do
        result
        |> Selecto.join(:left, "payments", on: "orders.id = payments.order_id")
        |> Selecto.select_merge([
            {:sum, "payments.amount", as: "total_paid"},
            {:count, "payments.id", as: "payment_count"}
          ])
      else
        result
      end
      
      result = if include_items do
        result
        |> Selecto.join(:left, "order_items", on: "orders.id = order_items.order_id")
        |> Selecto.select_merge([{:count, "order_items.id", as: "item_count"}])
      else
        result
      end
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "LEFT JOIN payments"
      assert sql =~ "SUM(payments.amount)"
      assert sql =~ "COUNT(payments.id)"
      refute sql =~ "order_items"
    end
  end
  
  describe "Dynamic Join Conditions" do
    test "join with field mapping" do
      selecto = configure_test_selecto()
      
      # Join with multiple field mappings
      result = 
        selecto
        |> Selecto.join(:inner, "customers", 
            on: "orders.customer_id = customers.id AND orders.billing_country = customers.country")
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "orders.customer_id = customers.id"
      assert sql =~ "orders.billing_country = customers.country"
    end
    
    test "complex join conditions" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.join(:inner, "payments", 
            on: "orders.id = payments.order_id AND payments.amount > 0 AND payments.status IN ('completed', 'pending')")
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "orders.id = payments.order_id"
      assert sql =~ "payments.amount > 0"
      assert sql =~ "payments.status IN ('completed', 'pending')"
    end
  end
  
  describe "Conditional Joins" do
    test "role-based joins for admin" do
      selecto = configure_test_selecto()
      user_role = :admin
      
      result = case user_role do
        :admin ->
          selecto
          |> Selecto.join(:left, "audit_logs", on: "orders.id = audit_logs.order_id")
          |> Selecto.join(:left, "internal_notes", on: "orders.id = internal_notes.order_id")
        :manager ->
          selecto
          |> Selecto.join(:left, "team_assignments", on: "orders.id = team_assignments.order_id")
        :customer ->
          selecto
          |> Selecto.join(:inner, "customer_accessible", on: "orders.id = customer_accessible.order_id")
        _ ->
          selecto
      end
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "LEFT JOIN audit_logs"
      assert sql =~ "LEFT JOIN internal_notes"
      refute sql =~ "team_assignments"
      refute sql =~ "customer_accessible"
    end
    
    test "time-based joins" do
      selecto = configure_test_selecto("products")
      time_range = :historical
      
      result = case time_range do
        :current ->
          selecto
          |> Selecto.join(:inner, "current_inventory", on: "products.id = current_inventory.product_id")
        :historical ->
          selecto
          |> Selecto.join(:inner, "inventory_history", 
              on: "products.id = inventory_history.product_id AND inventory_history.date >= '2024-01-01'")
        :forecast ->
          selecto
          |> Selecto.join(:left, "demand_forecast", on: "products.id = demand_forecast.product_id")
      end
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "INNER JOIN inventory_history"
      assert sql =~ "inventory_history.date >= '2024-01-01'"
      refute sql =~ "current_inventory"
      refute sql =~ "demand_forecast"
    end
    
    test "feature flag based joins" do
      selecto = configure_test_selecto("products")
      
      feature_flags = %{
        enable_recommendations: true,
        enable_reviews: true,
        enable_social: false
      }
      
      result = selecto
      
      result = if feature_flags[:enable_recommendations] do
        result
        |> Selecto.join(:left, 
            "ml_recommendations", 
            on: "products.id = ml_recommendations.product_id AND ml_recommendations.score > 0.7")
      else
        result
      end
      
      result = if feature_flags[:enable_reviews] do
        result
        |> Selecto.join(:left,
            "(SELECT product_id, AVG(rating) as avg_rating, COUNT(*) as review_count 
              FROM reviews GROUP BY product_id) AS review_stats",
            on: "products.id = review_stats.product_id")
      else
        result
      end
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "LEFT JOIN ml_recommendations"
      assert sql =~ "ml_recommendations.score > 0.7"
      assert sql =~ "AVG(rating) as avg_rating"
      assert sql =~ "review_stats"
    end
  end
  
  describe "Multi-Path Joins" do
    test "optimized join path via recent orders" do
      selecto = configure_test_selecto("customers")
      optimization_hint = :via_recent
      
      result = case optimization_hint do
        :via_recent ->
          selecto
          |> Selecto.join(:inner,
              "(SELECT * FROM orders WHERE created_at > CURRENT_DATE - INTERVAL '30 days') AS recent_orders",
              on: "customers.id = recent_orders.customer_id")
        :via_high_value ->
          selecto
          |> Selecto.join(:inner,
              "(SELECT * FROM orders WHERE total > 1000) AS high_value_orders",
              on: "customers.id = high_value_orders.customer_id")
        _ ->
          selecto
          |> Selecto.join(:inner, "orders", on: "customers.id = orders.customer_id")
      end
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "SELECT * FROM orders WHERE created_at > CURRENT_DATE - INTERVAL '30 days'"
      assert sql =~ "AS recent_orders"
      assert sql =~ "customers.id = recent_orders.customer_id"
    end
    
    test "indexed join path" do
      selecto = configure_test_selecto("customers")
      
      result = 
        selecto
        |> Selecto.join(:inner,
            "order_customer_index",
            on: "customers.id = order_customer_index.customer_id")
        |> Selecto.join(:inner,
            "orders",
            on: "order_customer_index.order_id = orders.id")
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "INNER JOIN order_customer_index"
      assert sql =~ "INNER JOIN orders"
      assert sql =~ "order_customer_index.order_id = orders.id"
    end
  end
  
  describe "Join Templates" do
    test "hierarchical joins with ancestors" do
      selecto = configure_test_selecto("hierarchy")
      
      # Build ancestor joins up to 2 levels
      result = 
        selecto
        |> Selecto.join(:left, 
            "hierarchy AS parent_1",
            on: "hierarchy.parent_id = parent_1.id")
        |> Selecto.join(:left,
            "hierarchy AS parent_2",
            on: "parent_1.parent_id = parent_2.id")
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "hierarchy AS parent_1"
      assert sql =~ "hierarchy AS parent_2"
      assert sql =~ "hierarchy.parent_id = parent_1.id"
      assert sql =~ "parent_1.parent_id = parent_2.id"
    end
    
    test "composable user and order joins" do
      selecto = configure_test_selecto("users")
      
      # Compose multiple joins
      result = 
        selecto
        |> Selecto.join(:left, "user_profiles", 
            on: "users.id = user_profiles.user_id")
        |> Selecto.join(:left,
            "(SELECT user_id, COUNT(*) as activity_count 
              FROM user_activity 
              WHERE created_at > CURRENT_DATE - INTERVAL '90 days'
              GROUP BY user_id) AS activity",
            on: "users.id = activity.user_id")
        |> Selecto.join(:left, "orders",
            on: "users.id = orders.user_id")
        |> Selecto.join(:left, "payments",
            on: "orders.id = payments.order_id")
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "LEFT JOIN user_profiles"
      assert sql =~ "activity_count"
      assert sql =~ "INTERVAL '90 days'"
      assert sql =~ "LEFT JOIN orders"
      assert sql =~ "LEFT JOIN payments"
    end
  end
  
  describe "Advanced Patterns" do
    test "polymorphic joins for comments" do
      selecto = configure_test_selecto("comments")
      
      # Join polymorphic commentables
      result = 
        selecto
        |> Selecto.join(:left,
            "posts",
            on: "comments.commentable_type = 'Post' AND comments.commentable_id = posts.id")
        |> Selecto.join(:left,
            "videos",
            on: "comments.commentable_type = 'Video' AND comments.commentable_id = videos.id")
        |> Selecto.join(:left,
            "images",
            on: "comments.commentable_type = 'Image' AND comments.commentable_id = images.id")
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "comments.commentable_type = 'Post'"
      assert sql =~ "comments.commentable_id = posts.id"
      assert sql =~ "comments.commentable_type = 'Video'"
      assert sql =~ "comments.commentable_id = videos.id"
      assert sql =~ "comments.commentable_type = 'Image'"
      assert sql =~ "comments.commentable_id = images.id"
    end
    
    test "self-referential joins for friend network" do
      selecto = configure_test_selecto("friendships")
      
      # Join friends of friends (depth 2)
      result = 
        selecto
        |> Selecto.join(:left, "friendships AS friendships_1", 
            on: "friendships.friend_id = friendships_1.user_id")
        |> Selecto.join(:left, "friendships AS friendships_2",
            on: "friendships_1.friend_id = friendships_2.user_id")
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "friendships AS friendships_1"
      assert sql =~ "friendships AS friendships_2"
      assert sql =~ "friendships.friend_id = friendships_1.user_id"
      assert sql =~ "friendships_1.friend_id = friendships_2.user_id"
    end
    
    test "cross-database joins" do
      selecto = configure_test_selecto()
      
      # Join across databases (simulated)
      result = 
        selecto
        |> Selecto.join(:left, "analytics_db.public.user_metrics", 
            on: "orders.user_id = analytics_db.public.user_metrics.user_id")
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "analytics_db.public.user_metrics"
      assert sql =~ "orders.user_id = analytics_db.public.user_metrics.user_id"
    end
  end
  
  describe "Multi-Tenant Joins" do
    test "scoped joins with tenant_id" do
      selecto = configure_test_selecto()
      tenant_id = 42
      
      result = 
        selecto
        |> Selecto.join(:inner, "customers", 
            on: "orders.customer_id = customers.id AND customers.tenant_id = #{tenant_id}")
        |> Selecto.join(:inner, "products",
            on: "order_items.product_id = products.id AND products.tenant_id = #{tenant_id}")
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "customers.tenant_id = 42"
      assert sql =~ "products.tenant_id = 42"
    end
  end
end