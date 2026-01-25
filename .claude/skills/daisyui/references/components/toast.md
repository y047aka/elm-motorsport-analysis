# Toast

Container element that sticks to the corner of page for notification messages.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `toast` | Component | Container element that sticks to the corner of page |
| `toast-start` | Placement | Align horizontally to the left |
| `toast-center` | Placement | Align horizontally to the center |
| `toast-end` | Placement | Align horizontally to the right (Default) |
| `toast-top` | Placement | Align vertically to top |
| `toast-middle` | Placement | Align vertically to middle |
| `toast-bottom` | Placement | Align vertically to bottom (Default) |

## Key Examples

### Basic toast

```html
<div class="toast">
  <div class="alert alert-info">
    <span>New message arrived.</span>
  </div>
</div>
```

### Toast positions

```html
<!-- Top end -->
<div class="toast toast-top toast-end">
  <div class="alert alert-info">
    <span>Top end</span>
  </div>
</div>

<!-- Bottom start -->
<div class="toast toast-bottom toast-start">
  <div class="alert alert-info">
    <span>Bottom start</span>
  </div>
</div>

<!-- Middle center -->
<div class="toast toast-middle toast-center">
  <div class="alert alert-info">
    <span>Middle center</span>
  </div>
</div>
```

### Multiple toasts

```html
<div class="toast toast-end">
  <div class="alert alert-info">
    <span>New mail arrived.</span>
  </div>
  <div class="alert alert-success">
    <span>Message sent successfully.</span>
  </div>
  <div class="alert alert-warning">
    <span>Warning: Low storage.</span>
  </div>
</div>
```

### Toast with different alert types

```html
<div class="toast">
  <div class="alert alert-success">
    <span>Success message</span>
  </div>
</div>

<div class="toast">
  <div class="alert alert-error">
    <span>Error message</span>
  </div>
</div>
```

### Toast with close button

```html
<div class="toast">
  <div class="alert alert-info">
    <span>New notification</span>
    <button class="btn btn-sm btn-circle btn-ghost">✕</button>
  </div>
</div>
```

### Toast with action button

```html
<div class="toast">
  <div class="alert alert-info">
    <span>New friend request</span>
    <button class="btn btn-sm btn-primary">Accept</button>
  </div>
</div>
```

### Dynamic toast with JavaScript

```html
<button class="btn" onclick="showToast()">Show Toast</button>

<div id="toast-container" class="toast toast-end">
  <!-- Toasts will be added here -->
</div>

<script>
function showToast() {
  const container = document.getElementById('toast-container');
  const toast = document.createElement('div');
  toast.className = 'alert alert-success';
  toast.innerHTML = '<span>Action completed!</span>';
  container.appendChild(toast);
  
  // Auto remove after 3 seconds
  setTimeout(() => {
    toast.remove();
  }, 3000);
}
</script>
```
