// Graph hook for Chart.js integration
export default {
  mounted() {
    console.log('GraphHook mounted');
    this.initializeChart();
  },

  updated() {
    console.log('GraphHook updated');
    this.updateChart();
  },

  destroyed() {
    console.log('GraphHook destroyed');
    if (this.chart) {
      this.chart.destroy();
    }
  },

  initializeChart() {
    const canvas = this.el.querySelector('canvas');
    if (!canvas) return;

    const chartData = JSON.parse(this.el.dataset.chartData || '{}');
    const chartOptions = JSON.parse(this.el.dataset.chartOptions || '{}');
    const chartType = this.el.dataset.chartType || 'bar';

    if (window.Chart) {
      this.chart = new Chart(canvas, {
        type: chartType,
        data: chartData,
        options: chartOptions
      });
    }
  },

  updateChart() {
    if (this.chart) {
      const chartData = JSON.parse(this.el.dataset.chartData || '{}');
      const chartOptions = JSON.parse(this.el.dataset.chartOptions || '{}');

      this.chart.data = chartData;
      this.chart.options = chartOptions;
      this.chart.update();
    } else {
      this.initializeChart();
    }
  }
};