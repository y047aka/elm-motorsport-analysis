# Tooltip

Component for showing additional information on hover.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `tooltip` | Component | Container element |
| `tooltip-content` | Part | Custom content instead of `data-tip` |
| `tooltip-top` | Placement | Position above (default) |
| `tooltip-bottom` | Placement | Position below |
| `tooltip-left` | Placement | Position to left |
| `tooltip-right` | Placement | Position to right |
| `tooltip-open` | Modifier | Force visible |
| `tooltip-neutral` | Color | Neutral color |
| `tooltip-primary` | Color | Primary color |
| `tooltip-secondary` | Color | Secondary color |
| `tooltip-accent` | Color | Accent color |
| `tooltip-info` | Color | Info color |
| `tooltip-success` | Color | Success color |
| `tooltip-warning` | Color | Warning color |
| `tooltip-error` | Color | Error color |

## Essential Examples

### Basic usage

```html
<div class="tooltip" data-tip="Hello">
  <button class="btn">Hover me</button>
</div>
```

### Positions

```html
<div class="tooltip tooltip-top" data-tip="Top tooltip">
  <button class="btn">Top</button>
</div>

<div class="tooltip tooltip-bottom" data-tip="Bottom tooltip">
  <button class="btn">Bottom</button>
</div>

<div class="tooltip tooltip-left" data-tip="Left tooltip">
  <button class="btn">Left</button>
</div>

<div class="tooltip tooltip-right" data-tip="Right tooltip">
  <button class="btn">Right</button>
</div>
```

### On different elements

```html
<!-- On text -->
<div class="tooltip" data-tip="This is a tooltip">
  <span class="underline cursor-help">Hover over this text</span>
</div>

<!-- On icon -->
<div class="tooltip" data-tip="More information">
  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class="h-6 w-6 stroke-current cursor-help">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
  </svg>
</div>

<!-- On badge -->
<div class="tooltip" data-tip="New feature">
  <span class="badge badge-primary">NEW</span>
</div>
```

### Force open

```html
<div class="tooltip tooltip-open" data-tip="Always visible">
  <button class="btn">Open</button>
</div>
```

## Notes

- Custom content: Use `tooltip-content` div for rich content
- Responsive: Combine with breakpoint classes (e.g., `tooltip-bottom md:tooltip-top`)
