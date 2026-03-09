import "../vendor/js/phoenix_html.js"

import { Socket } from "../vendor/js/phoenix.js"
import { LiveSocket } from "../vendor/js/phoenix_live_view.js"

// Import and register duskmoon custom elements
import "@duskmoon-dev/elements/register"
import "@duskmoon-dev/el-markdown/register"

// Import duskmoon LiveView hooks
import * as DuskmoonHooks from "phoenix_duskmoon/hooks"

// Custom web component for collapsible thinking box
// Maintains collapse state across LiveView updates
class ThinkingBox extends HTMLElement {
  constructor() {
    super()
    this.attachShadow({ mode: 'open' })
    this._collapsed = true
    this._streaming = false
  }

  static get observedAttributes() {
    return ['streaming']
  }

  connectedCallback() {
    this.render()
  }

  attributeChangedCallback(name, oldValue, newValue) {
    if (name === 'streaming') {
      this._streaming = newValue !== null
      this.updateStreamingIndicator()
    }
  }

  get collapsed() {
    return this._collapsed
  }

  set collapsed(value) {
    this._collapsed = value
    this.updateCollapseState()
  }

  toggle() {
    this.collapsed = !this.collapsed
  }

  updateCollapseState() {
    const content = this.shadowRoot.querySelector('.content')
    const arrow = this.shadowRoot.querySelector('.arrow')
    if (content) {
      content.style.display = this._collapsed ? 'none' : 'block'
    }
    if (arrow) {
      arrow.style.transform = this._collapsed ? 'rotate(0deg)' : 'rotate(90deg)'
    }
  }

  updateStreamingIndicator() {
    const indicator = this.shadowRoot.querySelector('.streaming-indicator')
    if (indicator) {
      indicator.style.display = this._streaming ? 'inline-flex' : 'none'
    }
  }

  render() {
    this.shadowRoot.innerHTML = `
      <style>
        :host {
          display: block;
          background: rgba(0,0,0,0.05);
          border-radius: 0.5rem;
          margin-bottom: 0.75rem;
          overflow: hidden;
        }
        .header {
          display: flex;
          align-items: center;
          gap: 0.5rem;
          padding: 0.5rem 0.75rem;
          cursor: pointer;
          font-size: 0.875rem;
          font-weight: 500;
          user-select: none;
        }
        .header:hover {
          background: rgba(0,0,0,0.05);
        }
        .arrow {
          transition: transform 0.2s;
          width: 1rem;
          height: 1rem;
        }
        .icon {
          width: 1rem;
          height: 1rem;
        }
        .streaming-indicator {
          display: none;
          gap: 2px;
          margin-left: 0.25rem;
        }
        .streaming-indicator span {
          width: 4px;
          height: 4px;
          background: currentColor;
          border-radius: 50%;
          animation: dot-pulse 1.4s infinite ease-in-out both;
        }
        .streaming-indicator span:nth-child(1) { animation-delay: -0.32s; }
        .streaming-indicator span:nth-child(2) { animation-delay: -0.16s; }
        @keyframes dot-pulse {
          0%, 80%, 100% { transform: scale(0); }
          40% { transform: scale(1); }
        }
        .content {
          display: none;
          padding: 0 0.75rem 0.75rem;
          font-size: 0.875rem;
          opacity: 0.8;
          max-height: 300px;
          overflow-y: auto;
        }
      </style>
      <div class="header" part="header">
        <svg class="arrow" viewBox="0 0 24 24" fill="currentColor">
          <path d="M8.59 16.59L13.17 12 8.59 7.41 10 6l6 6-6 6-1.41-1.41z"/>
        </svg>
        <svg class="icon" viewBox="0 0 24 24" fill="currentColor">
          <path d="M12,3C16.97,3 21,7.03 21,12C21,16.97 16.97,21 12,21C7.03,21 3,16.97 3,12C3,7.03 7.03,3 12,3M12,5C8.14,5 5,8.14 5,12C5,15.86 8.14,19 12,19C15.86,19 19,15.86 19,12C19,8.14 15.86,5 12,5M10.5,7.5A2,2 0 0,1 12.5,9.5A2,2 0 0,1 10.5,11.5A2,2 0 0,1 8.5,9.5A2,2 0 0,1 10.5,7.5M13.5,12.5A2,2 0 0,1 15.5,14.5A2,2 0 0,1 13.5,16.5A2,2 0 0,1 11.5,14.5A2,2 0 0,1 13.5,12.5Z"/>
        </svg>
        <span>Thinking Process</span>
        <div class="streaming-indicator">
          <span></span><span></span><span></span>
        </div>
      </div>
      <div class="content" part="content">
        <slot></slot>
      </div>
    `

    this.shadowRoot.querySelector('.header').addEventListener('click', () => this.toggle())
    this.updateCollapseState()
    this.updateStreamingIndicator()
  }
}

customElements.define('thinking-box', ThinkingBox)

// Hooks for LiveView interactions
let Hooks = {}

// Streaming Markdown hook for AI chat responses
Hooks.StreamingMarkdown = {
  mounted() {
    // Get the el-dm-markdown element
    this.mdElement = this.el.querySelector("el-dm-markdown")

    // Handle streaming start
    this.handleEvent("stream_start", () => {
      if (this.mdElement) {
        this.mdElement.startStreaming()
      }
    })

    // Handle streaming content chunks
    this.handleEvent("stream_chunk", ({ content }) => {
      if (this.mdElement) {
        this.mdElement.setContent(content)
      }
    })

    // Handle streaming end
    this.handleEvent("stream_end", ({ content }) => {
      if (this.mdElement) {
        this.mdElement.setContent(content)
        this.mdElement.endStreaming()
      }
    })
  },

  updated() {
    // Re-acquire element reference after DOM updates
    this.mdElement = this.el.querySelector("el-dm-markdown")
  }
}

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
    // Cmd+Enter (Mac) or Ctrl+Enter (Windows/Linux) submits the form
    if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) {
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

// Copy content hook - copies content to clipboard
Hooks.CopyContent = {
  mounted() {
    this.el.addEventListener("click", () => {
      const content = this.el.dataset.content || ""
      navigator.clipboard.writeText(content).then(() => {
        // Show feedback
        const originalText = this.el.innerHTML
        const originalTitle = this.el.title
        this.el.innerHTML = '<svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/></svg>'
        this.el.title = "Copied!"
        setTimeout(() => {
          this.el.innerHTML = originalText
          this.el.title = originalTitle
        }, 1500)
      }).catch(err => {
        console.error("Failed to copy:", err)
      })
    })
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
  hooks: { ...DuskmoonHooks, ...Hooks }
})

liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

