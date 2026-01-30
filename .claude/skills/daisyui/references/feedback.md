# Feedback Components

Guide for displaying feedback and status to users. For specific component details, see individual files in `components/`.

## Quick Reference

| Component | Use Case | Base Class |
|-----------|----------|------------|
| [alert](components/alert.md) | Inline messages, banners | `alert` |
| [toast](components/toast.md) | Corner notifications | `toast` |
| [tooltip](components/tooltip.md) | Hover hints | `tooltip` |
| [loading](components/loading.md) | Spinners, loading indicators | `loading` |
| [skeleton](components/skeleton.md) | Content placeholders | `skeleton` |
| [progress](components/progress.md) | Linear progress bar | `progress` |
| [radial-progress](components/radial-progress.md) | Circular progress | `radial-progress` |

## Alert vs Toast

| Alert | Toast |
|-------|-------|
| Inline in content flow | Fixed to screen corner |
| Static position | Stacked notifications |
| Part of page layout | Overlays content |
| Persistent | Often temporary |

## Alert

### Basic Alert

```html
<div role="alert" class="alert alert-info">
  <svg class="h-6 w-6 shrink-0 stroke-current"><!-- icon --></svg>
  <span>Message text</span>
</div>
```

### Alert Colors

```
alert-info       Blue, informational
alert-success    Green, success
alert-warning    Yellow, caution
alert-error      Red, error/danger
```

### Alert Styles

```
alert-outline    Outline style
alert-dash       Dashed outline
alert-soft       Soft background
```

### Alert with Actions

```html
<div role="alert" class="alert alert-vertical sm:alert-horizontal">
  <svg><!-- icon --></svg>
  <span>Message</span>
  <div>
    <button class="btn btn-sm">Deny</button>
    <button class="btn btn-sm btn-primary">Accept</button>
  </div>
</div>
```

Use `alert-vertical sm:alert-horizontal` for responsive layout.

## Toast

### Position Classes

Combine vertical + horizontal placement:

```
Vertical:    toast-top, toast-middle, toast-bottom (default)
Horizontal:  toast-start, toast-center, toast-end (default)
```

### Basic Toast

```html
<div class="toast toast-top toast-end">
  <div class="alert alert-success">
    <span>Saved successfully</span>
  </div>
</div>
```

### Multiple Toasts

Toasts stack automatically:

```html
<div class="toast toast-end">
  <div class="alert alert-info"><span>Message 1</span></div>
  <div class="alert alert-success"><span>Message 2</span></div>
</div>
```

## Tooltip

### Basic Tooltip

```html
<div class="tooltip" data-tip="Tooltip text">
  <button class="btn">Hover me</button>
</div>
```

### Positions

```
tooltip-top       Above (default)
tooltip-bottom    Below
tooltip-left      Left side
tooltip-right     Right side
```

### Tooltip Colors

```
tooltip-neutral, tooltip-primary, tooltip-secondary, tooltip-accent
tooltip-info, tooltip-success, tooltip-warning, tooltip-error
```

## Loading Indicators

### Animation Styles

```html
<span class="loading loading-spinner"></span>
<span class="loading loading-dots"></span>
<span class="loading loading-ring"></span>
<span class="loading loading-ball"></span>
<span class="loading loading-bars"></span>
<span class="loading loading-infinity"></span>
```

### Sizes

```
loading-xs, loading-sm, loading-md (default), loading-lg, loading-xl
```

### In Button

```html
<button class="btn">
  <span class="loading loading-spinner"></span>
  Loading
</button>
```

## Skeleton Placeholders

### Basic Skeleton

```html
<div class="skeleton h-32 w-32"></div>
```

### Card Skeleton

```html
<div class="flex flex-col gap-4">
  <div class="skeleton h-48 w-full"></div>
  <div class="skeleton h-4 w-3/4"></div>
  <div class="skeleton h-4 w-1/2"></div>
</div>
```

### Avatar + Text Skeleton

```html
<div class="flex items-center gap-4">
  <div class="skeleton h-12 w-12 shrink-0 rounded-full"></div>
  <div class="flex flex-col gap-2">
    <div class="skeleton h-4 w-20"></div>
    <div class="skeleton h-3 w-28"></div>
  </div>
</div>
```

### Text Placeholder

```html
<span class="skeleton skeleton-text">Loading text...</span>
```

## Progress Indicators

### Linear Progress

```html
<progress class="progress progress-primary w-56" value="70" max="100"></progress>
```

Omit `value` for indeterminate animation:

```html
<progress class="progress w-56"></progress>
```

### Progress Colors

```
progress-neutral, progress-primary, progress-secondary, progress-accent
progress-info, progress-success, progress-warning, progress-error
```

### Radial Progress

Uses CSS custom properties:

```html
<div class="radial-progress" style="--value:70;" role="progressbar" aria-valuenow="70">
  70%
</div>
```

Custom size and thickness:

```html
<div class="radial-progress" style="--value:50; --size:8rem; --thickness:1rem;" role="progressbar">
  50%
</div>
```

## Component Selection Guide

| Need | Use |
|------|-----|
| Inline message | `alert` |
| Temporary notification | `toast` with `alert` inside |
| Hover information | `tooltip` |
| Action in progress | `loading` |
| Content loading | `skeleton` |
| Task progress (linear) | `progress` |
| Task progress (circular) | `radial-progress` |

## Related Patterns

- [Toast Notifications](patterns.md#toast-notifications) - Dynamic toast management
- [Loading States](patterns.md#loading-states) - Skeleton patterns
