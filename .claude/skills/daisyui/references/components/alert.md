# Alert

Component for displaying important messages and notifications.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `alert` | Component | Container element for alert |
| `alert-outline` | Style | Outline style |
| `alert-dash` | Style | Dash outline style |
| `alert-soft` | Style | Soft style |
| `alert-info` | Color | Info color style |
| `alert-success` | Color | Success color style |
| `alert-warning` | Color | Warning color style |
| `alert-error` | Color | Error color style |
| `alert-vertical` | direction | Vertical layout (mobile-friendly) |
| `alert-horizontal` | direction | Horizontal layout (desktop-friendly) |

## Essential Examples

### Basic usage

```html
<div role="alert" class="alert">
  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class="stroke-info h-6 w-6 shrink-0">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
  </svg>
  <span>12 unread messages. Tap to see.</span>
</div>
```

### Colors and styles

```html
<div role="alert" class="alert alert-success">
  <span>Your purchase has been confirmed!</span>
</div>

<div role="alert" class="alert alert-error alert-outline">
  <span>Error! Task failed successfully.</span>
</div>
```

### With actions

```html
<div role="alert" class="alert alert-vertical sm:alert-horizontal">
  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class="stroke-info h-6 w-6 shrink-0">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
  </svg>
  <span>We use cookies for no reason.</span>
  <div>
    <button class="btn btn-sm">Deny</button>
    <button class="btn btn-sm btn-primary">Accept</button>
  </div>
</div>
```

### With title

```html
<div role="alert" class="alert alert-info">
  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class="h-6 w-6 shrink-0 stroke-current">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
  </svg>
  <div>
    <h3 class="font-bold">New message!</h3>
    <div class="text-xs">You have 1 unread message</div>
  </div>
  <button class="btn btn-sm">See</button>
</div>
```

## Notes

- Layout: Use `alert-vertical sm:alert-horizontal` for responsive behavior
