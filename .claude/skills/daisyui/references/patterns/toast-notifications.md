# Toast Notifications

**Components**: toast, alert

JavaScript toast manager for dynamic notifications.

```javascript
function showToast(message, type = 'info', duration = 3000) {
  const container = document.getElementById('toast-container') 
    || createToastContainer();
  
  const toast = document.createElement('div');
  toast.className = `alert alert-${type}`;
  toast.innerHTML = `<span>${message}</span>`;
  
  container.appendChild(toast);
  
  setTimeout(() => {
    toast.remove();
  }, duration);
}

function createToastContainer() {
  const container = document.createElement('div');
  container.id = 'toast-container';
  container.className = 'toast toast-end';
  document.body.appendChild(container);
  return container;
}

// Usage
showToast('File uploaded!', 'success');
showToast('Something went wrong', 'error');
```

## Toast Positions

```html
<!-- Position variants -->
<div class="toast toast-start">...</div>
<div class="toast toast-center">...</div>
<div class="toast toast-end">...</div>
<div class="toast toast-top">...</div>
<div class="toast toast-middle">...</div>
<div class="toast toast-bottom">...</div>
```

## Usage Notes

- Toast container should be positioned fixed on the page
- Use `toast-end` for right-aligned notifications (common pattern)
- Combine vertical and horizontal positions (e.g., `toast toast-top toast-end`)
- Set appropriate duration based on message length
- Use alert types: `info`, `success`, `warning`, `error`

## Related Components

- [Toast](../components/toast.md)
- [Alert](../components/alert.md)
