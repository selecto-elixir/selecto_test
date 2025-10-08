defmodule SelectoMixTest do
  use ExUnit.Case, async: false
  
  # Test the improvements we've made to SelectoMix
  
  describe "Adapter Detection" do
    test "detects PostgreSQL from SelectoTest.Repo" do
      alias SelectoMix.AdapterDetector
      
      result = AdapterDetector.detect(repo: SelectoTest.Repo)
      assert {:ok, :postgres} = result
    end
    
    test "provides correct features for different adapters" do
      alias SelectoMix.AdapterDetector
      
      # PostgreSQL features
      pg_features = AdapterDetector.get_features(:postgres)
      assert pg_features[:arrays] == true
      assert pg_features[:ctes] == true
      assert pg_features[:full_outer_join] == true
      
      # MySQL features
      mysql_features = AdapterDetector.get_features(:mysql, "8.0")
      assert mysql_features[:arrays] == false
      assert mysql_features[:ctes] == true
      assert mysql_features[:full_outer_join] == false
      
      # SQLite features  
      sqlite_features = AdapterDetector.get_features(:sqlite, "3.35")
      assert sqlite_features[:arrays] == false
      assert sqlite_features[:window_functions] == true
    end
  end
  
  describe "CLI Parser" do
    test "parses command-line arguments correctly" do
      alias SelectoMix.CLIParser
      
      argv = ["User", "--adapter", "mysql", "--joins", "advanced", 
              "--output", "lib/domains", "--force"]
      
      {:ok, args} = CLIParser.parse(argv)
      
      assert args[:adapter] == :mysql
      assert args[:joins] == :advanced
      assert args[:output] == "lib/domains"
      assert args[:force] == true
      assert "User" in args[:schemas]
    end
    
    test "validates argument combinations" do
      alias SelectoMix.CLIParser
      
      # Test conflicting options
      argv1 = ["--quiet", "--verbose"]
      {:ok, args1} = CLIParser.parse(argv1)
      assert {:error, errors} = CLIParser.validate_args(args1)
      assert Enum.any?(errors, &String.contains?(&1, "quiet"))
      
      # Test saved-views requires live
      argv2 = ["--saved-views"]
      {:ok, args2} = CLIParser.parse(argv2)
      assert {:error, errors} = CLIParser.validate_args(args2)
      assert Enum.any?(errors, &String.contains?(&1, "saved-views"))
    end
  end
  
  describe "Join Analyzer" do
    test "analyzes basic schema relationships" do
      alias SelectoMix.JoinAnalyzer

      # Analyze the User schema we created
      analysis = JoinAnalyzer.analyze(SelectoTest.Ecommerce.User)

      # Check that basic joins were detected (addresses is commented out)
      # assert Map.has_key?(analysis.joins, :addresses)
      assert Map.has_key?(analysis.joins, :orders)
      assert Map.has_key?(analysis.joins, :groups)

      # Check for hierarchical detection
      assert length(analysis.hierarchies) > 0
    end
    
    test "adapts joins for different databases" do
      alias SelectoMix.JoinAnalyzer
      
      # MySQL adapter - shouldn't have FULL OUTER JOIN
      mysql_analysis = JoinAnalyzer.analyze(SelectoTest.Ecommerce.Order, adapter: :mysql)
      
      Enum.each(mysql_analysis.joins, fn {_name, config} ->
        assert config.type != :full
      end)
      
      # SQLite adapter - shouldn't have RIGHT or FULL joins
      sqlite_analysis = JoinAnalyzer.analyze(SelectoTest.Ecommerce.Product, adapter: :sqlite)
      
      Enum.each(sqlite_analysis.joins, fn {_name, config} ->
        assert config.type not in [:right, :full]
      end)
    end
  end
  
  describe "Integration" do
    @tag :integration
    test "full pipeline with complex schema" do
      alias SelectoMix.{CLIParser, AdapterDetector, JoinAnalyzer}
      
      # Simulate full domain generation pipeline
      argv = ["SelectoTest.Ecommerce.User", "--adapter", "mysql", 
              "--joins", "advanced", "--dry-run"]
      
      # Parse arguments
      {:ok, args} = CLIParser.parse(argv)
      assert args[:adapter] == :mysql
      
      # Detect adapter features
      features = AdapterDetector.get_features(args[:adapter], "8.0")
      assert features[:arrays] == false
      
      # Analyze joins
      analysis = JoinAnalyzer.analyze(SelectoTest.Ecommerce.User,
        adapter: args[:adapter])
      # addresses is commented out, check for associations that exist
      assert Map.has_key?(analysis.joins, :orders)
      assert Map.has_key?(analysis.joins, :groups)
    end
  end
end