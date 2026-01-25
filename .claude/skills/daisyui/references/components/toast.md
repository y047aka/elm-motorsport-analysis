# Toast

Notification container that sticks to page corners.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `toast` | Component | Fixed position container |
| `toast-start` | Placement | Align to left |
| `toast-center` | Placement | Align to center |
| `toast-end` | Placement | Align to right (default) |
| `toast-top` | Placement | Align to top |
| `toast-middle` | Placement | Align to middle |
| `toast-bottom` | Placement | Align to bottom (default) |

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

- Position: Combine vertical (`toast-{top|middle|bottom}`) and horizontal (`toast-{start|center|end}`)
- Content: Typically contains `alert` components
- Dynamic: Add/remove with JavaScript for notifications
- Z-index: Positioned above other content by default
