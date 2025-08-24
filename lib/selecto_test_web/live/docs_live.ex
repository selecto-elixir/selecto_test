defmodule SelectoTestWeb.DocsLive do
  use SelectoTestWeb, :live_view

  def mount(%{"path" => path}, _session, socket) do
    doc_path = Path.join(["docs/selecto-system", path])
    
    case read_documentation(doc_path) do
      {:ok, content, title} ->
        socket = 
          socket
          |> assign(content: content)
          |> assign(title: title)
          |> assign(path: path)
          |> assign(error: nil)
        
        {:ok, socket}
      
      {:error, reason} ->
        socket = 
          socket
          |> assign(content: nil)
          |> assign(title: "Documentation Not Found")
          |> assign(path: path)
          |> assign(error: reason)
        
        {:ok, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">
      <%= if @error do %>
        <div class="bg-red-50 border border-red-200 rounded-lg p-6">
          <h1 class="text-2xl font-bold text-red-800 mb-2">Documentation Not Found</h1>
          <p class="text-red-700">Could not load documentation for: <code class="bg-red-100 px-2 py-1 rounded"><%= @path %></code></p>
          <p class="text-red-600 mt-2">Error: <%= @error %></p>
          
          <div class="mt-4">
            <.link navigate="/docs/selecto-system/system-overview" class="inline-flex items-center px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700">
              📚 Go to System Overview
            </.link>
          </div>
        </div>
      <% else %>
        <!-- Documentation Navigation -->
        <div class="bg-white border border-gray-200 rounded-lg mb-6 p-4">
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-4">
              <.link navigate="/docs/selecto-system/system-overview" class="text-blue-600 hover:text-blue-800 font-medium">
                🏠 System Overview
              </.link>
              <.link navigate="/docs/selecto-system/getting-started" class="text-green-600 hover:text-green-800">
                📖 Getting Started
              </.link>
              <.link navigate="/docs/selecto-system/best-practices" class="text-purple-600 hover:text-purple-800">
                ⭐ Best Practices
              </.link>
              <.link navigate="/docs/selecto-system/troubleshooting" class="text-orange-600 hover:text-orange-800">
                🔧 Troubleshooting
              </.link>
            </div>
            
            <div class="flex items-center gap-2 text-sm text-gray-500">
              <span>📄 Current:</span>
              <code class="bg-gray-100 px-2 py-1 rounded text-xs"><%= @path %></code>
            </div>
          </div>
        </div>

        <!-- Documentation Content -->
        <div class="bg-white border border-gray-200 rounded-lg p-8">
          <article class="prose prose-lg max-w-none">
            <%= raw(markdown_to_html(@content)) %>
          </article>
        </div>
        
        <!-- Additional Resources -->
        <div class="mt-8 bg-blue-50 border border-blue-200 rounded-lg p-6">
          <h3 class="text-lg font-semibold text-blue-900 mb-3">💡 Additional Resources</h3>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <.link navigate="/docs/selecto-system/index" class="block p-4 bg-white rounded-lg border border-blue-200 hover:border-blue-300 transition-colors">
              <div class="text-blue-600 font-medium">🔍 API Reference</div>
              <div class="text-sm text-gray-600">Complete function documentation</div>
            </.link>
            
            <.link href="/pagila" class="block p-4 bg-white rounded-lg border border-blue-200 hover:border-blue-300 transition-colors">
              <div class="text-green-600 font-medium">🎯 Live Demo</div>
              <div class="text-sm text-gray-600">Interactive Selecto demonstration</div>
            </.link>
            
            <.link href="https://github.com/selecto-elixir/selecto_test" class="block p-4 bg-white rounded-lg border border-blue-200 hover:border-blue-300 transition-colors">
              <div class="text-gray-600 font-medium">🔗 Source Code</div>
              <div class="text-sm text-gray-600">View on GitHub</div>
            </.link>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp read_documentation(doc_path) do
    # Use project root instead of compiled app directory
    project_root = File.cwd!()
    full_path = Path.join([project_root, doc_path])
    
    # Try with .md extension if not already present
    file_path = if String.ends_with?(full_path, ".md") do
      full_path
    else
      full_path <> ".md"
    end
    
    case File.read(file_path) do
      {:ok, content} ->
        title = extract_title(content)
        {:ok, content, title}
      
      {:error, :enoent} ->
        {:error, "File not found: #{file_path}"}
      
      {:error, reason} ->
        {:error, "Could not read file: #{inspect(reason)}"}
    end
  end

  defp extract_title(content) do
    case Regex.run(~r/^#\s+(.+)$/m, content) do
      [_, title] -> String.trim(title)
      _ -> "Documentation"
    end
  end

  defp markdown_to_html(content) do
    # Simple markdown-to-HTML conversion
    # This is a basic implementation - in production you'd want to use a proper markdown library
    content
    |> String.replace(~r/^# (.+)$/m, "<h1>\\1</h1>")
    |> String.replace(~r/^## (.+)$/m, "<h2>\\1</h2>")
    |> String.replace(~r/^### (.+)$/m, "<h3>\\1</h3>")
    |> String.replace(~r/^#### (.+)$/m, "<h4>\\1</h4>")
    |> String.replace(~r/\*\*(.+?)\*\*/m, "<strong>\\1</strong>")
    |> String.replace(~r/\*(.+?)\*/m, "<em>\\1</em>")
    |> String.replace(~r/`([^`]+)`/m, "<code>\\1</code>")
    |> String.replace(~r/```([^`]+)```/m, "<pre><code>\\1</code></pre>")
    |> String.replace(~r/^\- (.+)$/m, "<ul><li>\\1</li></ul>")
    |> String.replace(~r/^\d+\. (.+)$/m, "<ol><li>\\1</li></ol>")
    |> String.replace(~r/\[([^\]]+)\]\(([^)]+)\)/m, "<a href=\"\\2\">\\1</a>")
    |> String.replace(~r/\n\n/m, "</p><p>")
    |> then(&("<p>" <> &1 <> "</p>"))
    |> String.replace("<p><h", "<h")
    |> String.replace("</h1></p>", "</h1>")
    |> String.replace("</h2></p>", "</h2>")
    |> String.replace("</h3></p>", "</h3>")
    |> String.replace("</h4></p>", "</h4>")
    |> String.replace("<p><ul>", "<ul>")
    |> String.replace("</ul></p>", "</ul>")
    |> String.replace("<p><ol>", "<ol>")
    |> String.replace("</ol></p>", "</ol>")
    |> String.replace("<p><pre>", "<pre>")
    |> String.replace("</pre></p>", "</pre>")
  end
end