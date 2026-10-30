# Badge

Small status indicator for labels and counts.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `badge` | Component | Container element |
| `badge-outline` | Style | Outline style |
| `badge-dash` | Style | Dashed outline style |
| `badge-soft` | Style | Soft background style |
| `badge-ghost` | Style | Ghost style |
| `badge-{color}` | Color | primary, secondary, accent, neutral, info, success, warning, error |
| `badge-{size}` | Size | xs, sm, md (default), lg, xl |

## Essential Examples

### Basic usage

```html
<div class="badge">Default</div>
<div class="badge badge-primary">Primary</div>
```

### Empty badge (dot indicator)

```html
<div class="badge badge-primary badge-xs"></div>
<div class="badge badge-success badge-sm"></div>
```

### Badge in button

```html
<button class="btn">
  Inbox
  <div class="badge badge-secondary">+99</div>
</button>
```
