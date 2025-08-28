# SelectoComponents Custom Styling and Theming Plan

## Overview

Create a comprehensive styling and theming system for SelectoComponents that enables implementors to fully customize the appearance, behavior, and branding of all LiveView components while maintaining functionality and accessibility.

## Current State Analysis

### Existing Styling Limitations
- Hard-coded CSS classes with minimal customization options
- No comprehensive theming system or design tokens
- Limited brand customization capabilities
- CSS conflicts when integrating with existing applications
- No dark mode or accessibility theme support
- Difficulty overriding component styles without !important

### Current Styling Approach
```elixir
# Current basic styling in components
def render_table(assigns) do
  ~H"""
  <table class="selecto-table min-w-full bg-white border border-gray-200">
    <thead class="bg-gray-50">
      <tr>
        <%= for field <- @fields do %>
          <th class="px-4 py-2 text-left text-sm font-medium text-gray-900">
            <%= field %>
          </th>
        <% end %>
      </tr>
    </thead>
    <!-- Hard-coded Tailwind classes throughout -->
  </table>
  """
end
```

## Architecture Design

### Theming System Structure
```
vendor/selecto_components/lib/selecto_components/
├── theming/                                      # Theming system namespace
│   ├── theme_registry.ex                        # Theme registration and management
│   ├── theme_resolver.ex                        # Theme resolution and inheritance
│   ├── design_tokens.ex                         # Design token management
│   ├── css_generator.ex                         # Dynamic CSS generation
│   └── theme_validator.ex                       # Theme validation and testing
├── themes/                                       # Built-in themes
│   ├── default.ex                               # Default Selecto theme
│   ├── minimal.ex                               # Minimal/clean theme
│   ├── dark.ex                                  # Dark mode theme
│   ├── enterprise.ex                            # Professional enterprise theme
│   └── accessibility.ex                         # High contrast accessibility theme
├── styling/                                      # Styling utilities
│   ├── component_styles.ex                     # Component-specific styling
│   ├── utility_classes.ex                      # Utility class generation
│   ├── responsive_breakpoints.ex               # Responsive design utilities
│   └── animation_presets.ex                    # Animation and transition presets
└── assets/                                       # Theme assets
    ├── css/                                     # Generated CSS files
    │   ├── themes/                              # Per-theme CSS
    │   └── components/                          # Component-specific CSS
    ├── fonts/                                   # Custom fonts
    └── icons/                                   # Custom icon sets
```

### API Design

