# daisyUI Colors

Semantic color system that adapts to each theme.

## Color Names

| Color | CSS Variable | Purpose |
|-------|--------------|---------|
| `primary` | `--color-primary` | Brand main color |
| `primary-content` | `--color-primary-content` | Text on primary |
| `secondary` | `--color-secondary` | Brand secondary color |
| `secondary-content` | `--color-secondary-content` | Text on secondary |
| `accent` | `--color-accent` | Accent color |
| `accent-content` | `--color-accent-content` | Text on accent |
| `neutral` | `--color-neutral` | Neutral dark |
| `neutral-content` | `--color-neutral-content` | Text on neutral |
| `base-100` | `--color-base-100` | Page background |
| `base-200` | `--color-base-200` | Darker base (elevation) |
| `base-300` | `--color-base-300` | Even darker base |
| `base-content` | `--color-base-content` | Text on base |
| `info` | `--color-info` | Info messages |
| `info-content` | `--color-info-content` | Text on info |
| `success` | `--color-success` | Success messages |
| `success-content` | `--color-success-content` | Text on success |
| `warning` | `--color-warning` | Warning messages |
| `warning-content` | `--color-warning-content` | Text on warning |
| `error` | `--color-error` | Error messages |
| `error-content` | `--color-error-content` | Text on error |

## Utility Classes

### Basic (properties.css)
- `bg-{COLOR}` - Background color
- `text-{COLOR}` - Text color
- `border-{COLOR}` - Border color

### Extended (properties-extended.css)
- `from-{COLOR}`, `via-{COLOR}`, `to-{COLOR}` - Gradients
- `ring-{COLOR}` - Ring/focus
- `fill-{COLOR}`, `stroke-{COLOR}` - SVG
- `shadow-{COLOR}` - Shadow
- `outline-{COLOR}` - Outline

## Opacity Modifier

Add `/{0-100}` to color name:

```html
<div class="text-base-content/50">50% opacity text</div>
<div class="bg-primary/20">20% opacity background</div>
```

Note: Tailwind plugin supports 0-100, CDN only supports 10,20,30...90.

## Usage Examples

```html
<!-- Component modifier -->
<button class="btn btn-primary">Primary Button</button>

<!-- Utility classes -->
<div class="bg-primary text-primary-content p-4">
  Primary background with contrasting text
</div>

<!-- Border -->
<div class="border-2 border-secondary">Secondary border</div>
```
