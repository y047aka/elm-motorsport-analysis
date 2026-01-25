# Loading

Loading indicator component for async operations with multiple animation styles.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `loading` | Component | Loading element base class |
| `loading-spinner` | Style | Spinner animation |
| `loading-dots` | Style | Dots animation |
| `loading-ring` | Style | Ring animation |
| `loading-ball` | Style | Ball animation |
| `loading-bars` | Style | Bars animation |
| `loading-infinity` | Style | Infinity animation |
| `loading-xs` | Size | Extra small size |
| `loading-sm` | Size | Small size |
| `loading-md` | Size | Medium size (default) |
| `loading-lg` | Size | Large size |
| `loading-xl` | Size | Extra large size |

## Key Examples

### Loading types

```html
<span class="loading loading-spinner"></span>
<span class="loading loading-dots"></span>
<span class="loading loading-ring"></span>
<span class="loading loading-ball"></span>
<span class="loading loading-bars"></span>
<span class="loading loading-infinity"></span>
```

### Loading sizes

```html
<span class="loading loading-spinner loading-xs"></span>
<span class="loading loading-spinner loading-sm"></span>
<span class="loading loading-spinner loading-md"></span>
<span class="loading loading-spinner loading-lg"></span>
<span class="loading loading-spinner loading-xl"></span>
```

### Loading with colors

```html
<span class="loading loading-spinner text-primary"></span>
<span class="loading loading-spinner text-secondary"></span>
<span class="loading loading-spinner text-accent"></span>
<span class="loading loading-spinner text-neutral"></span>
<span class="loading loading-spinner text-info"></span>
<span class="loading loading-spinner text-success"></span>
<span class="loading loading-spinner text-warning"></span>
<span class="loading loading-spinner text-error"></span>
```

### In button

```html
<button class="btn">
  <span class="loading loading-spinner"></span>
  Loading
</button>

<button class="btn btn-primary">
  <span class="loading loading-spinner"></span>
  Loading
</button>

<button class="btn btn-square">
  <span class="loading loading-spinner"></span>
</button>
```

### Full page loading

```html
<div class="fixed inset-0 bg-base-100/80 flex items-center justify-center z-50">
  <div class="text-center">
    <span class="loading loading-spinner loading-lg"></span>
    <p class="mt-4">Loading...</p>
  </div>
</div>
```

### Loading overlay on card

```html
<div class="relative">
  <div class="card bg-base-100 w-72 shadow-xl">
    <div class="card-body">
      <h2 class="card-title">Card Title</h2>
      <p>Content here...</p>
    </div>
  </div>
  <div class="absolute inset-0 bg-base-100/80 flex items-center justify-center rounded-box">
    <span class="loading loading-spinner loading-lg"></span>
  </div>
</div>
```

### With text

```html
<div class="flex items-center gap-2">
  <span class="loading loading-spinner"></span>
  <span>Loading data...</span>
</div>
```
