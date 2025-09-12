// Non-colocated hooks for SelectoComponents
// These hooks provide interactivity for components that don't have colocated JS

// SlotManager - Manages custom component slots
const SlotManager = {
  mounted() {
    this.handleSlotUpdate = () => {
      this.pushEvent("slot_updated", {id: this.el.id})
    }
    this.el.addEventListener("slot-change", this.handleSlotUpdate)
  },
  destroyed() {
    this.el.removeEventListener("slot-change", this.handleSlotUpdate)
  }
}

// VirtualScroll - Implements virtual scrolling for large datasets
const VirtualScroll = {
  mounted() {
    this.handleScroll = () => {
      const scrollTop = this.el.scrollTop
      const scrollHeight = this.el.scrollHeight
      const clientHeight = this.el.clientHeight
      this.pushEvent("scroll_update", {
        scrollTop,
        scrollHeight,
        clientHeight,
        scrollPercentage: (scrollTop / (scrollHeight - clientHeight)) * 100
      })
    }
    this.el.addEventListener("scroll", this.handleScroll)
  },
  destroyed() {
    this.el.removeEventListener("scroll", this.handleScroll)
  }
}

// VirtualRow - Individual row in virtual scroll
const VirtualRow = {
  mounted() {
    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          this.pushEvent("row_visible", {index: this.el.dataset.index})
        }
      })
    })
    observer.observe(this.el)
    this.observer = observer
  },
  destroyed() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }
}

// TimelineChart - Renders timeline visualizations
const TimelineChart = {
  mounted() {
    this.renderChart()
  },
  updated() {
    this.renderChart()
  },
  renderChart() {
    const data = JSON.parse(this.el.dataset.chartData || '[]')
    // Chart rendering logic would go here
    // This is a placeholder - actual implementation would use Chart.js or similar
  }
}

// TrendChart - Renders trend visualizations
const TrendChart = {
  mounted() {
    this.renderChart()
  },
  updated() {
    this.renderChart()
  },
  renderChart() {
    const data = JSON.parse(this.el.dataset.trendData || '[]')
    // Trend chart rendering logic
  }
}

// CopyToClipboard - Copies content to clipboard
const CopyToClipboard = {
  mounted() {
    this.el.addEventListener("click", e => {
      e.preventDefault()
      const text = this.el.dataset.clipboardText || this.el.innerText
      navigator.clipboard.writeText(text).then(() => {
        this.pushEvent("copied", {text})
        // Visual feedback
        const originalText = this.el.innerText
        this.el.innerText = "Copied!"
        setTimeout(() => {
          this.el.innerText = originalText
        }, 2000)
      })
    })
  }
}

// QRCodeDisplay - Displays QR codes
const QRCodeDisplay = {
  mounted() {
    this.generateQR()
  },
  updated() {
    this.generateQR()
  },
  generateQR() {
    const link = this.el.dataset.link
    if (link && window.QRCode) {
      new window.QRCode(this.el, {
        text: link,
        width: 256,
        height: 256
      })
    }
  }
}

// QueryCanvas - Visual query builder canvas
const QueryCanvas = {
  mounted() {
    this.setupCanvas()
  },
  setupCanvas() {
    // Canvas setup for visual query building
    this.el.addEventListener("click", e => {
      const rect = this.el.getBoundingClientRect()
      const x = e.clientX - rect.left
      const y = e.clientY - rect.top
      this.pushEvent("canvas_click", {x, y})
    })
  }
}

// DraggableComponent - Makes components draggable
const DraggableComponent = {
  mounted() {
    this.el.draggable = true
    this.el.addEventListener("dragstart", e => {
      e.dataTransfer.effectAllowed = "move"
      e.dataTransfer.setData("component_id", this.el.id)
      this.pushEvent("drag_start", {id: this.el.id})
    })
    this.el.addEventListener("dragend", e => {
      this.pushEvent("drag_end", {id: this.el.id})
    })
  }
}

// DraggableQuery - Draggable query components
const DraggableQuery = {
  mounted() {
    this.el.draggable = true
    this.el.addEventListener("dragstart", e => {
      e.dataTransfer.setData("query_id", this.el.dataset.queryId)
    })
  }
}