#### Theme Configuration
```elixir
# Comprehensive theme configuration
theme_config = %{
  # Theme identification
  name: "corporate_theme",
  version: "1.0.0",
  description: "Corporate branding theme for SelectoComponents",
  author: "Your Company",
  
  # Design tokens
  design_tokens: %{
    # Color palette
    colors: %{
      # Primary brand colors
      primary: %{
        50 => "#eff6ff",
        100 => "#dbeafe", 
        500 => "#3b82f6",  # Main primary color
        600 => "#2563eb",
        900 => "#1e3a8a"
      },
      
      # Semantic colors
      semantic: %{
        success => "#10b981",
        warning => "#f59e0b", 
        error => "#ef4444",
        info => "#06b6d4"
      },
      
      # Neutral colors for text and backgrounds
      neutral: %{
        0 => "#ffffff",    # Pure white
        50 => "#f9fafb",   # Light background
        100 => "#f3f4f6",  # Card backgrounds
        500 => "#6b7280",  # Text secondary
        900 => "#111827"   # Text primary
      }
    },
    
    # Typography scale
    typography: %{
      font_families: %{
        sans: ["Inter", "system-ui", "sans-serif"],
        mono: ["JetBrains Mono", "Menlo", "monospace"],
        display: ["Poppins", "Inter", "sans-serif"]
      },
      
      font_sizes: %{
        xs: "0.75rem",     # 12px
        sm: "0.875rem",    # 14px  
        base: "1rem",      # 16px
        lg: "1.125rem",    # 18px
        xl: "1.25rem",     # 20px
        "2xl": "1.5rem",   # 24px
        "3xl": "1.875rem"  # 30px
      },
      
      font_weights: %{
        normal: "400",
        medium: "500", 
        semibold: "600",
        bold: "700"
      },
      
      line_heights: %{
        tight: "1.25",
        normal: "1.5",
        relaxed: "1.625"
      }
    },
    
    # Spacing scale
    spacing: %{
      0 => "0px",
      1 => "0.25rem",   # 4px
      2 => "0.5rem",    # 8px
      3 => "0.75rem",   # 12px
      4 => "1rem",      # 16px
      6 => "1.5rem",    # 24px
      8 => "2rem",      # 32px
      12 => "3rem",     # 48px
      16 => "4rem"      # 64px
    },
    
    # Border radius
    border_radius: %{
      none: "0px",
      sm: "0.125rem",   # 2px
      base: "0.25rem",  # 4px
      md: "0.375rem",   # 6px
      lg: "0.5rem",     # 8px
      xl: "0.75rem",    # 12px
      full: "9999px"    # Pills/circles
    },
    
    # Shadows
    shadows: %{
      sm: "0 1px 2px 0 rgb(0 0 0 / 0.05)",
      base: "0 1px 3px 0 rgb(0 0 0 / 0.1), 0 1px 2px -1px rgb(0 0 0 / 0.1)",
      md: "0 4px 6px -1px rgb(0 0 0 / 0.1), 0 2px 4px -2px rgb(0 0 0 / 0.1)",
      lg: "0 10px 15px -3px rgb(0 0 0 / 0.1), 0 4px 6px -4px rgb(0 0 0 / 0.1)",
      xl: "0 20px 25px -5px rgb(0 0 0 / 0.1), 0 8px 10px -6px rgb(0 0 0 / 0.1)"
    },
    
    # Transitions and animations
    transitions: %{
      duration: %{
        75 => "75ms",
        100 => "100ms", 
        150 => "150ms",
        200 => "200ms",
        300 => "300ms",
        500 => "500ms"
      },
      timing: %{
        linear: "linear",
        ease: "ease",
        ease_in: "cubic-bezier(0.4, 0, 1, 1)",
        ease_out: "cubic-bezier(0, 0, 0.2, 1)",
        ease_in_out: "cubic-bezier(0.4, 0, 0.2, 1)"
      }
    }
  },
  
  # Component-specific styling
  components: %{
    # Table styling
    table: %{
      container: %{
        background: "var(--color-neutral-0)",
        border: "1px solid var(--color-neutral-200)", 
        border_radius: "var(--radius-md)",
        shadow: "var(--shadow-sm)"
      },
      
      header: %{
        background: "var(--color-neutral-50)",
        font_weight: "var(--font-weight-semibold)",
        font_size: "var(--font-size-sm)",
        color: "var(--color-neutral-700)",
        padding: "var(--spacing-3) var(--spacing-4)"
      },
      
      row: %{
        border_bottom: "1px solid var(--color-neutral-100)",
        hover_background: "var(--color-neutral-50)",
        selected_background: "var(--color-primary-50)"
      },
      
      cell: %{
        padding: "var(--spacing-3) var(--spacing-4)",
        font_size: "var(--font-size-sm)",
        color: "var(--color-neutral-900)"
      }
    },
    
    # Button styling  
    button: %{
      base: %{
        font_weight: "var(--font-weight-medium)",
        border_radius: "var(--radius-md)",
        transition: "all var(--duration-150) var(--timing-ease-in-out)",
        font_family: "var(--font-sans)"
      },
      
      variants: %{
        primary: %{
          background: "var(--color-primary-500)",
          color: "var(--color-neutral-0)",
          hover_background: "var(--color-primary-600)",
          focus_ring: "2px solid var(--color-primary-200)"
        },
        
        secondary: %{
          background: "var(--color-neutral-100)",
          color: "var(--color-neutral-700)",
          hover_background: "var(--color-neutral-200)", 
          border: "1px solid var(--color-neutral-300)"
        }
      },
      
      sizes: %{
        sm: %{
          padding: "var(--spacing-2) var(--spacing-3)",
          font_size: "var(--font-size-sm)"
        },
        md: %{
          padding: "var(--spacing-3) var(--spacing-4)",
          font_size: "var(--font-size-base)"
        },
        lg: %{
          padding: "var(--spacing-4) var(--spacing-6)",
          font_size: "var(--font-size-lg)"
        }
      }
    },
    
    # Form input styling
    input: %{
      base: %{
        border: "1px solid var(--color-neutral-300)",
        border_radius: "var(--radius-md)",
        background: "var(--color-neutral-0)",
        padding: "var(--spacing-3)",
        font_size: "var(--font-size-base)",
        transition: "border-color var(--duration-150) var(--timing-ease-in-out)"
      },
      
      states: %{
        focus: %{
          border_color: "var(--color-primary-500)",
          ring: "2px solid var(--color-primary-100)",
          outline: "none"
        },
        
        error: %{
          border_color: "var(--color-error)",
          ring: "2px solid rgba(239, 68, 68, 0.1)"
        },
        
        disabled: %{
          background: "var(--color-neutral-100)",
          color: "var(--color-neutral-500)",
          cursor: "not-allowed"
        }
      }
    },
    
    # Modal styling
    modal: %{
      overlay: %{
        background: "rgba(0, 0, 0, 0.5)",
        backdrop_filter: "blur(4px)"
      },
      
      container: %{
        background: "var(--color-neutral-0)",
        border_radius: "var(--radius-lg)",
        shadow: "var(--shadow-xl)",
        max_width: "90vw",
        max_height: "90vh"
      },
      
      header: %{
        padding: "var(--spacing-6)",
        border_bottom: "1px solid var(--color-neutral-200)"
      }
    }
  },
  
  # Responsive breakpoints
  breakpoints: %{
    sm: "640px",
    md: "768px", 
    lg: "1024px",
    xl: "1280px",
    "2xl": "1536px"
  },
  
  # Theme variants (dark mode, high contrast, etc.)
  variants: %{
    dark: %{
      colors: %{
        neutral: %{
          0 => "#000000",
          50 => "#0f172a",
          100 => "#1e293b",
          500 => "#94a3b8",
          900 => "#f1f5f9"
        }
      }
    },
    
    high_contrast: %{
      colors: %{
        primary: %{
          500 => "#000000"
        },
        neutral: %{
          500 => "#000000",
          900 => "#000000"
        }
      }
    }
  }
}
```

