// Chart.js Graph Hook for Selecto Components
// This replaces the colocated hook to avoid build issues in production

export default {
  mounted() {
    this.chart = null
    this.initializeChart()
    this.bindEvents()
  },

  updated() {
    this.updateChart()
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }
  },

  initializeChart() {
    const canvas = this.el.querySelector('canvas')
    if (!canvas) return
    
    const ctx = canvas.getContext('2d')
    
    // Get configuration from data attributes
    const chartType = this.el.dataset.chartType || 'bar'
    const chartData = this.getChartData()
    const chartOptions = this.getChartOptions()

    // Create the chart using global Chart.js
    if (typeof Chart === 'undefined') {
      console.error('Chart.js is not loaded')
      return
    }

    this.chart = new Chart(ctx, {
      type: chartType,
      data: chartData,
      options: {
        ...chartOptions,
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          intersect: false,
          mode: 'index'
        },
        onClick: (event, activeElements) => {
          this.handleChartClick(event, activeElements)
        },
        onHover: (event, activeElements) => {
          this.handleChartHover(event, activeElements)
        }
      }
    })
  },

  updateChart() {
    if (!this.chart) {
      this.initializeChart()
      return
    }

    const newData = this.getChartData()
    const newOptions = this.getChartOptions()
    
    // Update chart data
    this.chart.data = newData
    this.chart.options = {
      ...this.chart.options,
      ...newOptions
    }
    
    this.chart.update('none') // No animation for updates
  },

  getChartData() {
    try {
      const dataJson = this.el.dataset.chartData
      if (!dataJson) return this.getDefaultData()
      
      const data = JSON.parse(dataJson)
      return this.formatDataForChart(data)
    } catch (error) {
      console.error('Error parsing chart data:', error)
      return this.getDefaultData()
    }
  },

  getChartOptions() {
    try {
      const optionsJson = this.el.dataset.chartOptions
      if (!optionsJson) return this.getDefaultOptions()
      
      const options = JSON.parse(optionsJson)
      return this.formatOptionsForChart(options)
    } catch (error) {
      console.error('Error parsing chart options:', error)
      return this.getDefaultOptions()
    }
  },

  formatDataForChart(rawData) {
    const chartType = this.el.dataset.chartType || 'bar'
    
    switch (chartType) {
      case 'pie':
      case 'doughnut':
        return this.formatPieData(rawData)
      case 'line':
      case 'area':
        return this.formatLineData(rawData)
      case 'scatter':
        return this.formatScatterData(rawData)
      default:
        return this.formatBarData(rawData)
    }
  },

  formatBarData(rawData) {
    const labels = rawData.labels || []
    const datasets = rawData.datasets || []
    
    return {
      labels: labels,
      datasets: datasets.map((dataset, index) => ({
        label: dataset.label || `Series ${index + 1}`,
        data: dataset.data || [],
        backgroundColor: dataset.backgroundColor || this.generateColors(dataset.data?.length || 0, 0.7),
        borderColor: dataset.borderColor || this.generateColors(dataset.data?.length || 0, 1.0),
        borderWidth: dataset.borderWidth || 1
      }))
    }
  },

  formatLineData(rawData) {
    const labels = rawData.labels || []
    const datasets = rawData.datasets || []
    
    return {
      labels: labels,
      datasets: datasets.map((dataset, index) => ({
        label: dataset.label || `Series ${index + 1}`,
        data: dataset.data || [],
        borderColor: dataset.borderColor || this.generateColors(1, 1.0)[0],
        backgroundColor: dataset.backgroundColor || this.generateColors(1, 0.1)[0],
        borderWidth: dataset.borderWidth || 2,
        fill: this.el.dataset.chartType === 'area',
        tension: 0.4
      }))
    }
  },

  formatPieData(rawData) {
    const labels = rawData.labels || []
    const data = rawData.data || []
    
    return {
      labels: labels,
      datasets: [{
        data: data,
        backgroundColor: this.generateColors(labels.length, 0.8),
        borderColor: this.generateColors(labels.length, 1.0),
        borderWidth: 2
      }]
    }
  },

  formatScatterData(rawData) {
    const datasets = rawData.datasets || []
    
    return {
      datasets: datasets.map((dataset, index) => ({
        label: dataset.label || `Series ${index + 1}`,
        data: dataset.data || [], // Should be array of {x, y} objects
        backgroundColor: dataset.backgroundColor || this.generateColors(1, 0.7)[0],
        borderColor: dataset.borderColor || this.generateColors(1, 1.0)[0],
        pointRadius: dataset.pointRadius || 5
      }))
    }
  },

  formatOptionsForChart(rawOptions) {
    const chartType = this.el.dataset.chartType || 'bar'
    const baseOptions = this.getDefaultOptions()
    
    // Merge with base options
    const options = { ...baseOptions, ...rawOptions }
    
    // Chart type specific options
    if (chartType === 'pie' || chartType === 'doughnut') {
      options.scales = undefined // Remove scales for pie charts
    }
    
    return options
  },

  getDefaultData() {
    return {
      labels: ['No Data'],
      datasets: [{
        label: 'No Data',
        data: [0],
        backgroundColor: ['#e5e7eb'],
        borderColor: ['#9ca3af'],
        borderWidth: 1
      }]
    }
  },

  getDefaultOptions() {
    return {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          position: 'bottom'
        },
        tooltip: {
          mode: 'index',
          intersect: false
        }
      },
      scales: {
        x: {
          beginAtZero: true,
          grid: {
            display: true
          }
        },
        y: {
          beginAtZero: true,
          grid: {
            display: true
          }
        }
      }
    }
  },

  generateColors(count, alpha = 1.0) {
    const colors = [
      `rgba(59, 130, 246, ${alpha})`,   // blue
      `rgba(16, 185, 129, ${alpha})`,   // green
      `rgba(245, 101, 101, ${alpha})`,  // red
      `rgba(251, 191, 36, ${alpha})`,   // yellow
      `rgba(139, 92, 246, ${alpha})`,   // purple
      `rgba(236, 72, 153, ${alpha})`,   // pink
      `rgba(6, 182, 212, ${alpha})`,    // cyan
      `rgba(251, 146, 60, ${alpha})`,   // orange
      `rgba(34, 197, 94, ${alpha})`,    // lime
      `rgba(168, 85, 247, ${alpha})`    // violet
    ]
    
    const result = []
    for (let i = 0; i < count; i++) {
      result.push(colors[i % colors.length])
    }
    return result
  },

  handleChartClick(event, activeElements) {
    if (activeElements.length === 0) return
    
    const element = activeElements[0]
    const dataIndex = element.index
    const datasetIndex = element.datasetIndex
    
    // Get the clicked data point information
    const clickedData = {
      dataIndex,
      datasetIndex,
      label: this.chart.data.labels[dataIndex],
      value: this.chart.data.datasets[datasetIndex].data[dataIndex]
    }
    
    // Send drill-down event to LiveView
    this.pushEvent('graph_drill_down', clickedData)
  },

  handleChartHover(event, activeElements) {
    // Change cursor to pointer when hovering over data points
    event.native.target.style.cursor = activeElements.length > 0 ? 'pointer' : 'default'
  },

  bindEvents() {
    // Export functionality
    const exportBtn = this.el.querySelector('[data-export]')
    if (exportBtn) {
      exportBtn.addEventListener('click', () => this.exportChart())
    }
  },

  exportChart() {
    if (!this.chart) return
    
    const canvas = this.chart.canvas
    const url = canvas.toDataURL('image/png')
    const link = document.createElement('a')
    link.download = 'chart.png'
    link.href = url
    link.click()
  }
}