// QueryComposition - Manages query composition
const QueryComposition = {
  mounted() {
    this.el.addEventListener("drop", e => {
      e.preventDefault()
      const queryId = e.dataTransfer.getData("query_id")
      if (queryId) {
        this.pushEvent("compose_query", {queryId})
      }
    })
    this.el.addEventListener("dragover", e => {
      e.preventDefault()
    })
  }
}

// DraggableCTE - Draggable CTE components
const DraggableCTE = {
  mounted() {
    this.el.draggable = true
    this.el.addEventListener("dragstart", e => {
      e.dataTransfer.setData("cte_name", this.el.dataset.cteName)
    })
  }
}

// CTEGraphRenderer - Renders CTE dependency graphs
const CTEGraphRenderer = {
  mounted() {
    this.renderGraph()
  },
  updated() {
    this.renderGraph()
  },
  renderGraph() {
    const nodes = JSON.parse(this.el.dataset.nodes || '[]')
    const edges = JSON.parse(this.el.dataset.edges || '[]')
    // Graph rendering logic would go here
  }
}

// ModalControl - Controls modal behavior
const ModalControl = {
  mounted() {
    // Handle escape key
    this.handleEscape = (e) => {
      if (e.key === "Escape") {
        this.pushEvent("close_modal", {})
      }
    }
    document.addEventListener("keydown", this.handleEscape)
    
    // Handle backdrop click
    this.el.addEventListener("click", e => {
      if (e.target === this.el) {
        this.pushEvent("close_modal", {})
      }
    })
  },
  destroyed() {
    document.removeEventListener("keydown", this.handleEscape)
  }
}

// ThemeProvider - Provides theme context
const ThemeProvider = {
  mounted() {
    const theme = this.el.dataset.theme || 'light'
    document.documentElement.setAttribute('data-theme', theme)
  },
  updated() {
    const theme = this.el.dataset.theme || 'light'
    document.documentElement.setAttribute('data-theme', theme)
  }
}

// ThemeSwitcher - Theme switching UI
const ThemeSwitcher = {
  mounted() {
    this.el.addEventListener("click", e => {
      const button = e.target.closest("[data-theme-value]")
      if (button) {
        const theme = button.dataset.themeValue
        this.pushEvent("switch_theme", {theme})
      }
    })
  }
}

// ThemeBuilder - Custom theme builder
const ThemeBuilder = {
  mounted() {
    this.setupColorPickers()
  },
  setupColorPickers() {
    this.el.querySelectorAll('input[type="color"]').forEach(input => {
      input.addEventListener("change", e => {
        const variable = e.target.dataset.cssVariable
        const value = e.target.value
        if (variable) {
          document.documentElement.style.setProperty(variable, value)
          this.pushEvent("theme_color_changed", {variable, value})
        }
      })
    })
  }
}

// RowClickable - Makes table rows clickable
const RowClickable = {
  mounted() {
    this.el.addEventListener("click", e => {
      const row = e.target.closest("tr[phx-click]")
      if (row && !e.target.closest("a, button, input, select, textarea")) {
        // Row click is handled by phx-click, but we can add visual feedback
        row.style.opacity = "0.7"
        setTimeout(() => {
          row.style.opacity = "1"
        }, 200)
      }
    })
  }
}

// Additional non-colocated hooks

// ExpressionBuilder - Expression filter builder
const ExpressionBuilder = {
  mounted() {
    this.setupExpressionBuilder()
  },
  setupExpressionBuilder() {
    // Expression builder logic
    this.el.addEventListener("change", e => {
      if (e.target.matches("select, input")) {
        const expression = this.buildExpression()
        this.pushEvent("expression_changed", {expression})
      }
    })
  },
  buildExpression() {
    // Build expression from form inputs
    return this.el.querySelector("[name=expression]")?.value || ""
  }
}

// MultiSelectFilter - Multi-select filter component
const MultiSelectFilter = {
  mounted() {
    this.selected = new Set()
    this.setupMultiSelect()
  },
  setupMultiSelect() {
    this.el.addEventListener("click", e => {
      const option = e.target.closest("[data-option]")
      if (option) {
        const value = option.dataset.option
        if (this.selected.has(value)) {
          this.selected.delete(value)
        } else {
          this.selected.add(value)
        }
        this.pushEvent("selection_changed", {selected: Array.from(this.selected)})
      }
    })
  }
}

