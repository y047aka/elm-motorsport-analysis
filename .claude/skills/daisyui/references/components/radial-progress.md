# Radial Progress

Circular progress indicator driven by CSS custom properties.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `radial-progress` | Component | Circular progress ring |

## CSS Custom Properties

| Property | Description | Default |
|----------|-------------|---------|
| `--value` | Progress percentage (0-100) | Required |
| `--size` | Component dimensions | 5rem |
| `--thickness` | Ring stroke width | 10% of size |

## Essential Examples

### Basic usage

```html
<div class="radial-progress" style="--value:70;" aria-valuenow="70" role="progressbar">
  70%
</div>
```

### With structure

```html
<!-- Custom size and thickness via CSS variables -->
<div class="radial-progress" style="--value:50; --size:12rem; --thickness:2rem;" aria-valuenow="50" role="progressbar">
  50%
</div>
```

## Notes

- **Required**: Must be a `<div>` element, not `<progress>` (browsers cannot display text inside `<progress>` and Firefox does not render pseudo-elements within them)
- **Required**: Set `--value` CSS custom property inline (0-100) to control progress percentage
- **Required**: Include `role="progressbar"` and `aria-valuenow` attributes for accessibility
- **Recommended**: Customize size with `--size` CSS variable (default: `5rem`)
- **Recommended**: Customize ring thickness with `--thickness` CSS variable (default: 10% of `--size`)
- **Recommended**: Use text color classes (e.g., `text-primary`) to change the progress ring color
