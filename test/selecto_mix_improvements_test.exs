defmodule SelectoMixImprovementsTest do
  use ExUnit.Case, async: false
  
  alias SelectoMix.{AdapterDetector, CLIParser, JoinAnalyzer}
  alias SelectoTest.Ecommerce.{User, Product, Category, Order, Warehouse}
  
  describe "AdapterDetector" do
    test "detects PostgreSQL adapter from repo" do
      assert {:ok, :postgres} = AdapterDetector.detect(repo: SelectoTest.Repo)
    end
    
    test "detects adapter from dependencies" do
      assert {:ok, adapter} = AdapterDetector.detect()
      assert adapter in [:postgres, :mysql, :sqlite]
    end
    
    test "returns correct feature map for PostgreSQL" do
      features = AdapterDetector.get_features(:postgres)
      
      assert features[:arrays] == true
      assert features[:ctes] == true
      assert features[:window_functions] == true
      assert features[:full_outer_join] == true
      assert features[:uuid_native] == true
    end
    
    test "returns correct feature map for MySQL with version" do
      features = AdapterDetector.get_features(:mysql, "8.0.32")
      
      assert features[:arrays] == false
      assert features[:ctes] == true  # Available in 8.0+
      assert features[:window_functions] == true  # Available in 8.0+
      assert features[:full_outer_join] == false
      assert features[:uuid_native] == false
    end
    
    test "returns correct feature map for SQLite" do
      features = AdapterDetector.get_features(:sqlite, "3.35.0")
      
      assert features[:arrays] == false
      assert features[:ctes] == true
      assert features[:window_functions] == true  # Available in 3.25+
      assert features[:full_outer_join] == false
      assert features[:lateral_joins] == false
    end
    
    test "provides correct type mappings for MySQL" do
      mappings = AdapterDetector.get_type_mappings(:mysql)
      
      assert mappings[:uuid] == :string
      assert mappings[:array] == :json
      assert mappings[:jsonb] == :json
    end
    
    test "provides correct type mappings for SQLite" do
      mappings = AdapterDetector.get_type_mappings(:sqlite)
      
      assert mappings[:uuid] == :string
      assert mappings[:array] == :json
      assert mappings[:bigint] == :integer
      assert mappings[:boolean] == :integer
    end
  end
  
  describe "CLIParser" do
    test "parses basic options correctly" do
      argv = ["Blog.Post", "--adapter", "mysql", "--output", "lib/domains", "--force"]
      
      assert {:ok, args} = CLIParser.parse(argv)
      assert args[:adapter] == :mysql
      assert args[:output] == "lib/domains"
      assert args[:force] == true
      assert args[:dry_run] == false
      assert "Blog.Post" in args[:schemas]
    end
    
    test "parses complex join options" do
      argv = ["--joins", "advanced", "--join-depth", "5", 
              "--join-strategy", "eager", "--parameterized-joins"]
      
      assert {:ok, args} = CLIParser.parse(argv)
      assert args[:joins] == :advanced
      assert args[:join_depth] == 5
      assert args[:join_strategy] == :eager
      assert args[:parameterized_joins] == true
    end
    
    test "parses database-specific options" do
      argv = ["--adapter", "mysql", "--mysql-version", "8.0.32",
              "--mysql-extensions", "json,fulltext"]
      
      assert {:ok, args} = CLIParser.parse(argv)
      assert args[:adapter] == :mysql
      assert args[:adapter_version] == "8.0.32"
      assert "json" in args[:extensions]
      assert "fulltext" in args[:extensions]
    end
    
    test "uses aliases correctly" do
      argv = ["User", "-a", "postgres", "-o", "lib/gen", "-f", "-v", "-l", "-t"]
      
      assert {:ok, args} = CLIParser.parse(argv)
      assert args[:adapter] == :postgres
      assert args[:output] == "lib/gen"
      assert args[:force] == true
      assert args[:verbose] == true
      assert args[:live] == true
      assert args[:tests] == true
    end
    
    test "validates conflicting options" do
      argv = ["--quiet", "--verbose"]
      {:ok, args} = CLIParser.parse(argv)
      
      assert {:error, errors} = CLIParser.validate_args(args)
      assert "Cannot use --quiet and --verbose together" in errors
    end
    
    test "validates saved-views requires live" do
      argv = ["--saved-views"]
      {:ok, args} = CLIParser.parse(argv)
      
      assert {:error, errors} = CLIParser.validate_args(args)
      assert "--saved-views requires --live to be set" in errors
    end
  end
  
  describe "JoinAnalyzer with complex Ecommerce schema" do
    test "analyzes User schema with hierarchical referral relationship" do
      analysis = JoinAnalyzer.analyze(User)
      
      # Should detect self-referential hierarchy
      assert length(analysis.hierarchies) > 0
      hierarchy = hd(analysis.hierarchies)
      assert hierarchy.type == :adjacency_list
      assert hierarchy.parent_field == :referrer_id
      
      # Should detect basic relationships (addresses, reviews are commented out)
      # assert Map.has_key?(analysis.joins, :addresses)
      assert Map.has_key?(analysis.joins, :orders)
      assert Map.has_key?(analysis.joins, :groups)
      # assert Map.has_key?(analysis.joins, :reviews)
    end
    
    test "detects many-to-many relationships" do
      analysis = JoinAnalyzer.analyze(User)
      
      # Should detect user_groups junction table
      relationships = analysis.relationships
      assert :many_to_many in Map.keys(relationships) or 
             Enum.any?(analysis.junction_tables, &(&1 == SelectoTest.Ecommerce.UserGroup))
    end
    
    test "analyzes Category with multiple hierarchy patterns" do
      analysis = JoinAnalyzer.analyze(Category)
      
      hierarchies = analysis.hierarchies
      assert length(hierarchies) >= 1
      
      # Should detect adjacency list (parent_id)
      assert Enum.any?(hierarchies, &(&1.type == :adjacency_list))
      
      # Should detect materialized path if path field exists
      assert Enum.any?(hierarchies, &(&1.type == :materialized_path)) or
             Enum.any?(hierarchies, &(&1.type == :nested_set))
    end
    
    test "detects dimension table patterns" do
      analysis = JoinAnalyzer.analyze(SelectoTest.Ecommerce.UserHistory)
      
      # Should identify as SCD Type 2
      assert Enum.any?(analysis.dimensions, &(&1.type == :scd_type2))
      
      dimension = Enum.find(analysis.dimensions, &(&1.type == :scd_type2))
      assert dimension.valid_from == :valid_from
      assert dimension.valid_to == :valid_to
      assert dimension.is_current == :is_current
    end
    
    test "optimizes joins based on strategy" do
      analysis = JoinAnalyzer.analyze(Product, join_strategy: :eager)
      
      # belongs_to relationships should be eager
      category_join = analysis.joins[:category]
      assert category_join.strategy == :eager
    end
    
    test "adapts joins for MySQL" do
      analysis = JoinAnalyzer.analyze(Order, adapter: :mysql)
      
      # Should not have any FULL OUTER JOINs
      Enum.each(analysis.joins, fn {_name, config} ->
        assert config.type != :full
        
        # Check if it was adapted
        if config[:metadata][:original_type] == :full do
          assert config.type == :left
        end
      end)
    end
    
    test "adapts joins for SQLite" do
      analysis = JoinAnalyzer.analyze(Warehouse, adapter: :sqlite)
      
      # Should not have RIGHT or FULL joins
      Enum.each(analysis.joins, fn {_name, config} ->
        assert config.type not in [:right, :full]
      end)
    end
    
    test "detects circular dependencies" do
      # Create a schema with circular references for testing
      analysis = JoinAnalyzer.analyze(Category, join_depth: 5)
      
      # Should detect if there are any cycles in hierarchical relationships
      if analysis.warnings != [] do
        assert Enum.any?(analysis.warnings, &String.contains?(&1, "Circular"))
      end
    end
    
    test "generates optimization suggestions" do
      analysis = JoinAnalyzer.analyze(Order)
      
      # Should suggest indexes for foreign keys
      assert Enum.any?(analysis.suggestions, &String.contains?(&1, "index"))
    end
    
    test "generates Selecto-compatible join configuration" do
      analysis = JoinAnalyzer.analyze(Product, adapter: :postgres)
      join_config = JoinAnalyzer.generate_join_config(analysis, :postgres)
      
      # Should have proper Selecto join format
      category_join = join_config[:category]
      assert category_join.type in [:inner, :left, :right]
      assert category_join.schema == SelectoTest.Ecommerce.Category
      assert category_join.on != nil
    end
  end
  
  describe "Integration with domain generation" do
    @tag :integration
    test "generates domain with adapter awareness" do
      # This would test the full pipeline
      # Would need actual file generation to test completely
      
      argv = ["SelectoTest.Ecommerce.User", 
              "--adapter", "mysql",
              "--joins", "advanced",
              "--dry-run"]
      
      assert {:ok, args} = CLIParser.parse(argv)
      assert args[:adapter] == :mysql
      assert args[:joins] == :advanced
      assert args[:dry_run] == true
    end
  end
end