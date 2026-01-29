# Link

Styled underline for anchor elements, restoring default link appearance over Tailwind's CSS reset.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `link` | Component | Base class adding underline styling to links |
| `link-hover` | Style | Shows underline only on hover |
| `link-neutral` | Color | Neutral color |
| `link-primary` | Color | Primary color |
| `link-secondary` | Color | Secondary color |
| `link-accent` | Color | Accent color |
| `link-success` | Color | Success color |
| `link-info` | Color | Info color |
| `link-warning` | Color | Warning color |
| `link-error` | Color | Error color |

## Essential Examples

### Basic usage

```html
<a class="link">Click me</a>
<a class="link link-hover">Underline on hover only</a>
<a class="link link-primary">Primary link</a>
```

## Notes

- **Recommended**: Use `link` to restore underline styling that Tailwind CSS resets by default on anchor elements
