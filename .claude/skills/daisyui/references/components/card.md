# Card

Container component for grouping related content and actions.

## Basic Usage

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

## Card Without Image

```html
<div class="card bg-base-100 w-96 shadow-xl">
  <div class="card-body">
    <h2 class="card-title">Card Title</h2>
    <p>Content goes here</p>
  </div>
</div>
```

## Compact Card

```html
<div class="card card-compact bg-base-100 w-96 shadow-xl">
  <figure>
    <img src="image.jpg" alt="Image" />
  </figure>
  <div class="card-body">
    <h2 class="card-title">Compact Card</h2>
    <p>Less padding</p>
    <div class="card-actions justify-end">
      <button class="btn btn-primary btn-sm">Action</button>
    </div>
  </div>
</div>
```

## Side Card (Horizontal)

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

## Bordered Card

```html
<div class="card card-bordered bg-base-100 w-96">
  <div class="card-body">
    <h2 class="card-title">Bordered Card</h2>
    <p>Has a visible border</p>
  </div>
</div>
```

## Color Variants

```html
<!-- Primary -->
<div class="card bg-primary text-primary-content w-96">
  <div class="card-body">
    <h2 class="card-title">Primary Card</h2>
    <p>Primary background color</p>
  </div>
</div>

<!-- Neutral -->
<div class="card bg-neutral text-neutral-content w-96">
  <div class="card-body">
    <h2 class="card-title">Neutral Card</h2>
    <p>Neutral background color</p>
  </div>
</div>
```

## Image Overlay

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

## Card with Badge

```html
<div class="card bg-base-100 w-96 shadow-xl">
  <figure>
    <img src="image.jpg" alt="Image" />
  </figure>
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

## Centered Content

```html
<div class="card bg-base-100 w-96 shadow-xl">
  <figure class="px-10 pt-10">
    <img src="image.jpg" alt="Image" class="rounded-xl" />
  </figure>
  <div class="card-body items-center text-center">
    <h2 class="card-title">Centered!</h2>
    <p>Content is centered</p>
    <div class="card-actions">
      <button class="btn btn-primary">Buy Now</button>
    </div>
  </div>
</div>
```

## Glass Card

```html
<div class="card bg-base-100 w-96 glass">
  <figure>
    <img src="image.jpg" alt="Image" />
  </figure>
  <div class="card-body">
    <h2 class="card-title">Glass Effect</h2>
    <p>Frosted glass appearance</p>
  </div>
</div>
```

## Responsive Card

```html
<div class="card card-side bg-base-100 shadow-xl lg:card-normal">
  <figure>
    <img src="image.jpg" alt="Image" />
  </figure>
  <div class="card-body">
    <h2 class="card-title">Responsive</h2>
    <p>Side on mobile, normal on large</p>
  </div>
</div>
```

## Classes Reference

| Class | Description |
|-------|-------------|
| `card` | Container element |
| `card-body` | Content container with padding |
| `card-title` | Title element |
| `card-actions` | Actions container |
| `card-compact` | Less padding |
| `card-normal` | Normal padding (default) |
| `card-side` | Horizontal layout |
| `card-bordered` | Visible border |
| `image-full` | Image as background |
| `glass` | Glass effect |
