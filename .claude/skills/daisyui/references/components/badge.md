# Badge

Small status indicator component for labels and counts.

## Class Reference

| Class | Description |
|-------|-------------|
| `badge` | Base badge class |
| `badge-neutral` | Neutral color |
| `badge-primary` | Primary color |
| `badge-secondary` | Secondary color |
| `badge-accent` | Accent color |
| `badge-ghost` | Ghost style |
| `badge-info` | Info state color |
| `badge-success` | Success state color |
| `badge-warning` | Warning state color |
| `badge-error` | Error state color |
| `badge-outline` | Outlined style |
| `badge-lg` | Large size |
| `badge-md` | Medium size (default) |
| `badge-sm` | Small size |
| `badge-xs` | Extra small size |

## Key Examples

### Basic badges with colors

```html
<div class="badge">Badge</div>
<div class="badge badge-primary">primary</div>
<div class="badge badge-secondary">secondary</div>
<div class="badge badge-accent">accent</div>
<div class="badge badge-info">info</div>
<div class="badge badge-success">success</div>
<div class="badge badge-warning">warning</div>
<div class="badge badge-error">error</div>
```

### Outlined badges

```html
<div class="badge badge-outline">outline</div>
<div class="badge badge-outline badge-primary">primary</div>
<div class="badge badge-outline badge-secondary">secondary</div>
```

### Badge sizes

```html
<div class="badge badge-lg">Large</div>
<div class="badge badge-md">Medium</div>
<div class="badge badge-sm">Small</div>
<div class="badge badge-xs">Tiny</div>
```

### Empty badge (dot indicator)

```html
<div class="badge badge-primary badge-xs"></div>
<div class="badge badge-primary badge-sm"></div>
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

### Badge in card title

```html
<div class="card-title">
  Card Title
  <div class="badge badge-secondary">NEW</div>
</div>
```
