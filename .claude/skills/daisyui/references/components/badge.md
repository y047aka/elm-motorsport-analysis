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
| `badge-neutral` | Color | Neutral color |
| `badge-primary` | Color | Primary color |
| `badge-secondary` | Color | Secondary color |
| `badge-accent` | Color | Accent color |
| `badge-info` | Color | Info color |
| `badge-success` | Color | Success color |
| `badge-warning` | Color | Warning color |
| `badge-error` | Color | Error color |
| `badge-xs` | Size | Extra small |
| `badge-sm` | Size | Small |
| `badge-md` | Size | Medium (default) |
| `badge-lg` | Size | Large |
| `badge-xl` | Size | Extra large |

## Essential Examples

### Basic usage

```html
<div class="badge">Default</div>
<div class="badge badge-primary">Primary</div>
<div class="badge badge-outline badge-primary">Outline</div>
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
