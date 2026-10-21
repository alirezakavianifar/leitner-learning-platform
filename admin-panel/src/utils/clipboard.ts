/**
 * Universal clipboard utility that works across secure (HTTPS/localhost)
 * and insecure contexts (plain HTTP, remote IP addresses, or legacy browsers).
 */
export async function copyTextToClipboard(text: string): Promise<boolean> {
  // 1. Modern Asynchronous Clipboard API (Secure Contexts: HTTPS or localhost)
  if (typeof window !== 'undefined' && navigator?.clipboard?.writeText) {
    try {
      await navigator.clipboard.writeText(text);
      return true;
    } catch (err) {
      console.warn('navigator.clipboard.writeText failed, attempting document.execCommand fallback:', err);
    }
  }

  // 2. Legacy / Insecure Context Fallback (document.execCommand)
  if (typeof document !== 'undefined') {
    try {
      const textArea = document.createElement('textarea');
      textArea.value = text;

      // Position off-screen and invisible without triggering scroll jumps
      textArea.style.position = 'fixed';
      textArea.style.top = '0';
      textArea.style.left = '0';
      textArea.style.width = '2em';
      textArea.style.height = '2em';
      textArea.style.padding = '0';
      textArea.style.border = 'none';
      textArea.style.outline = 'none';
      textArea.style.boxShadow = 'none';
      textArea.style.background = 'transparent';
      textArea.setAttribute('readonly', '');

      document.body.appendChild(textArea);
      textArea.focus();
      textArea.select();
      textArea.setSelectionRange(0, text.length);

      const successful = document.execCommand('copy');
      document.body.removeChild(textArea);
      return successful;
    } catch (err) {
      console.error('execCommand copy fallback failed:', err);
      return false;
    }
  }

  return false;
}
