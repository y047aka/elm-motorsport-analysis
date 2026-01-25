# Loading

Loading indicator for async operations.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `loading` | Component | Base loading element |
| `loading-spinner` | Style | Spinner animation |
| `loading-dots` | Style | Dots animation |
| `loading-ring` | Style | Ring animation |
| `loading-ball` | Style | Ball animation |
| `loading-bars` | Style | Bars animation |
| `loading-infinity` | Style | Infinity animation |
| `loading-xs` | Size | Extra small |
| `loading-sm` | Size | Small |
| `loading-md` | Size | Medium (default) |
| `loading-lg` | Size | Large |
| `loading-xl` | Size | Extra large |

## Essential Examples

### Basic usage

```html
<span class="loading loading-spinner"></span>
<span class="loading loading-dots"></span>
<span class="loading loading-ring"></span>
<span class="loading loading-ball"></span>
<span class="loading loading-bars"></span>
<span class="loading loading-infinity"></span>
```

### In button

```html
<button class="btn">
  <span class="loading loading-spinner"></span>
  Loading
</button>

<button class="btn btn-square">
  <span class="loading loading-spinner"></span>
</button>
```

### With colors

```html
<span class="loading loading-spinner text-primary"></span>
<span class="loading loading-spinner text-secondary"></span>
<span class="loading loading-spinner text-accent"></span>
```

## Notes

- Colors: Use Tailwind `text-{color}` classes
- Common use: Inside buttons, overlays, or standalone with text
