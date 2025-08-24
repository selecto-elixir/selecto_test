// TreeBuilder Hook for Selecto Components
// This replaces the colocated hook to avoid build issues in production

export default {
  mounted() {
    window.PushEventHook = this
  },
  destroyed() {
    window.PushEventHook = null
  }
}