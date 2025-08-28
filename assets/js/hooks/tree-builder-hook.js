// TreeBuilder hook for drag-and-drop filter building
export default {
  mounted() {
    console.log('TreeBuilderHook mounted');
    window.PushEventHook = this;
  },

  destroyed() {
    console.log('TreeBuilderHook destroyed');
    window.PushEventHook = null;
  }
};