# Progress

Progress bar for showing task completion or time passage.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `progress` | Component | Base `<progress>` element |
| `progress-neutral` | Color | Neutral color |
| `progress-primary` | Color | Primary color |
| `progress-secondary` | Color | Secondary color |
| `progress-accent` | Color | Accent color |
| `progress-info` | Color | Info color |
| `progress-success` | Color | Success color |
| `progress-warning` | Color | Warning color |
| `progress-error` | Color | Error color |

## Essential Examples

### Basic usage

```html
<progress class="progress w-56" value="0" max="100"></progress>
<progress class="progress w-56" value="40" max="100"></progress>
<progress class="progress w-56" value="70" max="100"></progress>
<progress class="progress w-56" value="100" max="100"></progress>
```

### Indeterminate (no value)

```html
<progress class="progress w-56"></progress>
<progress class="progress progress-primary w-56"></progress>
```

### With label

```html
<div class="flex flex-col gap-2 w-full">
  <div class="flex justify-between text-sm">
    <span>Processing...</span>
    <span>70%</span>
  </div>
  <progress class="progress progress-primary" value="70" max="100"></progress>
</div>
```

## Notes

- **Recommended**: Omit `value` attribute for indeterminate loading animation
- **Recommended**: Use Tailwind width classes for sizing (e.g., `w-56`, `w-full`)