#### Theme Implementation in Components
```elixir
# Enhanced component with full theme support
defmodule SelectoComponents.EnhancedTable do
  use SelectoComponents, :component
  import SelectoComponents.Theming
  
  def render_table(assigns) do
    # Resolve theme for this component
    theme = resolve_theme(assigns[:theme] || :default)
    table_styles = get_component_styles(theme, :table)
    
    assigns = assign(assigns, :theme_styles, table_styles)
    
    ~H"""
    <div class={["selecto-table-container", theme_class(@theme_styles, :container)]}>
      <table class={["selecto-table", theme_class(@theme_styles, :table)]}>
        <thead class={theme_class(@theme_styles, :header)}>
          <tr>
            <%= for field <- @fields do %>
              <th class={theme_class(@theme_styles, :header_cell)}>
                <div class="header-content">
                  <span><%= field.label %></span>
                  
                  <%= if field.sortable do %>
                    <button 
                      class={theme_class(@theme_styles, :sort_button)}
                      phx-click="sort_column"
                      phx-value-field={field.name}
                    >
                      <.icon name={sort_icon(field, @sort_state)} />
                    </button>
                  <% end %>
                </div>
              </th>
            <% end %>
          </tr>
        </thead>
        
        <tbody>
          <%= for {row, index} <- Enum.with_index(@data) do %>
            <tr class={[
              theme_class(@theme_styles, :row),
              row_variant_class(@theme_styles, row, index)
            ]}>
              <%= for field <- @fields do %>
                <td class={theme_class(@theme_styles, :cell)}>
                  <.render_cell_content 
                    value={Map.get(row, field.name)} 
                    field={field}
                    theme={@theme_styles}
                  />
                </td>
              <% end %>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    
    <!-- Theme-aware CSS custom properties -->
    <style>
      .selecto-table-container {
        <%= css_custom_properties(@theme_styles) %>
      }
    </style>
    """
  end
  
  # Theme-aware cell rendering
  def render_cell_content(%{value: value, field: field, theme: theme} = assigns) do
    cell_class = case field.type do
      :currency -> theme_class(theme, :currency_cell)
      :date -> theme_class(theme, :date_cell)
      :status -> theme_class(theme, :status_cell)
      _ -> theme_class(theme, :text_cell)
    end
    
    assigns = assign(assigns, :cell_class, cell_class)
    
    ~H"""
    <span class={@cell_class}>
      <%= format_cell_value(@value, @field) %>
    </span>
    """
  end
end
```

