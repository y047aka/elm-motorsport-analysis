# Range

Slider input for selecting a value within a defined range.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `range` | Component | Base class for range slider (`<input type="range">`) |
| `range-neutral` | Color | Neutral color |
| `range-primary` | Color | Primary color |
| `range-secondary` | Color | Secondary color |
| `range-accent` | Color | Accent color |
| `range-success` | Color | Success color |
| `range-warning` | Color | Warning color |
| `range-info` | Color | Info color |
| `range-error` | Color | Error color |
| `range-xs` | Size | Extra small |
| `range-sm` | Size | Small |
| `range-md` | Size | Medium (default) |
| `range-lg` | Size | Large |
| `range-xl` | Size | Extra large |

## Essential Examples

### Basic usage

```html
<input type="range" min="0" max="100" value="40" class="range" />
```

### With step markers and labels

```html
<div class="w-full max-w-xs">
  <input type="range" min="0" max="100" value="25" class="range" step="25" />
  <div class="flex justify-between px-2.5 mt-2 text-xs">
    <span>|</span>
    <span>|</span>
    <span>|</span>
    <span>|</span>
    <span>|</span>
  </div>
  <div class="flex justify-between px-2.5 mt-2 text-xs">
    <span>1</span>
    <span>2</span>
    <span>3</span>
    <span>4</span>
    <span>5</span>
  </div>
</div>
```

### CSS variable customization

```html
<input type="range" min="0" max="100" value="40" class="range [--range-bg:orange] [--range-thumb:blue] [--range-fill:0]" />
```

## Notes

- **CSS variable**: `--range-fill` can be set to 0 to disable the fill color
- **Recommended**: Use CSS variables for fine-grained styling: `--range-bg` (track color), `--range-thumb` (handle color), `--range-fill` (set to `0` to disable fill)
- **Recommended**: Use Tailwind width classes (e.g., `w-full`, `max-w-xs`) to control slider width
