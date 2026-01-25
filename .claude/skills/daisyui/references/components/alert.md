# Alert

Component for displaying important messages and notifications.

## Class Reference

| Class | Description |
|-------|-------------|
| `alert` | Base alert class |
| `alert-info` | Info style (blue) |
| `alert-success` | Success style (green) |
| `alert-warning` | Warning style (yellow/orange) |
| `alert-error` | Error style (red) |

## Key Examples

### Basic alert

```html
<div role="alert" class="alert">
  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class="stroke-info h-6 w-6 shrink-0">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
  </svg>
  <span>12 unread messages. Tap to see.</span>
</div>
```

### Alert types

```html
<div role="alert" class="alert alert-info">
  <span>New software update available.</span>
</div>

<div role="alert" class="alert alert-success">
  <span>Your purchase has been confirmed!</span>
</div>

<div role="alert" class="alert alert-warning">
  <span>Warning: Invalid email address!</span>
</div>

<div role="alert" class="alert alert-error">
  <span>Error! Task failed successfully.</span>
</div>
```

### Alert with actions

```html
<div role="alert" class="alert">
  <span>We use cookies for no reason.</span>
  <div>
    <button class="btn btn-sm">Deny</button>
    <button class="btn btn-sm btn-primary">Accept</button>
  </div>
</div>
```

### Alert with title and description

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

### Dismissible alert

```html
<div role="alert" class="alert">
  <span>Click the X to dismiss</span>
  <button class="btn btn-sm btn-circle btn-ghost">✕</button>
</div>
```

### Soft style (custom)

```html
<div role="alert" class="alert bg-info/10 text-info">
  <span>Soft info alert</span>
</div>

<div role="alert" class="alert bg-success/10 text-success">
  <span>Soft success alert</span>
</div>
```
