# Button

Interactive button component with multiple variants, sizes, and states.

## Basic Usage

```html
<button class="btn">Button</button>
```

## Color Variants

```html
<button class="btn btn-primary">Primary</button>
<button class="btn btn-secondary">Secondary</button>
<button class="btn btn-accent">Accent</button>
<button class="btn btn-neutral">Neutral</button>
<button class="btn btn-ghost">Ghost</button>
<button class="btn btn-link">Link</button>
```

## State Colors

```html
<button class="btn btn-info">Info</button>
<button class="btn btn-success">Success</button>
<button class="btn btn-warning">Warning</button>
<button class="btn btn-error">Error</button>
```

## Sizes

```html
<button class="btn btn-xs">Tiny</button>
<button class="btn btn-sm">Small</button>
<button class="btn btn-md">Normal</button>
<button class="btn btn-lg">Large</button>
```

## Outlined Buttons

```html
<button class="btn btn-outline">Outline</button>
<button class="btn btn-outline btn-primary">Primary Outline</button>
<button class="btn btn-outline btn-secondary">Secondary Outline</button>
<button class="btn btn-outline btn-accent">Accent Outline</button>
```

## Button States

```html
<button class="btn btn-active">Active</button>
<button class="btn" disabled>Disabled</button>
<button class="btn btn-disabled">Disabled (class)</button>
```

## Loading State

```html
<button class="btn">
  <span class="loading loading-spinner"></span>
  Loading
</button>

<!-- Loading without text -->
<button class="btn btn-square">
  <span class="loading loading-spinner"></span>
</button>
```

## Icon Buttons

```html
<!-- Square button -->
<button class="btn btn-square">
  <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
  </svg>
</button>

<!-- Circle button -->
<button class="btn btn-circle">
  <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
  </svg>
</button>
```

## Button with Icon

```html
<button class="btn">
  <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
  </svg>
  Button
</button>
```

## Block Button (Full Width)

```html
<button class="btn btn-block">Block Button</button>
```

## Wide Button

```html
<button class="btn btn-wide">Wide Button</button>
```

## Responsive Button

```html
<button class="btn btn-xs sm:btn-sm md:btn-md lg:btn-lg">Responsive</button>
```

## Button Group

```html
<div class="join">
  <button class="btn join-item">Button</button>
  <button class="btn join-item">Button</button>
  <button class="btn join-item">Button</button>
</div>
```

## Classes Reference

| Class | Description |
|-------|-------------|
| `btn` | Base button class |
| `btn-primary` | Primary color |
| `btn-secondary` | Secondary color |
| `btn-accent` | Accent color |
| `btn-neutral` | Neutral color |
| `btn-ghost` | Transparent background |
| `btn-link` | Link style |
| `btn-info` | Info state color |
| `btn-success` | Success state color |
| `btn-warning` | Warning state color |
| `btn-error` | Error state color |
| `btn-outline` | Outlined style |
| `btn-active` | Active state |
| `btn-disabled` | Disabled style |
| `btn-xs` | Extra small size |
| `btn-sm` | Small size |
| `btn-md` | Medium size (default) |
| `btn-lg` | Large size |
| `btn-wide` | Wide button |
| `btn-block` | Full width |
| `btn-circle` | Circle shape |
| `btn-square` | Square shape |
