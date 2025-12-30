import "../vendor/js/phoenix_html.js"

import { Socket } from "../vendor/js/phoenix.js"
import { LiveSocket } from "../vendor/js/phoenix_live_view.js"

// Hooks for LiveView interactions
let Hooks = {}

// T011-T012: Provider selection persistence hooks
Hooks.ProviderSelection = {
  mounted() {
    // T012: Restore saved provider selection on mount
    // Try new format first, then fallback to legacy
    const savedProviderModel = localStorage.getItem("selected_provider_model")
    const savedProviderId = localStorage.getItem("selected_provider_id")

    if (savedProviderModel) {
      this.pushEvent("restore_provider_selection", { provider_model: savedProviderModel })
    } else if (savedProviderId) {
      this.pushEvent("restore_provider_selection", { provider_id: savedProviderId })
    }

    // T011: Save provider selection to localStorage (new format)
    this.handleEvent("save_provider_selection", ({ provider_model }) => {
      localStorage.setItem("selected_provider_model", provider_model)
      // Clear legacy key
      localStorage.removeItem("selected_provider_id")
    })
  }
}

// Auto-resize textarea hook
Hooks.AutoResizeTextarea = {
  mounted() {
    this.resize()
    this.el.addEventListener("input", () => this.resize())
    this.el.addEventListener("keydown", (e) => this.handleKeydown(e))
  },
  updated() {
    this.resize()
  },
  resize() {
    // Reset height to auto to get the correct scrollHeight
    this.el.style.height = "auto"
    // Set height to scrollHeight, but respect max-height from CSS
    this.el.style.height = this.el.scrollHeight + "px"
  },
  handleKeydown(e) {
    // Enter without Shift submits the form
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault()
      const form = this.el.closest("form")
      if (form) {
        // Check if message is not empty
        const message = this.el.value.trim()
        if (message) {
          form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }))
        }
      }
    }
  }
}

// Modal auto-open hook - opens dialog when mounted
Hooks.ModalAutoOpen = {
  mounted() {
    // Find the dialog element inside the wrapper or use el directly
    const dialog = this.el.tagName === 'DIALOG' ? this.el : this.el.querySelector('dialog')
    if (dialog && typeof dialog.showModal === 'function') {
      dialog.showModal()
    }
  },
  updated() {
    // Also handle updates (e.g., when navigating between :new and :edit)
    const dialog = this.el.tagName === 'DIALOG' ? this.el : this.el.querySelector('dialog')
    if (dialog && typeof dialog.showModal === 'function' && !dialog.open) {
      dialog.showModal()
    }
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: Hooks
})

liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

