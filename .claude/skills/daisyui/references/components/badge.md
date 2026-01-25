# Badge

Small status indicator component for labels and counts. Badges are used to inform the user of the status of specific data.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `badge` | Component | Container element for badges |
| `badge-outline` | Style | Outline style |
| `badge-dash` | Style | Dash outline style |
| `badge-soft` | Style | Soft style |
| `badge-ghost` | Style | Ghost style |
| `badge-neutral` | Color | Neutral color |
| `badge-primary` | Color | Primary color |
| `badge-secondary` | Color | Secondary color |
| `badge-accent` | Color | Accent color |
| `badge-info` | Color | Info state color |
| `badge-success` | Color | Success state color |
| `badge-warning` | Color | Warning state color |
| `badge-error` | Color | Error state color |
| `badge-xs` | Size | Extra small size |
| `badge-sm` | Size | Small size |
| `badge-md` | Size | Medium size (default) |
| `badge-lg` | Size | Large size |
| `badge-xl` | Size | Extra large size |

## Key Examples

### Basic badges with colors

```html
<div class="badge">Badge</div>
<div class="badge badge-neutral">neutral</div>
<div class="badge badge-primary">primary</div>
<div class="badge badge-secondary">secondary</div>
<div class="badge badge-accent">accent</div>
<div class="badge badge-info">info</div>
<div class="badge badge-success">success</div>
<div class="badge badge-warning">warning</div>
<div class="badge badge-error">error</div>
```

### Style variants

```html
<div class="badge badge-outline">outline</div>
<div class="badge badge-outline badge-primary">primary outline</div>
<div class="badge badge-dash">dash</div>
<div class="badge badge-dash badge-primary">primary dash</div>
<div class="badge badge-soft">soft</div>
<div class="badge badge-soft badge-primary">primary soft</div>
<div class="badge badge-ghost">ghost</div>
```

### Badge sizes

```html
<div class="badge badge-xs">Extra small</div>
<div class="badge badge-sm">Small</div>
<div class="badge badge-md">Medium</div>
<div class="badge badge-lg">Large</div>
<div class="badge badge-xl">Extra large</div>
```

### Empty badge (dot indicator)

```html
<div class="badge badge-primary badge-xs"></div>
<div class="badge badge-primary badge-sm"></div>
<div class="badge badge-primary badge-md"></div>
```

### Badge in button

```html
<button class="btn">
  Inbox
  <div class="badge">+99</div>
</button>

<button class="btn">
  Inbox
  <div class="badge badge-secondary">+99</div>
</button>
```
