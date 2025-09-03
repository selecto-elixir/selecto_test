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

    const pushEvent = (event, payload) => {\n      this.pushEvent(event, payload);\n    };

    if (window.Chart) {
      this.chart = new Chart(canvas, {
        type: chartType,
        data: chartData,
        options: {
          ...chartOptions,
          onClick: (event, elements) => {
            if (elements.length > 0) {
              const element = elements[0];
              const datasetIndex = element.datasetIndex;
              const index = element.index;
              const dataset = chartData.datasets[datasetIndex];
              const value = dataset.data[index];
              const label = chartData.labels[index];

              const xFieldName = this.el.dataset.xAxis; 
              const yFieldName = dataset.label; 
              
              pushEvent('chart_click', {
                label: label,
                value: value,
                dataset_label: dataset.label,
                x_field: xFieldName,
                y_field: yFieldName
              });
            }
          }
        }
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