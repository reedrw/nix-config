import type { TuiPlugin, TuiPluginModule } from "@opencode-ai/plugin/tui"

const tui: TuiPlugin = async (api) => {
  let state = 0

  const dispatch = (name: string) => api.keymap.dispatchCommand(name)

  const set = (s: number) => {
    state = s
  }

  const forward = async () => {
    switch (state) {
      case 0:
        dispatch("permission.mode")
        set(1)
        break
      case 1:
        dispatch("permission.mode")
        dispatch("agent.cycle")
        set(2)
        break
      case 2:
        dispatch("agent.cycle")
        set(0)
        break
    }
  }

  const reverse = async () => {
    switch (state) {
      case 0:
        dispatch("agent.cycle")
        set(2)
        break
      case 2:
        dispatch("agent.cycle")
        dispatch("permission.mode")
        set(1)
        break
      case 1:
        dispatch("permission.mode")
        set(0)
        break
    }
  }

  api.keymap.registerLayer({
    commands: [
      {
        name: "mode.cycle",
        title: "Cycle build / build+auto / plan",
        category: "Prompt",
        hidden: true,
        run: forward,
      },
      {
        name: "mode.cycle.reverse",
        title: "Reverse cycle plan / build+auto / build",
        category: "Prompt",
        hidden: true,
        run: reverse,
      },
    ],
    bindings: [
      {
        key: "shift+tab",
        cmd: "mode.cycle",
        desc: "Cycle build → build+auto → plan",
      },
      {
        key: "tab",
        cmd: "mode.cycle.reverse",
        desc: "Cycle build → plan → build+auto",
      },
    ],
  })
}

const plugin: TuiPluginModule & { id: string } = {
  id: "mode-cycle",
  tui,
}

export default plugin
