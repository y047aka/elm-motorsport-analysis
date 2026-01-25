# Card

Container component for grouping related content and actions.

## Class Reference

| Class | Description |
|-------|-------------|
| `card` | Container element |
| `card-body` | Content container with padding |
| `card-title` | Title element |
| `card-actions` | Actions container |
| `card-compact` | Reduced padding |
| `card-normal` | Normal padding (default) |
| `card-side` | Horizontal layout (image on side) |
| `card-bordered` | Visible border |
| `image-full` | Image as background overlay |
| `glass` | Frosted glass effect |

## Key Examples

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

### Card without image

```html
<div class="card bg-base-100 w-96 shadow-xl">
  <div class="card-body">
    <h2 class="card-title">Card Title</h2>
    <p>Content goes here</p>
  </div>
</div>
```

### Horizontal card (card-side)

```html
<div class="card card-side bg-base-100 shadow-xl">
  <figure>
    <img src="image.jpg" alt="Image" />
  </figure>
  <div class="card-body">
    <h2 class="card-title">Side Card</h2>
    <p>Image on the side</p>
    <div class="card-actions justify-end">
      <button class="btn btn-primary">Watch</button>
    </div>
  </div>
</div>
```

### Card with color variants

```html
<!-- Primary background -->
<div class="card bg-primary text-primary-content w-96">
  <div class="card-body">
    <h2 class="card-title">Primary Card</h2>
    <p>Primary background color</p>
  </div>
</div>

<!-- Neutral background -->
<div class="card bg-neutral text-neutral-content w-96">
  <div class="card-body">
    <h2 class="card-title">Neutral Card</h2>
    <p>Neutral background color</p>
  </div>
</div>
```

### Card with badge

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

### Image overlay card

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
