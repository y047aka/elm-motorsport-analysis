# Indicator

Container that positions a child element (such as a badge or status dot) on a corner of a sibling element.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `indicator` | Component | Container that enables corner positioning for indicator items |
| `indicator-item` | Part | Element positioned on a corner of its sibling |
| `indicator-start` | Placement | Align horizontally to the start |
| `indicator-center` | Placement | Align horizontally to the center |
| `indicator-end` | Placement | Align horizontally to the end |
| `indicator-top` | Placement | Align vertically to the top |
| `indicator-middle` | Placement | Align vertically to the middle |
| `indicator-bottom` | Placement | Align vertically to the bottom |

## Essential Examples

### Basic usage

```html
<div class="indicator">
  <span class="indicator-item badge badge-primary">New</span>
  <div class="bg-base-300 grid h-32 w-32 place-items-center">
    content
  </div>
</div>
```

### With structure

```html
<!-- Indicator with explicit placement (bottom-start) -->
<div class="indicator">
  <span class="indicator-item indicator-bottom indicator-start badge badge-secondary">3</span>
  <div class="bg-base-300 grid h-32 w-32 place-items-center">
    content
  </div>
</div>
```

## Notes

- **Required**: `indicator-item` must be placed inside an `indicator` container as a sibling of the target element
- **Required**: The `indicator-item` element must come before its sibling target in the DOM
- **Default**: Default position is top-end
- **Recommended**: Combine `indicator-top/middle/bottom` with `indicator-start/center/end` for other placements
