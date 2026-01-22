# Badge

Small status indicator component for labels and counts.

## Basic Usage

```html
<div class="badge">Badge</div>
```

## Color Variants

```html
<div class="badge badge-neutral">neutral</div>
<div class="badge badge-primary">primary</div>
<div class="badge badge-secondary">secondary</div>
<div class="badge badge-accent">accent</div>
<div class="badge badge-ghost">ghost</div>
```

## State Colors

```html
<div class="badge badge-info">info</div>
<div class="badge badge-success">success</div>
<div class="badge badge-warning">warning</div>
<div class="badge badge-error">error</div>
```

## Outlined Badges

```html
<div class="badge badge-outline">outline</div>
<div class="badge badge-outline badge-primary">primary</div>
<div class="badge badge-outline badge-secondary">secondary</div>
<div class="badge badge-outline badge-accent">accent</div>
```

## Sizes

```html
<div class="badge badge-lg">Large</div>
<div class="badge badge-md">Medium</div>
<div class="badge badge-sm">Small</div>
<div class="badge badge-xs">Tiny</div>
```

## Empty Badge (Dot)

```html
<div class="badge badge-primary badge-xs"></div>
<div class="badge badge-primary badge-sm"></div>
<div class="badge badge-primary badge-md"></div>
<div class="badge badge-primary badge-lg"></div>
```

## Badge in Button

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

## Badge in Text

```html
<h2 class="text-2xl">
  Heading
  <span class="badge badge-lg">NEW</span>
</h2>
```

## Badge in Card Title

```html
<div class="card-title">
  Card Title
  <div class="badge badge-secondary">NEW</div>
</div>
```

## Badge with Icon

```html
<div class="badge gap-2">
  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class="inline-block h-4 w-4 stroke-current">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
  </svg>
  Badge
</div>
```

## Removable Badge

```html
<div class="badge gap-2 badge-primary">
  primary
  <button>
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class="inline-block h-4 w-4 stroke-current">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
    </svg>
  </button>
</div>
```

## Multiple Badges

```html
<div class="flex gap-2">
  <div class="badge badge-outline">Fashion</div>
  <div class="badge badge-outline">Products</div>
  <div class="badge badge-outline">Technology</div>
</div>
```

## Classes Reference

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