// NumericRangeFilter - Numeric range filter
const NumericRangeFilter = {
  mounted() {
    this.setupRangeInputs()
  },
  setupRangeInputs() {
    const minInput = this.el.querySelector("[name=min]")
    const maxInput = this.el.querySelector("[name=max]")
    
    const handleChange = () => {
      this.pushEvent("range_changed", {
        min: minInput?.value,
        max: maxInput?.value
      })
    }
    
    minInput?.addEventListener("change", handleChange)
    maxInput?.addEventListener("change", handleChange)
  }
}

// DateRangeFilter - Date range filter
const DateRangeFilter = {
  mounted() {
    this.setupDateInputs()
  },
  setupDateInputs() {
    const startInput = this.el.querySelector("[name=start_date]")
    const endInput = this.el.querySelector("[name=end_date]")
    
    const handleChange = () => {
      this.pushEvent("date_range_changed", {
        start_date: startInput?.value,
        end_date: endInput?.value
      })
    }
    
    startInput?.addEventListener("change", handleChange)
    endInput?.addEventListener("change", handleChange)
  }
}

// Additional dashboard hooks
const Sparkline = {
  mounted() {
    this.renderSparkline()
  },
  updated() {
    this.renderSparkline()
  },
  renderSparkline() {
    const data = JSON.parse(this.el.dataset.data || '[]')
    // Sparkline rendering logic
  }
}

const PieSparkline = {
  mounted() {
    this.renderPie()
  },
  updated() {
    this.renderPie()
  },
  renderPie() {
    const data = JSON.parse(this.el.dataset.data || '[]')
    // Pie chart rendering logic
  }
}

const TrendSparkline = {
  mounted() {
    this.renderTrend()
  },
  updated() {
    this.renderTrend()
  },
  renderTrend() {
    const data = JSON.parse(this.el.dataset.data || '[]')
    // Trend sparkline rendering logic
  }
}

const MetricDisplay = {
  mounted() {
    this.updateMetric()
  },
  updated() {
    this.updateMetric()
  },
  updateMetric() {
    const value = this.el.dataset.value
    const trend = this.el.dataset.trend
    // Update metric display
  }
}

const DashboardWidget = {
  mounted() {
    this.initWidget()
  },
  initWidget() {
    // Widget initialization
    this.el.addEventListener("click", e => {
      if (e.target.matches("[data-action]")) {
        const action = e.target.dataset.action
        this.pushEvent("widget_action", {action})
      }
    })
  }
}

const DashboardLayout = {
  mounted() {
    this.setupGridLayout()
  },
  setupGridLayout() {
    // Grid layout management
  }
}

// Form-related hooks
const InlineForm = {
  mounted() {
    this.setupInlineEditing()
  },
  setupInlineEditing() {
    this.el.addEventListener("click", e => {
      if (e.target.matches("[data-editable]")) {
        const field = e.target.dataset.editable
        this.pushEvent("start_edit", {field})
      }
    })
  }
}

const BulkAddForm = {
  mounted() {
    this.setupBulkAdd()
  },
  setupBulkAdd() {
    // Bulk add form logic
  }
}

const QuickAddModal = {
  mounted() {
    this.setupQuickAdd()
  },
  setupQuickAdd() {
    // Quick add modal logic
  }
}

// Enhanced table hooks
const DraggableColumn = {
  mounted() {
    this.el.draggable = true
    this.el.addEventListener("dragstart", e => {
      e.dataTransfer.setData("column_id", this.el.dataset.columnId)
    })
  }
}

const ColumnReorder = {
  mounted() {
    this.setupColumnReordering()
  },
  setupColumnReordering() {
    // Column reordering logic
  }
}

const ColumnHeader = {
  mounted() {
    this.el.addEventListener("click", e => {
      const sortable = e.target.closest("[data-sortable]")
      if (sortable) {
        this.pushEvent("sort", {column: sortable.dataset.column})
      }
    })
  }
}

