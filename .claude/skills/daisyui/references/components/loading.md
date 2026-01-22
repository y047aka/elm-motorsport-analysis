# Loading

Loading indicator component for async operations.

## Loading Types

```html
<!-- Spinner -->
<span class="loading loading-spinner"></span>

<!-- Dots -->
<span class="loading loading-dots"></span>

<!-- Ring -->
<span class="loading loading-ring"></span>

<!-- Ball -->
<span class="loading loading-ball"></span>

<!-- Bars -->
<span class="loading loading-bars"></span>

<!-- Infinity -->
<span class="loading loading-infinity"></span>
```

## Sizes

```html
<!-- Extra small -->
<span class="loading loading-spinner loading-xs"></span>

<!-- Small -->
<span class="loading loading-spinner loading-sm"></span>

<!-- Medium -->
<span class="loading loading-spinner loading-md"></span>

<!-- Large -->
<span class="loading loading-spinner loading-lg"></span>
```

## All Types with Sizes

```html
<!-- Spinner sizes -->
<span class="loading loading-spinner loading-xs"></span>
<span class="loading loading-spinner loading-sm"></span>
<span class="loading loading-spinner loading-md"></span>
<span class="loading loading-spinner loading-lg"></span>

<!-- Dots sizes -->
<span class="loading loading-dots loading-xs"></span>
<span class="loading loading-dots loading-sm"></span>
<span class="loading loading-dots loading-md"></span>
<span class="loading loading-dots loading-lg"></span>

<!-- Ring sizes -->
<span class="loading loading-ring loading-xs"></span>
<span class="loading loading-ring loading-sm"></span>
<span class="loading loading-ring loading-md"></span>
<span class="loading loading-ring loading-lg"></span>

<!-- Ball sizes -->
<span class="loading loading-ball loading-xs"></span>
<span class="loading loading-ball loading-sm"></span>
<span class="loading loading-ball loading-md"></span>
<span class="loading loading-ball loading-lg"></span>

<!-- Bars sizes -->
<span class="loading loading-bars loading-xs"></span>
<span class="loading loading-bars loading-sm"></span>
<span class="loading loading-bars loading-md"></span>
<span class="loading loading-bars loading-lg"></span>
```

## Colors

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

## In Button

```html
<button class="btn">
  <span class="loading loading-spinner"></span>
  Loading
</button>

<button class="btn btn-primary">
  <span class="loading loading-spinner"></span>
  Loading
</button>

<!-- Square button with loading -->
<button class="btn btn-square">
  <span class="loading loading-spinner"></span>
</button>
```

## Loading Overlay

```html
<div class="relative">
  <div class="card bg-base-100 w-72 shadow-xl">
    <div class="card-body">
      <h2 class="card-title">Card Title</h2>
      <p>Content here...</p>
    </div>
  </div>
  <!-- Overlay -->
  <div class="absolute inset-0 bg-base-100/80 flex items-center justify-center rounded-box">
    <span class="loading loading-spinner loading-lg"></span>
  </div>
</div>
```

## Full Page Loading

```html
<div class="fixed inset-0 bg-base-100/80 flex items-center justify-center z-50">
  <div class="text-center">
    <span class="loading loading-spinner loading-lg"></span>
    <p class="mt-4">Loading...</p>
  </div>
</div>
```

## With Text

```html
<div class="flex items-center gap-2">
  <span class="loading loading-spinner"></span>
  <span>Loading data...</span>
</div>
```

## In Table

```html
<table class="table">
  <thead>
    <tr>
      <th>Name</th>
      <th>Status</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Task 1</td>
      <td><span class="loading loading-spinner loading-xs"></span></td>
    </tr>
    <tr>
      <td>Task 2</td>
      <td><span class="badge badge-success">Done</span></td>
    </tr>
  </tbody>
</table>
```

## Classes Reference

| Class | Description |
|-------|-------------|
| `loading` | Base loading class |
| `loading-spinner` | Spinner animation |
| `loading-dots` | Dots animation |
| `loading-ring` | Ring animation |
| `loading-ball` | Ball animation |
| `loading-bars` | Bars animation |
| `loading-infinity` | Infinity animation |
| `loading-xs` | Extra small size |
| `loading-sm` | Small size |
| `loading-md` | Medium size |
| `loading-lg` | Large size |

Note: Use text color utilities (`text-primary`, etc.) to change colors.
