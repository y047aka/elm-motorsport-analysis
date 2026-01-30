# Layout Components

Guide for building page layouts with daisyUI. For specific component details, see individual files in `components/`.

## Quick Reference

| Component | Use Case | Base Class |
|-----------|----------|------------|
| [card](components/card.md) | Content container with image/body/actions | `card` |
| [modal](components/modal.md) | Dialog overlay | `modal` |
| [hero](components/hero.md) | Landing page banner | `hero` |
| [footer](components/footer.md) | Page footer with links | `footer` |
| [divider](components/divider.md) | Section separator | `divider` |
| [join](components/join.md) | Group elements with shared borders | `join` |
| [indicator](components/indicator.md) | Position badge on corner | `indicator` |
| [stack](components/stack.md) | Layer elements on top | `stack` |
| [dock](components/dock.md) | Bottom navigation bar | `dock` |
| [fab](components/fab.md) | Floating action button | `fab` |
| [mask](components/mask.md) | Crop to geometric shapes | `mask` |

## Card

### Basic Card Structure

```html
<div class="card bg-base-100 shadow-xl">
  <figure>
    <img src="image.jpg" alt="Image" />
  </figure>
  <div class="card-body">
    <h2 class="card-title">Title</h2>
    <p>Description</p>
    <div class="card-actions justify-end">
      <button class="btn btn-primary">Action</button>
    </div>
  </div>
</div>
```

### Card Variants

```
card-side       Image on side instead of top
image-full      Image as background overlay
card-border     Visible border
card-dash       Dashed border
```

### Card Sizes

```
card-xs, card-sm, card-md (default), card-lg, card-xl
```

## Modal

### Basic Modal (Dialog Element)

```html
<button class="btn" onclick="my_modal.showModal()">Open</button>

<dialog id="my_modal" class="modal">
  <div class="modal-box">
    <h3 class="text-lg font-bold">Title</h3>
    <p class="py-4">Content</p>
    <div class="modal-action">
      <form method="dialog">
        <button class="btn">Close</button>
      </form>
    </div>
  </div>
</dialog>
```

### Close on Outside Click

```html
<dialog id="my_modal" class="modal">
  <div class="modal-box">
    <h3 class="font-bold">Title</h3>
    <p>Content</p>
  </div>
  <form method="dialog" class="modal-backdrop">
    <button>close</button>
  </form>
</dialog>
```

### Modal Positioning

```
modal-top        Top of screen
modal-middle     Center (default)
modal-bottom     Bottom of screen
modal-start      Left side
modal-end        Right side
```

Responsive: `modal-bottom sm:modal-middle`

## Hero

### Basic Hero

```html
<div class="hero min-h-screen bg-base-200">
  <div class="hero-content text-center">
    <div class="max-w-md">
      <h1 class="text-5xl font-bold">Title</h1>
      <p class="py-6">Description</p>
      <button class="btn btn-primary">Get Started</button>
    </div>
  </div>
</div>
```

### Hero with Background Image

```html
<div class="hero min-h-screen" style="background-image: url(image.jpg);">
  <div class="hero-overlay bg-opacity-60"></div>
  <div class="hero-content text-neutral-content text-center">
    <div class="max-w-md">
      <h1 class="text-5xl font-bold">Title</h1>
      <p class="py-6">Description</p>
    </div>
  </div>
</div>
```

### Hero with Side Image

```html
<div class="hero min-h-screen bg-base-200">
  <div class="hero-content flex-col lg:flex-row">
    <img src="image.jpg" class="max-w-sm rounded-lg shadow-2xl" />
    <div>
      <h1 class="text-5xl font-bold">Title</h1>
      <p class="py-6">Description</p>
      <button class="btn btn-primary">Get Started</button>
    </div>
  </div>
</div>
```

## Footer

### Basic Footer