#### Theme Builder Interface
```elixir
# Interactive theme builder for implementors
theme_builder_config = %{
  # Visual theme editor
  editor: %{
    sections: [
      %{
        name: "colors",
        title: "Colors",
        description: "Configure your brand colors and semantic colors",
        editor_type: :color_palette,
        
        fields: [
          %{
            name: "primary_color",
            type: :color_picker,
            label: "Primary Brand Color",
            description: "Main brand color used for buttons, links, and accents",
            default: "#3b82f6",
            generates: [:primary_palette]  # Auto-generate color scale
          },
          
          %{
            name: "secondary_color", 
            type: :color_picker,
            label: "Secondary Color",
            default: "#6b7280"
          },
          
          %{
            name: "background_color",
            type: :color_picker, 
            label: "Background Color",
            default: "#ffffff"
          }
        ]
      },
      
      %{
        name: "typography",
        title: "Typography", 
        description: "Configure fonts and text styling",
        editor_type: :typography_editor,
        
        fields: [
          %{
            name: "font_family",
            type: :font_selector,
            label: "Primary Font",
            options: :google_fonts,  # Integration with Google Fonts
            preview_text: "The quick brown fox jumps over the lazy dog"
          },
          
          %{
            name: "font_scale",
            type: :slider,
            label: "Font Size Scale",
            min: 0.8,
            max: 1.4,
            step: 0.1,
            default: 1.0
          }
        ]
      },
      
      %{
        name: "spacing",
        title: "Spacing & Layout",
        description: "Configure spacing, borders, and layout properties",
        
        fields: [
          %{
            name: "base_spacing",
            type: :slider,
            label: "Base Spacing Unit (rem)",
            min: 0.5,
            max: 2.0,
            step: 0.25,
            default: 1.0
          },
          
          %{
            name: "border_radius",
            type: :slider,
            label: "Border Radius",
            min: 0,
            max: 20,
            step: 1,
            default: 6,
            unit: "px"
          }
        ]
      },
      
      %{
        name: "components",
        title: "Component Styling",
        description: "Customize individual component appearances",
        editor_type: :component_editor,
        
        components: [
          %{
            name: "table",
            preview: :live_table,
            customizable_properties: [
              "header_background",
              "row_hover_color", 
              "border_color",
              "cell_padding"
            ]
          },
          
          %{
            name: "button",
            preview: :button_showcase,
            customizable_properties: [
              "primary_background",
              "primary_text_color",
              "hover_effect",
              "border_radius"
            ]
          }
        ]
      }
    ]
  },
  
  # Real-time preview
  preview: %{
    enabled: true,
    components: ["table", "forms", "modals", "buttons"],
    sample_data: :realistic,  # Use realistic sample data
    responsive_preview: true,  # Show mobile/tablet views
    dark_mode_toggle: true
  },
  
  # Export and sharing
  export: %{
    formats: [:elixir_config, :css_file, :design_tokens_json],
    include_documentation: true,
    generate_usage_guide: true
  }
}
```

## Theme System Features

