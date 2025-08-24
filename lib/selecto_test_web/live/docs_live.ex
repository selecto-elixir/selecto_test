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
          <article class="prose prose-lg max-w-none
            prose-headings:text-gray-900 prose-headings:font-semibold
            prose-h1:text-3xl prose-h1:border-b prose-h1:border-gray-200 prose-h1:pb-2 prose-h1:mb-6
            prose-h2:text-2xl prose-h2:mt-8 prose-h2:mb-4
            prose-h3:text-xl prose-h3:mt-6 prose-h3:mb-3
            prose-h4:text-lg prose-h4:mt-4 prose-h4:mb-2
            prose-p:text-gray-700 prose-p:leading-relaxed prose-p:mb-4
            prose-a:text-blue-600 prose-a:hover:text-blue-800 prose-a:underline prose-a:transition-colors
            prose-strong:text-gray-900 prose-strong:font-semibold
            prose-em:text-gray-700 prose-em:italic
            prose-code:text-sm prose-code:bg-gray-100 prose-code:text-gray-800 prose-code:px-2 prose-code:py-1 prose-code:rounded prose-code:font-mono prose-code:border
            prose-pre:bg-gray-900 prose-pre:text-gray-100 prose-pre:p-4 prose-pre:rounded-lg prose-pre:overflow-x-auto prose-pre:border prose-pre:shadow-sm
            prose-pre>code:bg-transparent prose-pre>code:text-gray-100 prose-pre>code:p-0
            prose-ul:list-disc prose-ul:pl-6 prose-ul:mb-4
            prose-ol:list-decimal prose-ol:pl-6 prose-ol:mb-4
            prose-li:text-gray-700 prose-li:mb-1 prose-li:leading-relaxed
            prose-table:w-full prose-table:border-collapse prose-table:border prose-table:border-gray-300 prose-table:rounded-lg prose-table:overflow-hidden prose-table:shadow-sm
            prose-thead:bg-gray-50
            prose-th:px-6 prose-th:py-3 prose-th:text-left prose-th:font-semibold prose-th:text-gray-900 prose-th:border-b prose-th:border-gray-300
            prose-td:px-6 prose-td:py-3 prose-td:text-gray-700 prose-td:border-b prose-td:border-gray-200
            prose-tr:hover:bg-gray-50 prose-tr:transition-colors
            prose-blockquote:border-l-4 prose-blockquote:border-blue-500 prose-blockquote:pl-4 prose-blockquote:italic prose-blockquote:text-gray-600">
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
    case Earmark.as_html(content, earmark_options()) do
      {:ok, html, []} -> html
      {:ok, html, warnings} -> 
        # Log warnings but still return the HTML
        Enum.each(warnings, &IO.warn("Markdown warning: #{inspect(&1)}"))
        html
      {:error, html, errors} ->
        # Log errors but return what HTML we could generate
        Enum.each(errors, &IO.warn("Markdown error: #{inspect(&1)}"))
        html
    end
  end

  defp earmark_options do
    %Earmark.Options{
      # Enable GitHub Flavored Markdown features
      gfm: true,
      # Enable tables
      gfm_tables: true,
      # Enable strikethrough
      breaks: false,
      # Add classes for syntax highlighting (works with Prism.js or similar)
      code_class_prefix: "language-",
      # Disable unsafe HTML for security
      pure_links: true,
      # Enable footnotes
      footnotes: true,
      # Enable definition lists  
      pedantic: false,
      # Enable smartypants for smart quotes
      smartypants: true
    }
  end
end