const ResizeHandle = {
  mounted() {
    this.setupResize()
  },
  setupResize() {
    let startX, startWidth
    
    this.el.addEventListener("mousedown", e => {
      startX = e.clientX
      startWidth = this.el.parentElement.offsetWidth
      
      const handleMouseMove = (e) => {
        const width = startWidth + e.clientX - startX
        this.el.parentElement.style.width = width + "px"
      }
      
      const handleMouseUp = () => {
        document.removeEventListener("mousemove", handleMouseMove)
        document.removeEventListener("mouseup", handleMouseUp)
        this.pushEvent("column_resized", {
          column: this.el.dataset.column,
          width: this.el.parentElement.offsetWidth
        })
      }
      
      document.addEventListener("mousemove", handleMouseMove)
      document.addEventListener("mouseup", handleMouseUp)
    })
  }
}

const ColumnResize = {
  mounted() {
    // Column resize observer
  }
}

// Subselect/Query builder hooks
const SubselectBuilder = {
  mounted() {
    this.setupBuilder()
  },
  setupBuilder() {
    // Subselect builder logic
  }
}

const DraggableQueryComponent = {
  mounted() {
    this.el.draggable = true
    this.el.addEventListener("dragstart", e => {
      e.dataTransfer.setData("component_type", this.el.dataset.componentType)
    })
  }
}

// Responsive hooks
const ResponsiveTable = {
  mounted() {
    this.observeResize()
  },
  observeResize() {
    const resizeObserver = new ResizeObserver(entries => {
      for (let entry of entries) {
        const width = entry.contentRect.width
        this.pushEvent("table_resized", {width})
      }
    })
    resizeObserver.observe(this.el)
    this.resizeObserver = resizeObserver
  },
  destroyed() {
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
    }
  }
}

const MobileAccordion = {
  mounted() {
    this.setupAccordion()
  },
  setupAccordion() {
    this.el.addEventListener("click", e => {
      const header = e.target.closest("[data-accordion-header]")
      if (header) {
        const content = header.nextElementSibling
        if (content) {
          content.classList.toggle("hidden")
        }
      }
    })
  }
}

const SwipeableCards = {
  mounted() {
    this.setupSwipe()
  },
  setupSwipe() {
    let startX = 0
    let currentX = 0
    
    this.el.addEventListener("touchstart", e => {
      startX = e.touches[0].clientX
    })
    
    this.el.addEventListener("touchmove", e => {
      currentX = e.touches[0].clientX
    })
    
    this.el.addEventListener("touchend", () => {
      const diff = currentX - startX
      if (Math.abs(diff) > 50) {
        this.pushEvent("swipe", {direction: diff > 0 ? "right" : "left"})
      }
    })
  }
}

// Performance monitoring hooks
const QueryTimeline = {
  mounted() {
    this.renderTimeline()
  },
  updated() {
    this.renderTimeline()
  },
  renderTimeline() {
    const data = JSON.parse(this.el.dataset.queries || '[]')
    // Timeline rendering logic
  }
}

const CacheHitRateChart = {
  mounted() {
    this.renderChart()
  },
  updated() {
    this.renderChart()
  },
  renderChart() {
    const data = JSON.parse(this.el.dataset.cacheData || '[]')
    // Cache hit rate chart rendering
  }
}

// Export all hooks
export default {
  SlotManager,
  VirtualScroll,
  VirtualRow,
  TimelineChart,
  TrendChart,
  CopyToClipboard,
  QRCodeDisplay,
  QueryCanvas,
  DraggableComponent,
  DraggableQuery,
  QueryComposition,
  DraggableCTE,
  CTEGraphRenderer,
  ModalControl,
  ThemeProvider,
  ThemeSwitcher,
  ThemeBuilder,
  RowClickable,
  // Additional hooks
  ExpressionBuilder,
  MultiSelectFilter,
  NumericRangeFilter,
  DateRangeFilter,
  Sparkline,
  PieSparkline,
  TrendSparkline,
  MetricDisplay,
  DashboardWidget,
  DashboardLayout,
  InlineForm,
  BulkAddForm,
  QuickAddModal,
  DraggableColumn,
  ColumnReorder,
  ColumnHeader,
  ResizeHandle,
  ColumnResize,
  SubselectBuilder,
  DraggableQueryComponent,
  ResponsiveTable,
  MobileAccordion,
  SwipeableCards,
  QueryTimeline,
  CacheHitRateChart
}