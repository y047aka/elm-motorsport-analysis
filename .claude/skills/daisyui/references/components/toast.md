# Toast

Toast notification component for temporary messages.

## Basic Usage

```html
<div class="toast">
  <div class="alert alert-info">
    <span>New message arrived.</span>
  </div>
</div>
```

## Positions

```html
<!-- Top start -->
<div class="toast toast-top toast-start">
  <div class="alert alert-info">
    <span>Top start</span>
  </div>
</div>

<!-- Top center -->
<div class="toast toast-top toast-center">
  <div class="alert alert-info">
    <span>Top center</span>
  </div>
</div>

<!-- Top end -->
<div class="toast toast-top toast-end">
  <div class="alert alert-info">
    <span>Top end</span>
  </div>
</div>

<!-- Middle start -->
<div class="toast toast-middle toast-start">
  <div class="alert alert-info">
    <span>Middle start</span>
  </div>
</div>

<!-- Middle center -->
<div class="toast toast-middle toast-center">
  <div class="alert alert-info">
    <span>Middle center</span>
  </div>
</div>

<!-- Middle end -->
<div class="toast toast-middle toast-end">
  <div class="alert alert-info">
    <span>Middle end</span>
  </div>
</div>

<!-- Bottom start -->
<div class="toast toast-bottom toast-start">
  <div class="alert alert-info">
    <span>Bottom start</span>
  </div>
</div>

<!-- Bottom center -->
<div class="toast toast-bottom toast-center">
  <div class="alert alert-info">
    <span>Bottom center</span>
  </div>
</div>

<!-- Bottom end (default) -->
<div class="toast toast-bottom toast-end">
  <div class="alert alert-info">
    <span>Bottom end</span>
  </div>
</div>
```

## Multiple Toasts

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

## With Different Alert Types

```html
<div class="toast">
  <div class="alert alert-info">
    <span>Info message</span>
  </div>
</div>

<div class="toast">
  <div class="alert alert-success">
    <span>Success message</span>
  </div>
</div>

<div class="toast">
  <div class="alert alert-warning">
    <span>Warning message</span>
  </div>
</div>

<div class="toast">
  <div class="alert alert-error">
    <span>Error message</span>
  </div>
</div>
```

## With Close Button

```html
<div class="toast">
  <div class="alert alert-info">
    <span>New notification</span>
    <button class="btn btn-sm btn-circle btn-ghost">✕</button>
  </div>
</div>
```

## With Action Button

```html
<div class="toast">
  <div class="alert alert-info">
    <span>New friend request</span>
    <button class="btn btn-sm btn-primary">Accept</button>
  </div>
</div>
```

## Compact Toast

```html
<div class="toast">
  <div class="alert py-2">
    <span class="text-sm">Compact notification</span>
  </div>
</div>
```

## Dynamic Toast (JavaScript)

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

## Stacked Toasts

```html
<div class="toast toast-end">
  <div class="alert alert-info shadow-lg">
    <span>1st notification</span>
  </div>
  <div class="alert alert-success shadow-lg">
    <span>2nd notification</span>
  </div>
  <div class="alert alert-warning shadow-lg">
    <span>3rd notification</span>
  </div>
</div>
```

## Classes Reference

| Class | Description |
|-------|-------------|
| `toast` | Container element |
| `toast-start` | Align to start (left) |
| `toast-center` | Align to center |
| `toast-end` | Align to end (right) |
| `toast-top` | Position at top |
| `toast-middle` | Position at middle |
| `toast-bottom` | Position at bottom |

Note: Toast uses alert components for the actual notification content.