### 1. Design Token Management
```elixir
# Centralized design token system
defmodule SelectoComponents.DesignTokens do
  @moduledoc """
  Centralized design token management for consistent theming across components.
  """
  
  # Register design tokens from theme
  def register_tokens(theme_config) do
    tokens = theme_config.design_tokens
    
    # Convert to CSS custom properties
    css_properties = generate_css_properties(tokens)
    
    # Store in ETS for fast access
    :ets.insert(:selecto_design_tokens, {theme_config.name, css_properties})
  end
  
  # Generate CSS custom properties
  def generate_css_properties(tokens) do
    tokens
    |> flatten_tokens("--")
    |> Enum.map(fn {key, value} -> "#{key}: #{value};" end)
    |> Enum.join("\n")
  end
  
  # Example output:
  # --color-primary-50: #eff6ff;
  # --color-primary-500: #3b82f6;
  # --font-size-base: 1rem;
  # --spacing-4: 1rem;
  
  defp flatten_tokens(tokens, prefix, acc \\ [])
  
  defp flatten_tokens(map, prefix, acc) when is_map(map) do
    Enum.reduce(map, acc, fn {key, value}, acc ->
      new_prefix = "#{prefix}-#{key}"
      flatten_tokens(value, new_prefix, acc)
    end)
  end
  
  defp flatten_tokens(value, prefix, acc) do
    [{prefix, value} | acc]
  end
end
```

### 2. Dynamic CSS Generation
```elixir
# Generate CSS at runtime based on theme
defmodule SelectoComponents.CSSGenerator do
  @moduledoc """
  Generate CSS dynamically based on theme configuration.
  """
  
  def generate_theme_css(theme_config) do
    """
    /* Generated CSS for theme: #{theme_config.name} */
    :root {
      #{generate_css_variables(theme_config.design_tokens)}
    }
    
    #{generate_component_css(theme_config.components)}
    
    #{generate_responsive_css(theme_config.breakpoints)}
    
    #{generate_variant_css(theme_config.variants)}
    """
  end
  
  def generate_component_css(components) do
    components
    |> Enum.map(fn {component_name, styles} ->
      generate_component_rules(component_name, styles)
    end)
    |> Enum.join("\n\n")
  end
  
  defp generate_component_rules(component_name, styles) do
    """
    /* #{String.upcase(to_string(component_name))} Component */
    .selecto-#{component_name} {
      #{generate_style_rules(styles)}
    }
    """
  end
  
  defp generate_style_rules(styles) do
    styles
    |> Enum.map(fn {property, value} ->
      css_property = property |> to_string() |> String.replace("_", "-")
      "  #{css_property}: #{value};"
    end)
    |> Enum.join("\n")
  end
end
```

### 3. Theme Inheritance and Variants
```elixir
# Support theme inheritance and variants (dark mode, high contrast)
defmodule SelectoComponents.ThemeResolver do
  @moduledoc """
  Resolve themes with inheritance and variant support.
  """
  
  def resolve_theme(theme_name, variant \\ nil) do
    base_theme = get_base_theme(theme_name)
    
    case variant do
      nil -> base_theme
      variant_name -> apply_variant(base_theme, variant_name)
    end
  end
  
  def apply_variant(base_theme, variant_name) do
    variant_overrides = get_in(base_theme, [:variants, variant_name]) || %{}
    deep_merge(base_theme, variant_overrides)
  end
  
  # Dark mode theme generation
  def generate_dark_mode_variant(base_theme) do
    dark_overrides = %{
      design_tokens: %{
        colors: %{
          neutral: %{
            0 => base_theme.design_tokens.colors.neutral[900],    # Flip background
            50 => base_theme.design_tokens.colors.neutral[800],
            100 => base_theme.design_tokens.colors.neutral[700],
            500 => base_theme.design_tokens.colors.neutral[400],  # Flip text
            900 => base_theme.design_tokens.colors.neutral[0]
          }
        }
      },
      components: %{
        table: %{
          container: %{
            background: "var(--color-neutral-900)",
            border: "1px solid var(--color-neutral-700)"
          }
        }
      }
    }
    
    deep_merge(base_theme, dark_overrides)
  end
  
  defp deep_merge(left, right) do
    Map.merge(left, right, &deep_resolve/3)
  end
  
  defp deep_resolve(_key, left, right) when is_map(left) and is_map(right) do
    deep_merge(left, right)
  end
  
  defp deep_resolve(_key, _left, right), do: right
end
```

