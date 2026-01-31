# Mask

Crops element content to predefined geometric shapes using CSS masking.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `mask` | Component | Base class enabling CSS mask on the element |
| `mask-squircle` | Style | Rounded square (superellipse) shape |
| `mask-heart` | Style | Heart shape |
| `mask-hexagon` | Style | Vertical hexagon |
| `mask-hexagon-2` | Style | Horizontal hexagon |
| `mask-decagon` | Style | 10-sided polygon |
| `mask-pentagon` | Style | 5-sided polygon |
| `mask-diamond` | Style | Diamond (rhombus) shape |
| `mask-square` | Style | Square shape |
| `mask-circle` | Style | Circle shape |
| `mask-star` | Style | Standard star |
| `mask-star-2` | Style | Bold (thick-armed) star |
| `mask-triangle` | Style | Upward-pointing triangle |
| `mask-triangle-2` | Style | Downward-pointing triangle |
| `mask-triangle-3` | Style | Left-pointing triangle |
| `mask-triangle-4` | Style | Right-pointing triangle |
| `mask-half-1` | Modifier | Reveals only the first half of the mask shape |
| `mask-half-2` | Modifier | Reveals only the second half of the mask shape |

## Essential Examples

### Basic usage

```html
<img class="mask mask-squircle w-32" src="image.jpg" />
<img class="mask mask-heart w-32" src="image.jpg" />
<img class="mask mask-circle w-32" src="image.jpg" />
```

### With structure

```html
<!-- Half mask (split shape across two elements) -->
<div class="flex">
  <img class="mask mask-half-1 mask-squircle w-32" src="image-left.jpg" />
  <img class="mask mask-half-2 mask-squircle w-32" src="image-right.jpg" />
</div>
```

## Notes

- **Recommended**: All shape classes follow the same pattern: combine `mask` base class with exactly one shape style class (e.g., `mask mask-diamond`)
- **Recommended**: Use `mask-half-1` and `mask-half-2` together on adjacent elements to create split-image effects
