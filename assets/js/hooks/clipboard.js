// Clipboard Hook for copying text to clipboard
const ClipboardHook = {
  mounted() {
    // Listen for clipboard copy events from the server
    this.handleEvent("copy-to-clipboard", ({ text }) => {
      this.copyToClipboard(text);
    });
  },

  copyToClipboard(text) {
    // Modern clipboard API with fallback
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text)
        .then(() => {
          this.showCopyFeedback(true);
        })
        .catch((err) => {
          console.error('Failed to copy text: ', err);
          this.fallbackCopy(text);
        });
    } else {
      this.fallbackCopy(text);
    }
  },

  fallbackCopy(text) {
    // Fallback for older browsers
    const textArea = document.createElement("textarea");
    textArea.value = text;
    textArea.style.position = "fixed";
    textArea.style.top = "-9999px";
    textArea.style.left = "-9999px";
    document.body.appendChild(textArea);
    textArea.focus();
    textArea.select();

    try {
      const successful = document.execCommand('copy');
      this.showCopyFeedback(successful);
    } catch (err) {
      console.error('Fallback copy failed: ', err);
      this.showCopyFeedback(false);
    }

    document.body.removeChild(textArea);
  },

  showCopyFeedback(success) {
    // Find the copy button and show feedback
    const button = this.el.querySelector('[phx-click="copy_sql"]');
    if (button) {
      const originalText = button.innerHTML;
      
      if (success) {
        button.innerHTML = `
          <svg class="h-3 w-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
          </svg>
          Copied!
        `;
        button.classList.remove('bg-blue-500', 'hover:bg-blue-600');
        button.classList.add('bg-green-500', 'hover:bg-green-600');
      } else {
        button.innerHTML = `
          <svg class="h-3 w-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
          Failed
        `;
        button.classList.remove('bg-blue-500', 'hover:bg-blue-600');
        button.classList.add('bg-red-500', 'hover:bg-red-600');
      }

      // Reset after 2 seconds
      setTimeout(() => {
        button.innerHTML = originalText;
        button.classList.remove('bg-green-500', 'hover:bg-green-600', 'bg-red-500', 'hover:bg-red-600');
        button.classList.add('bg-blue-500', 'hover:bg-blue-600');
      }, 2000);
    }
  }
};

export default ClipboardHook;