## Implementation Phases

### Phase 1: Core Theming Infrastructure (Week 1-3)
- [ ] Design token system with CSS custom property generation
- [ ] Theme registry and resolution system
- [ ] Basic theme configuration structure
- [ ] CSS generation pipeline for themes

### Phase 2: Component Integration (Week 4-5)
- [ ] Update all SelectoComponents to support theme system
- [ ] Theme-aware styling utilities and helpers
- [ ] Component style inheritance and customization
- [ ] Responsive breakpoint integration

### Phase 3: Built-in Themes and Variants (Week 6-7)
- [ ] Default SelectoComponents theme
- [ ] Dark mode theme variant
- [ ] Accessibility/high contrast theme
- [ ] Minimal and enterprise themes
- [ ] Theme inheritance and variant system

### Phase 4: Theme Builder and Tooling (Week 8-10)
- [ ] Interactive theme builder interface
- [ ] Real-time theme preview system
- [ ] Theme export in multiple formats
- [ ] Theme validation and testing tools
- [ ] Documentation and migration guides

## Advanced Theming Features

### 1. CSS-in-JS Integration
```elixir
# Optional CSS-in-JS approach for dynamic styling
defmodule SelectoComponents.DynamicStyles do
  @moduledoc """
  Generate component styles dynamically based on props and theme.
  """
  
  def generate_component_styles(component_name, props, theme) do
    base_styles = get_component_base_styles(component_name, theme)
    variant_styles = get_variant_styles(component_name, props[:variant], theme)
    state_styles = get_state_styles(component_name, props[:state], theme)
    
    merge_styles([base_styles, variant_styles, state_styles])
  end
  
  # Example usage in component
  def render_button(assigns) do
    dynamic_styles = generate_component_styles(:button, assigns, assigns[:theme])
    assigns = assign(assigns, :computed_styles, dynamic_styles)
    
    ~H"""
    <button 
      class={[@computed_styles.classes]}
      style={@computed_styles.inline_styles}
    >
      <%= @label %>
    </button>
    """
  end
end
```

### 2. Brand Kit Integration
```elixir
# Integration with brand guidelines and design systems
brand_kit_integration = %{
  # Import from design tools
  import_sources: [
    %{type: :figma, api_key: "figma_api_key", file_id: "design_file_id"},
    %{type: :sketch, file_path: "brand_kit.sketch"},
    %{type: :adobe_xd, cloud_document_id: "xd_doc_id"}
  ],
  
  # Brand asset management
  assets: %{
    logos: %{
      primary: "logo-primary.svg",
      secondary: "logo-secondary.svg", 
      mark: "logo-mark.svg"
    },
    
    icons: %{
      custom_icon_set: "custom-icons.svg",
      fallback_to: :heroicons  # Fallback icon library
    },
    
    fonts: %{
      primary: %{
        name: "Brand Font",
        files: ["brand-font-regular.woff2", "brand-font-bold.woff2"],
        fallback: ["Inter", "system-ui"]
      }
    }
  },
  
  # Brand compliance checking
  compliance: %{
    enforce_brand_colors: true,
    allow_color_variations: false,
    require_brand_fonts: true,
    accessibility_requirements: :wcag_aa
  }
}
```

### 3. Theme Performance Optimization
```elixir
# Optimize theme loading and CSS generation
performance_optimization = %{
  # CSS optimization
  css_optimization: %{
    minify_output: true,
    remove_unused_styles: true,
    critical_css_extraction: true,
    lazy_load_non_critical: true
  },
  
  # Caching strategies
  caching: %{
    theme_css_cache: %{
      enabled: true,
      ttl: {:hours, 24},
      invalidation_strategy: :version_based
    },
    
    computed_styles_cache: %{
      enabled: true,
      max_entries: 1000,
      eviction_policy: :lru
    }
  },
  
  # Bundle optimization
  bundling: %{
    split_themes: true,        # Separate CSS files per theme
    tree_shake_unused: true,   # Remove unused design tokens
    compress_tokens: true      # Compress design token JSON
  }
}
```

