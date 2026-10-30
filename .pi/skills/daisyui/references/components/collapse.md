# Collapse

Toggleable content panel for showing and hiding content with multiple interaction methods.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `collapse` | Component | Base container for the collapsible element |
| `collapse-title` | Part | Title/header section of the collapse |
| `collapse-content` | Part | Content section that is shown or hidden |
| `collapse-arrow` | Modifier | Adds a rotating arrow icon indicator |
| `collapse-plus` | Modifier | Adds a plus/minus toggle icon |
| `collapse-open` | Modifier | Forces the collapse to remain expanded |
| `collapse-close` | Modifier | Forces the collapse to remain collapsed |

## Essential Examples

### Basic usage

```html
<!-- Checkbox-based toggle -->
<div class="collapse bg-base-100 border border-base-300">
  <input type="checkbox" />
  <div class="collapse-title font-semibold">Click me to open</div>
  <div class="collapse-content text-sm">This content is hidden by default.</div>
</div>
```

### With structure

```html
<!-- With arrow indicator -->
<div class="collapse collapse-arrow bg-base-100 border border-base-300">
  <input type="checkbox" />
  <div class="collapse-title font-semibold">Arrow indicator</div>
  <div class="collapse-content text-sm">Content with arrow toggle.</div>
</div>
```

## Notes

- **Recommended**: Prefer the checkbox method for programmatic control, the focus method for keyboard accessibility, or the details element for semantic HTML
- **Recommended**: Use `collapse-arrow` or `collapse-plus` to provide a visual toggle indicator
- **Recommended**: When used as an accordion, share the same `name` attribute on radio inputs or details elements to enforce single-item-open behavior (see accordion.md)
