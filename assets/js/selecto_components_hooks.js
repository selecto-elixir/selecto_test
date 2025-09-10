// Import colocated hooks from SelectoComponents
import TreeBuilderHook from "selecto_components/SelectoComponents.Components.TreeBuilder/11_ehpljylwqw72vuompp2v7ecrdq.js"

// Note: GraphComponent hook will be dynamically loaded when the component is compiled
// For now, we'll provide an empty placeholder to avoid build errors
const GraphComponentHook = {
  mounted() {
    console.warn("GraphComponent hook not yet compiled. Run 'mix compile --force' in vendor/selecto_components to generate it.");
  }
};

// Export hooks with their full names
export const selectoComponentsHooks = {
  "SelectoComponents.Components.TreeBuilder.TreeBuilder": TreeBuilderHook,
  "SelectoComponents.Views.Graph.Component.GraphComponent": GraphComponentHook
}