## Theme Customization Examples

### Corporate Theme Example
```elixir
# Complete corporate theme configuration
corporate_theme = %{
  name: "corporate_professional",
  description: "Professional corporate theme with enterprise styling",
  
  design_tokens: %{
    colors: %{
      primary: %{
        50 => "#f0f9ff",
        500 => "#0ea5e9",   # Corporate blue
        900 => "#0c4a6e"
      },
      
      neutral: %{
        0 => "#ffffff",
        50 => "#f8fafc",
        100 => "#f1f5f9",
        900 => "#0f172a"
      }
    },
    
    typography: %{
      font_families: %{
        sans: ["Inter", "system-ui", "sans-serif"],
        display: ["Inter", "system-ui", "sans-serif"]
      }
    },
    
    spacing: %{
      # Generous spacing for professional look
      4 => "1.25rem",    # 20px instead of 16px
      6 => "2rem",       # 32px instead of 24px
      8 => "2.5rem"      # 40px instead of 32px  
    }
  },
  
  components: %{
    table: %{
      container: %{
        border_radius: "0.5rem",
        shadow: "0 4px 6px -1px rgb(0 0 0 / 0.1)"
      },
      
      header: %{
        background: "linear-gradient(135deg, var(--color-neutral-50) 0%, var(--color-neutral-100) 100%)",
        font_weight: "600",
        letter_spacing: "0.025em"
      }
    },
    
    button: %{
      variants: %{
        primary: %{
          background: "linear-gradient(135deg, var(--color-primary-500) 0%, var(--color-primary-600) 100%)",
          box_shadow: "0 2px 4px rgb(14 165 233 / 0.2)"
        }
      }
    }
  }
}
```

### Accessibility Theme Example
```elixir
# High contrast accessibility theme
accessibility_theme = %{
  name: "high_contrast_accessible",
  description: "High contrast theme for accessibility compliance",
  
  design_tokens: %{
    colors: %{
      # High contrast color pairs
      primary: %{
        500 => "#000000",    # Pure black for maximum contrast
        600 => "#000000"
      },
      
      neutral: %{
        0 => "#ffffff",      # Pure white backgrounds
        900 => "#000000"     # Pure black text
      },
      
      semantic: %{
        error => "#d32f2f",     # High contrast red
        success => "#2e7d32",   # High contrast green
        warning => "#f57c00"    # High contrast orange
      }
    },
    
    typography: %{
      font_sizes: %{
        # Larger font sizes for readability
        base: "1.125rem",   # 18px instead of 16px
        lg: "1.375rem",     # 22px instead of 18px
        xl: "1.5rem"        # 24px instead of 20px
      },
      
      line_heights: %{
        normal: "1.6",      # Increased line height
        relaxed: "1.8"
      }
    }
  },
  
  components: %{
    button: %{
      base: %{
        border: "2px solid currentColor",  # Always visible borders
        font_weight: "700"                 # Bold text for visibility
      },
      
      variants: %{
        primary: %{
          background: "#000000",
          color: "#ffffff",
          hover_background: "#333333"
        }
      }
    },
    
    input: %{
      base: %{
        border: "2px solid #000000",       # High contrast borders
        font_size: "1.125rem"              # Larger input text
      },
      
      states: %{
        focus: %{
          border_color: "#000000",
          ring: "3px solid #ffeb3b",       # High contrast focus ring
          outline: "none"
        }
      }
    }
  }
}
```

## Testing and Validation

