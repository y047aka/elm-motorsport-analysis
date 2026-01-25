# Button

Buttons allow the user to take actions or make choices.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `btn` | Component | Button base class |
| `btn-neutral` | Color | Neutral color |
| `btn-primary` | Color | Primary color |
| `btn-secondary` | Color | Secondary color |
| `btn-accent` | Color | Accent color |
| `btn-info` | Color | Info color |
| `btn-success` | Color | Success color |
| `btn-warning` | Color | Warning color |
| `btn-error` | Color | Error color |
| `btn-outline` | Style | Outline style |
| `btn-dash` | Style | Dashed outline style |
| `btn-soft` | Style | Soft background style |
| `btn-ghost` | Style | Ghost style (transparent bg) |
| `btn-link` | Style | Link style (underlined) |
| `btn-active` | Behavior | Active state appearance |
| `btn-disabled` | Behavior | Disabled appearance |
| `btn-xs` | Size | Extra small |
| `btn-sm` | Size | Small |
| `btn-md` | Size | Medium (default) |
| `btn-lg` | Size | Large |
| `btn-xl` | Size | Extra large |
| `btn-wide` | Modifier | Extra horizontal padding |
| `btn-block` | Modifier | Full width |
| `btn-square` | Modifier | Square shape (1:1 ratio) |
| `btn-circle` | Modifier | Circle shape (1:1 ratio with rounded corners) |

## Key Examples

### Basic buttons with colors

```html
<button class="btn">Default</button>
<button class="btn btn-primary">Primary</button>
<button class="btn btn-secondary">Secondary</button>
<button class="btn btn-accent">Accent</button>
```

### Button sizes

```html
<button class="btn btn-xs">Extra Small</button>
<button class="btn btn-sm">Small</button>
<button class="btn">Default</button>
<button class="btn btn-lg">Large</button>
<button class="btn btn-xl">Extra Large</button>
```

### Responsive sizes

```html
<button class="btn sm:btn-sm md:btn-md lg:btn-lg">Responsive</button>

### Button styles

```html
<!-- Outline buttons -->
<button class="btn btn-outline">Default</button>
<button class="btn btn-outline btn-primary">Primary</button>

<!-- Soft style -->
<button class="btn btn-soft btn-primary">Soft Primary</button>

<!-- Ghost buttons -->
<button class="btn btn-ghost">Ghost</button>
<button class="btn btn-ghost btn-primary">Ghost Primary</button>

```

### Button states

```html
<!-- Disabled (prefer this) -->
<button class="btn" disabled>Disabled</button>
<!-- Disabled with class -->
<button class="btn btn-disabled" tabindex="-1" role="button" aria-disabled="true">Disabled</button>

<!-- Active -->
<button class="btn btn-active btn-primary">Active</button>

<!-- Loading -->
<button class="btn">
  <span class="loading loading-spinner"></span>
  Loading
</button>
```

### Icon buttons

```html
<!-- Button with icon and text -->
<button class="btn">
  <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12Z" />
  </svg>
  Like
</button>

<!-- Square icon button -->
<button class="btn btn-square">
  <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
  </svg>
</button>

<!-- Circle icon button -->
<button class="btn btn-circle btn-primary">
  <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
  </svg>
</button>
```

### Block and wide buttons

```html
<button class="btn btn-block">Full Width Button</button>
<button class="btn btn-wide">Wide Button</button>
```

## Usage as Other Elements

Buttons can be applied to various HTML elements:

```html
<a role="button" class="btn">Link Button</a>
<input type="button" value="Input Button" class="btn" />
<input type="submit" value="Submit" class="btn btn-primary" />
```
