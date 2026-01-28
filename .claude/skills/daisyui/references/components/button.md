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
| `btn-wide` | Modifier | Extra horizontal padding for wider button |
| `btn-block` | Modifier | Full width button |
| `btn-square` | Modifier | Square shape with 1:1 aspect ratio |
| `btn-circle` | Modifier | Circle shape with 1:1 aspect ratio and rounded corners |

## Essential Examples

### Basic usage

```html
<button class="btn">Default</button>
<button class="btn btn-primary">Primary</button>
<button class="btn btn-outline btn-primary">Outline</button>
```

### With loading state

```html
<button class="btn">
  <span class="loading loading-spinner"></span>
  Loading
</button>
```

### With icon

```html
<!-- With text and icon -->
<button class="btn">
  <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12Z" />
  </svg>
  Like
</button>

<!-- Icon only: use btn-square or btn-circle -->
<button class="btn btn-square">
  <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
  </svg>
</button>
```

## Notes

- **Recommended**: Can be used with `<a>`, `<input type="button">`, `<input type="submit">` elements
- **Recommended**: For disabled state, prefer using `disabled` attribute over `btn-disabled` class
