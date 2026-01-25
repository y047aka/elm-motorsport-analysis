# Card

Cards are used to group and display content in a way that is easily readable.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `card` | Component | Container element for card |
| `card-title` | Part | Title part of the card |
| `card-body` | Part | Body part (content container with padding) |
| `card-actions` | Part | Actions part (buttons, etc.) |
| `card-border` | Style | Adds a visible border around the card |
| `card-dash` | Style | Applies a dashed border style |
| `card-side` | Modifier | Positions image from `<figure>` element to the side |
| `image-full` | Modifier | Makes image in `<figure>` the background |
| `card-xs` | Size | Extra small card dimensions |
| `card-sm` | Size | Small card dimensions |
| `card-md` | Size | Medium card (default) |
| `card-lg` | Size | Large card dimensions |
| `card-xl` | Size | Extra large card dimensions |

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

### Card with border styles

```html
<!-- Border style -->
<div class="card card-border bg-base-100 w-96">
  <div class="card-body">
    <h2 class="card-title">Bordered Card</h2>
    <p>Card with solid border</p>
  </div>
</div>

<!-- Dash style -->
<div class="card card-dash bg-base-100 w-96">
  <div class="card-body">
    <h2 class="card-title">Dashed Card</h2>
    <p>Card with dashed border</p>
  </div>
</div>
```

### Card sizes

```html
<!-- Extra small -->
<div class="card card-xs bg-base-100 shadow-xl">
  <div class="card-body">
    <h2 class="card-title">XS Card</h2>
  </div>
</div>

<!-- Large -->
<div class="card card-lg bg-base-100 shadow-xl">
  <div class="card-body">
    <h2 class="card-title">Large Card</h2>
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

### Card without image

```html
<div class="card bg-base-100 w-96 shadow-xl">
  <div class="card-body">
    <h2 class="card-title">Card Title</h2>
    <p>Content goes here</p>
  </div>
</div>
```
