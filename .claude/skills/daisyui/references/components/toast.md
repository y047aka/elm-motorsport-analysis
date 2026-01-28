# Toast

Notification container that sticks to page corners.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `toast` | Component | Container element that sticks to the corner of page |
| `toast-start` | Placement | Align horizontally to left |
| `toast-center` | Placement | Align horizontally to center |
| `toast-end` | Placement | Align horizontally to right (default) |
| `toast-top` | Placement | Align vertically to top |
| `toast-middle` | Placement | Align vertically to middle |
| `toast-bottom` | Placement | Align vertically to bottom (default) |

## Essential Examples

### Basic usage

```html
<div class="toast">
  <div class="alert alert-info">
    <span>New message arrived.</span>
  </div>
</div>
```

### Positions

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
</div>
```

### With action

```html
<div class="toast">
  <div class="alert alert-info">
    <span>New notification</span>
    <button class="btn btn-sm btn-primary">View</button>
  </div>
</div>
```

## Notes

- **Required**: Combine vertical and horizontal placement classes (e.g., `toast-top toast-end`)
- **Recommended**: Typically contains `alert` components
- **Recommended**: Add/remove dynamically with JavaScript for notifications