```html
<footer class="footer bg-neutral text-neutral-content p-10">
  <nav>
    <h6 class="footer-title">Services</h6>
    <a class="link link-hover">Branding</a>
    <a class="link link-hover">Design</a>
  </nav>
  <nav>
    <h6 class="footer-title">Company</h6>
    <a class="link link-hover">About us</a>
    <a class="link link-hover">Contact</a>
  </nav>
</footer>
```

### Centered Footer

```html
<footer class="footer footer-center bg-base-200 text-base-content p-4">
  <p>Copyright 2024 - All rights reserved</p>
</footer>
```

## Divider

### Horizontal Divider

```html
<div class="divider">OR</div>
```

### Vertical Divider

```html
<div class="flex">
  <div>Left content</div>
  <div class="divider divider-horizontal">OR</div>
  <div>Right content</div>
</div>
```

### Divider Colors

```
divider-neutral, divider-primary, divider-secondary, divider-accent
divider-info, divider-success, divider-warning, divider-error
```

## Join (Group Elements)

### Horizontal Group

```html
<div class="join">
  <button class="btn join-item">Left</button>
  <button class="btn join-item">Center</button>
  <button class="btn join-item">Right</button>
</div>
```

### Vertical Group

```html
<div class="join join-vertical">
  <button class="btn join-item">Top</button>
  <button class="btn join-item">Middle</button>
  <button class="btn join-item">Bottom</button>
</div>
```

### Mixed Content

```html
<div class="join">
  <input class="input join-item" placeholder="Search" />
  <button class="btn join-item">Go</button>
</div>
```

## Indicator

Position a badge on element corner:

```html
<div class="indicator">
  <span class="indicator-item badge badge-primary">99+</span>
  <button class="btn">Inbox</button>
</div>
```

### Indicator Positions

```
Vertical:   indicator-top, indicator-middle, indicator-bottom
Horizontal: indicator-start, indicator-center, indicator-end
```

Default: top-end

## Dock (Bottom Navigation)

```html
<div class="dock">
  <button>
    <svg><!-- icon --></svg>
    <span class="dock-label">Home</span>
  </button>
  <button class="dock-active">
    <svg><!-- icon --></svg>
    <span class="dock-label">Inbox</span>
  </button>
  <button>
    <svg><!-- icon --></svg>
    <span class="dock-label">Profile</span>
  </button>
</div>
```

### Dock Sizes

```
dock-xs, dock-sm, dock-md (default), dock-lg, dock-xl
```

## FAB (Floating Action Button)

```html
<div class="fab">
  <div tabindex="0" role="button" class="btn btn-lg btn-circle btn-primary">+</div>
  <button class="btn btn-lg btn-circle btn-accent">A</button>
  <button class="btn btn-lg btn-circle btn-accent">B</button>
</div>
```

Use `fab-flower` for quarter-circle arrangement.

## Mask (Shape Cropping)

```html
<img class="mask mask-squircle w-24" src="avatar.jpg" />
<img class="mask mask-hexagon w-24" src="avatar.jpg" />
<img class="mask mask-heart w-24" src="avatar.jpg" />
```

### Available Shapes

```
mask-squircle, mask-circle, mask-square
mask-heart, mask-star, mask-star-2
mask-hexagon, mask-hexagon-2, mask-pentagon, mask-decagon
mask-diamond, mask-triangle, mask-triangle-2, mask-triangle-3, mask-triangle-4
```

## Component Selection Guide

| Need | Use |
|------|-----|
| Content container | `card` |
| Dialog/popup | `modal` |
| Landing banner | `hero` |
| Page footer | `footer` |
| Section separator | `divider` |
| Group buttons/inputs | `join` |
| Badge on corner | `indicator` |
| Layer elements | `stack` |
| Mobile bottom nav | `dock` |
| Floating actions | `fab` |
| Shape cropping | `mask` |

## Related Patterns

- [Dashboard Layout](patterns.md#dashboard-layout) - Stats + card layout
- [Authentication Page](patterns.md#authentication-page) - Card-based form
