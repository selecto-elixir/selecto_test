// Import colocated hooks from SelectoComponents
import TreeBuilderHook from "selecto_components/SelectoComponents.Components.TreeBuilder/11_ehpljylwqw72vuompp2v7ecrdq.js"
import GraphComponentHook from "selecto_components/SelectoComponents.Views.Graph.Component/152_wfdwh3vvrupqz4vkyw4xdcwzai.js"
import DebugClipboardHook from "selecto_components/SelectoComponents.Debug.DebugDisplay/123_tojpd332cosf6hjdib742dc2lq.js"

// Export hooks with their full names
export const selectoComponentsHooks = {
  "SelectoComponents.Components.TreeBuilder.TreeBuilder": TreeBuilderHook,
  "SelectoComponents.Views.Graph.Component.GraphComponent": GraphComponentHook,
  "SelectoComponents.Debug.DebugDisplay.DebugClipboard": DebugClipboardHook,
  // Also register without the full path for simpler references
  "TreeBuilder": TreeBuilderHook,
  "GraphComponent": GraphComponentHook,
  "DebugClipboard": DebugClipboardHook
}