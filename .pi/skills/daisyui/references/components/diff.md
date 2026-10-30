# Diff

Interactive side-by-side comparison component with a draggable resizer divider.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `diff` | Component | Container for the side-by-side comparison |
| `diff-item-1` | Part | First item in the comparison (revealed by moving resizer right) |
| `diff-item-2` | Part | Second item in the comparison (revealed by moving resizer left) |
| `diff-resizer` | Part | Draggable divider control for adjusting the split position |

## Essential Examples

### Basic usage

```html
<figure class="diff aspect-16/9" tabindex="0">
  <div class="diff-item-1" role="img" tabindex="0">
    <img src="image1.jpg" />
  </div>
  <div class="diff-item-2" role="img">
    <img src="image2.jpg" />
  </div>
  <div class="diff-resizer"></div>
</figure>
```

### With structure

```html
<!-- Diff with text content instead of images -->
<figure class="diff aspect-16/9" tabindex="0">
  <div class="diff-item-1 flex items-center justify-center bg-base-100" role="img" tabindex="0">
    <span class="text-lg font-bold">Before</span>
  </div>
  <div class="diff-item-2 flex items-center justify-center bg-base-200" role="img">
    <span class="text-lg font-bold">After</span>
  </div>
  <div class="diff-resizer"></div>
</figure>
```

## Notes

- **Required**: The `diff-resizer` element must be included as a sibling of `diff-item-1` and `diff-item-2` inside the `diff` container to enable the interactive slider
- **Recommended**: Use `tabindex="0"` on the `diff` container and on `diff-item-1` for keyboard accessibility
- **Recommended**: Use `role="img"` on diff items when the content is visual (images) for screen reader support
- **Recommended**: Size the component using Tailwind aspect ratio utilities (e.g., `aspect-16/9`) rather than fixed dimensions
