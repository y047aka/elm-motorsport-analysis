# Card

Container for grouping and displaying content in an organized way.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `card` | Component | Container element |
| `card-title` | Part | Title section |
| `card-body` | Part | Content container with padding |
| `card-actions` | Part | Actions section (buttons, etc.) |
| `card-border` | Style | Visible border |
| `card-dash` | Style | Dashed border |
| `card-side` | Modifier | Horizontal layout (image on side) |
| `image-full` | Modifier | Image as background |
| `card-xs` | Size | Extra small |
| `card-sm` | Size | Small |
| `card-md` | Size | Medium (default) |
| `card-lg` | Size | Large |
| `card-xl` | Size | Extra large |

## Essential Examples

### Basic card

```html
<div class="card bg-base-100 w-96 shadow-xl">
  <figure>
    <img src="image.jpg" alt="Image" />
  </figure>
  <div class="card-body">
    <h2 class="card-title">Card Title</h2>
    <p>Description text goes here</p>
    <div class="card-actions justify-end">
      <button class="btn btn-primary">Buy Now</button>
    </div>
  </div>
</div>
```

### With badge

```html
<div class="card bg-base-100 w-96 shadow-xl">
  <div class="card-body">
    <h2 class="card-title">
      Card Title
      <div class="badge badge-secondary">NEW</div>
    </h2>
    <p>Description here</p>
    <div class="card-actions justify-end">
      <div class="badge badge-outline">Fashion</div>
      <div class="badge badge-outline">Products</div>
    </div>
  </div>
</div>
```

### Image overlay

```html
<div class="card bg-base-100 w-96 image-full">
  <figure>
    <img src="image.jpg" alt="Image" />
  </figure>
  <div class="card-body">
    <h2 class="card-title">Image Overlay</h2>
    <p>Content overlays the image</p>
    <div class="card-actions justify-end">
      <button class="btn btn-primary">Action</button>
    </div>
  </div>
</div>
```

## Notes

- Use `<figure>` for images
- Combine with Tailwind: `shadow-xl`, `rounded-box`, background colors
- Colors: Apply via `bg-{color}` with matching `text-{color}-content`
