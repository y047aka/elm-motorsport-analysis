# Card

Container for grouping and displaying content in an organized way.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `card` | Component | Container element |
| `card-title` | Part | Title section within card-body |
| `card-body` | Part | Content container with padding |
| `card-actions` | Part | Actions section for buttons or interactive elements |
| `card-border` | Style | Visible border |
| `card-dash` | Style | Dashed border |
| `card-side` | Modifier | The image in `<figure>` will be on the side |
| `image-full` | Modifier | The image in `<figure>` element will be the background |
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

### Side image layout

```html
<div class="card card-side bg-base-100 shadow-xl">
  <figure>
    <img src="image.jpg" alt="Image" />
  </figure>
  <div class="card-body">
    <h2 class="card-title">Side Layout</h2>
    <p>Image on the side, content on the right</p>
    <div class="card-actions justify-end">
      <button class="btn btn-primary">Watch</button>
    </div>
  </div>
</div>
```

## Notes

- **Recommended**: Use `<figure>` element for images
- **Recommended**: Combine with Tailwind utilities like `shadow-xl`, `rounded-box`, and background colors
