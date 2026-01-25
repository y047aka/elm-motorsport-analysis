# Hero

Full-width banner component for landing pages and headers.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `hero` | Component | Container element |
| `hero-content` | Part | Content wrapper |
| `hero-overlay` | Part | Overlay covering background image |

## Essential Examples

### Basic centered hero

```html
<div class="hero min-h-screen bg-base-200">
  <div class="hero-content text-center">
    <div class="max-w-md">
      <h1 class="text-5xl font-bold">Hello there</h1>
      <p class="py-6">
        Provident cupiditate voluptatem et in. Quaerat fugiat ut assumenda excepturi.
      </p>
      <button class="btn btn-primary">Get Started</button>
    </div>
  </div>
</div>
```

### With background image and overlay

```html
<div class="hero min-h-screen" style="background-image: url(image.jpg);">
  <div class="hero-overlay bg-opacity-60"></div>
  <div class="hero-content text-neutral-content text-center">
    <div class="max-w-md">
      <h1 class="mb-5 text-5xl font-bold">Hello there</h1>
      <p class="mb-5">Provident cupiditate voluptatem et in.</p>
      <button class="btn btn-primary">Get Started</button>
    </div>
  </div>
</div>
```

### With side image

```html
<div class="hero min-h-screen bg-base-200">
  <div class="hero-content flex-col lg:flex-row">
    <img src="image.jpg" class="max-w-sm rounded-lg shadow-2xl" />
    <div>
      <h1 class="text-5xl font-bold">Box Office News!</h1>
      <p class="py-6">Provident cupiditate voluptatem et in.</p>
      <button class="btn btn-primary">Get Started</button>
    </div>
  </div>
</div>
```

## Notes

- Use `min-h-screen` for full-height sections
- Layout: Combine `flex-col lg:flex-row` for responsive layouts
- Overlay: Use `hero-overlay` with `bg-opacity-{value}` for image overlays
- Background: Set via inline style or Tailwind classes