### Theme Testing Framework
```elixir
# Automated theme testing
defmodule SelectoComponents.ThemeTesting do
  @moduledoc """
  Automated testing framework for themes and styling.
  """
  
  def validate_theme(theme_config) do
    with :ok <- validate_structure(theme_config),
         :ok <- validate_colors(theme_config),
         :ok <- validate_accessibility(theme_config),
         :ok <- validate_performance(theme_config) do
      {:ok, "Theme validation passed"}
    else
      {:error, reason} -> {:error, reason}
    end
  end
  
  def validate_accessibility(theme_config) do
    color_combinations = extract_color_combinations(theme_config)
    
    failing_combinations = 
      color_combinations
      |> Enum.filter(fn {bg, fg} -> 
           contrast_ratio(bg, fg) < 4.5  # WCAG AA standard
         end)
    
    case failing_combinations do
      [] -> :ok
      failures -> {:error, "Low contrast combinations: #{inspect(failures)}"}
    end
  end
  
  def generate_theme_report(theme_config) do
    %{
      name: theme_config.name,
      validation: validate_theme(theme_config),
      accessibility_score: calculate_accessibility_score(theme_config),
      performance_metrics: analyze_performance(theme_config),
      browser_compatibility: check_browser_support(theme_config)
    }
  end
end
```

### Visual Regression Testing
```elixir
# Visual testing for theme changes
visual_testing_config = %{
  # Screenshot comparison testing
  visual_regression: %{
    enabled: true,
    tools: [:percy, :chromatic, :backstop],
    
    test_scenarios: [
      %{component: :table, variants: [:default, :dark, :accessible]},
      %{component: :forms, variants: [:default, :dark, :accessible]},
      %{component: :modals, variants: [:default, :dark, :accessible]}
    ],
    
    breakpoints: ["mobile", "tablet", "desktop"],
    threshold: 0.02  # 2% pixel difference threshold
  },
  
  # Cross-browser testing
  browser_testing: %{
    browsers: ["chrome", "firefox", "safari", "edge"],
    versions: ["current", "current-1"],
    report_inconsistencies: true
  }
}
```

## Documentation and Migration

### Theme Documentation Generator
```elixir
# Auto-generate theme documentation
defmodule SelectoComponents.ThemeDocumentation do
  @moduledoc """
  Generate comprehensive documentation for themes.
  """
  
  def generate_theme_docs(theme_config) do
    %{
      overview: generate_overview(theme_config),
      design_tokens: document_design_tokens(theme_config),
      component_examples: generate_component_examples(theme_config),
      usage_guide: generate_usage_guide(theme_config),
      migration_guide: generate_migration_guide(theme_config)
    }
  end
  
  def generate_component_examples(theme_config) do
    theme_config.components
    |> Enum.map(fn {component_name, _styles} ->
      %{
        component: component_name,
        preview_html: render_component_preview(component_name, theme_config),
        usage_code: generate_usage_code(component_name, theme_config),
        customization_options: list_customization_options(component_name, theme_config)
      }
    end)
  end
end
```

### Migration Tools
```elixir
# Tools to migrate existing implementations to new theming system
migration_tools = %{
  # Analyze existing CSS for migration opportunities
  css_analyzer: %{
    scan_existing_styles: true,
    suggest_token_mappings: true,
    identify_inconsistencies: true,
    generate_migration_plan: true
  },
  
  # Automated migration assistant
  migration_assistant: %{
    backup_existing_styles: true,
    apply_theme_gradually: true,    # Incremental migration
    rollback_capability: true,
    validation_at_each_step: true
  },
  
  # Legacy compatibility layer
  legacy_support: %{
    css_bridge: true,              # Bridge old CSS with new theme system
    gradual_adoption: true,        # Allow mixed old/new styling
    deprecation_warnings: true     # Warn about deprecated patterns
  }
}
```

## Success Metrics

- [ ] Complete theming system with design tokens and CSS generation
- [ ] All SelectoComponents support full theme customization
- [ ] Interactive theme builder with real-time preview
- [ ] Built-in themes (default, dark, accessible, enterprise)
- [ ] Theme inheritance and variant system working correctly
- [ ] Performance impact <10% compared to hard-coded styles
- [ ] Full accessibility compliance (WCAG 2.1 AA) for all built-in themes
- [ ] Comprehensive documentation with examples and migration guides
- [ ] Zero breaking changes for existing implementations
- [ ] Visual regression testing pipeline for theme changes
- [ ] Cross-browser compatibility across all modern browsers