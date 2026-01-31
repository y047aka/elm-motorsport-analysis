# Hover 3D

Adds 3D tilt effect on hover by placing 8 hover zones on top of content.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `hover-3d` | Component | Wrapper for 3D hover effect |

## Essential Examples

### Basic usage

```html
<div class="hover-3d">
  <figure class="rounded-2xl">
    <img src="image.webp" alt="Description" />
  </figure>
  <div></div>
  <div></div>
  <div></div>
  <div></div>
  <div></div>
  <div></div>
  <div></div>
  <div></div>
</div>
```

### With link wrapper

```html
<a href="#" class="hover-3d">
  <figure class="rounded-2xl">
    <img src="image.webp" alt="Description" />
  </figure>
  <div></div>
  <div></div>
  <div></div>
  <div></div>
  <div></div>
  <div></div>
  <div></div>
  <div></div>
</a>
```

### Inside a card

```html
<div class="hover-3d">
  <div class="card bg-base-100 shadow-xl">
    <figure>
      <img src="image.webp" alt="Description" />
    </figure>
    <div class="card-body">
      <h2 class="card-title">Card Title</h2>
      <p>Card content</p>
    </div>
  </div>
  <div></div>
  <div></div>
  <div></div>
  <div></div>
  <div></div>
  <div></div>
  <div></div>
  <div></div>
</div>
```

## Notes

- **Required**: 8 empty `<div>` elements must follow the content for hover zones to work
- **Required**: Only non-interactive content inside (no buttons or links as children)
- **Recommended**: Wrap entire component with `<a>` if clickable behavior is needed
- **Recommended**: Combine with `rounded-*` utilities for rounded corners
