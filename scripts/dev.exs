#!/usr/bin/env elixir

# Development helper script
# Usage: elixir scripts/dev.exs [command]

defmodule DevHelper do
  @commands %{
    "server" => "Start Phoenix server with dev configuration",
    "test" => "Run tests with parallel execution",
    "test-watch" => "Run tests in watch mode",
    "setup" => "Full development setup",
    "reset" => "Reset database and restart",
    "compile" => "Clean compile all dependencies",
    "format" => "Format code and check style",
    "deps" => "Update and compile dependencies",
    "coverage" => "Generate test coverage report"
  }

  def run([]) do
    IO.puts("🔧 Selecto Test Development Helper")
    IO.puts("")
    IO.puts("Available commands:")
    
    for {cmd, desc} <- @commands do
      IO.puts("  #{String.pad_trailing(cmd, 12)} #{desc}")
    end
    
    IO.puts("")
    IO.puts("Usage: elixir scripts/dev.exs [command]")
  end

  def run(["server"]) do
    IO.puts("🚀 Starting Phoenix server with dev configuration...")
    System.cmd("mix", ["phx.server"], into: IO.stream(:stdio, :line))
  end

  def run(["test"]) do
    IO.puts("🧪 Running tests with parallel execution...")
    System.cmd("mix", ["test", "--max-failures", "3"], into: IO.stream(:stdio, :line))
  end

  def run(["test-watch"]) do
    IO.puts("👀 Running tests in watch mode...")
    case System.cmd("which", ["fswatch"], stderr_to_stdout: true) do
      {_, 0} ->
        spawn(fn ->
          System.cmd("fswatch", ["-o", "lib/", "test/"], 
            into: fn chunk, acc ->
              IO.puts("🔄 File changes detected, running tests...")
              System.cmd("mix", ["test", "--max-failures", "1"])
              acc
            end
          )
        end)
        
        # Initial test run
        System.cmd("mix", ["test"], into: IO.stream(:stdio, :line))
        
        IO.puts("Watching for file changes... Press Ctrl+C to stop")
        Process.sleep(:infinity)
      
      _ ->
        IO.puts("❌ fswatch not found. Install with: brew install fswatch")
    end
  end

  def run(["setup"]) do
    IO.puts("⚙️  Running full development setup...")
    commands = [
      ["deps.get"],
      ["deps.compile"],
      ["ecto.setup"],
      ["assets.setup"],
      ["assets.build"]
    ]
    
    run_commands(commands)
  end

  def run(["reset"]) do
    IO.puts("🔄 Resetting database and restarting...")
    commands = [
      ["ecto.reset"],
      ["compile", "--force"]
    ]
    
    run_commands(commands)
  end

  def run(["compile"]) do
    IO.puts("🔨 Clean compiling all dependencies...")
    commands = [
      ["deps.clean", "--all"],
      ["clean"],
      ["deps.get"],
      ["compile"]
    ]
    
    run_commands(commands)
  end

  def run(["format"]) do
    IO.puts("✨ Formatting code and checking style...")
    System.cmd("mix", ["format"], into: IO.stream(:stdio, :line))
  end

  def run(["deps"]) do
    IO.puts("📦 Updating and compiling dependencies...")
    commands = [
      ["deps.get"],
      ["deps.update", "--all"],
      ["deps.compile"]
    ]
    
    run_commands(commands)
  end

  def run(["coverage"]) do
    IO.puts("📊 Generating test coverage report...")
    System.cmd("mix", ["coveralls.html"], into: IO.stream(:stdio, :line))
    IO.puts("Coverage report generated at cover/excoveralls.html")
  end

  def run([unknown]) do
    IO.puts("❌ Unknown command: #{unknown}")
    run([])
  end

  defp run_commands(commands) do
    Enum.each(commands, fn cmd ->
      IO.puts("Running: mix #{Enum.join(cmd, " ")}")
      case System.cmd("mix", cmd, into: IO.stream(:stdio, :line)) do
        {_, 0} -> IO.puts("✅ Success")
        {_, code} -> IO.puts("❌ Failed with exit code #{code}")
      end
      IO.puts("")
    end)
  end
end

System.argv()
|> DevHelper.run()