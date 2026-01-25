# Tooltip

Tooltip component for showing additional information on hover.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `tooltip` | Component | Container element for tooltip |
| `tooltip-content` | Part | Optional div for custom tooltip content instead of `data-tip` |
| `tooltip-top` | Placement | Positions tooltip above element (default) |
| `tooltip-bottom` | Placement | Positions tooltip below element |
| `tooltip-left` | Placement | Positions tooltip to the left |
| `tooltip-right` | Placement | Positions tooltip to the right |
| `tooltip-open` | Modifier | Forces tooltip to remain visible |
| `tooltip-neutral` | Color | Applies neutral color scheme |
| `tooltip-primary` | Color | Applies primary color scheme |
| `tooltip-secondary` | Color | Applies secondary color scheme |
| `tooltip-accent` | Color | Applies accent color scheme |
| `tooltip-info` | Color | Applies info color scheme |
| `tooltip-success` | Color | Applies success color scheme |
| `tooltip-warning` | Color | Applies warning color scheme |
| `tooltip-error` | Color | Applies error color scheme |

## Key Examples

### Basic tooltip

```html
<div class="tooltip" data-tip="Hello">
  <button class="btn">Hover me</button>
</div>
```

### Custom content tooltip

```html
<div class="tooltip">
  <div class="tooltip-content">
    <strong>Bold text</strong> and <em>italic text</em>
  </div>
  <button class="btn">Hover me</button>
</div>
```

### Tooltip positions

```html
<div class="tooltip tooltip-top" data-tip="Top tooltip">
  <button class="btn">Top</button>
</div>

<div class="tooltip tooltip-bottom" data-tip="Bottom tooltip">
  <button class="btn">Bottom</button>
</div>

<div class="tooltip tooltip-left" data-tip="Left tooltip">
  <button class="btn">Left</button>
</div>

<div class="tooltip tooltip-right" data-tip="Right tooltip">
  <button class="btn">Right</button>
</div>
```

### Tooltip colors

```html
<div class="tooltip tooltip-primary" data-tip="Primary">
  <button class="btn">Primary</button>
</div>

<div class="tooltip tooltip-secondary" data-tip="Secondary">
  <button class="btn">Secondary</button>
</div>

<div class="tooltip tooltip-accent" data-tip="Accent">
  <button class="btn">Accent</button>
</div>

<div class="tooltip tooltip-success" data-tip="Success">
  <button class="btn">Success</button>
</div>

<div class="tooltip tooltip-warning" data-tip="Warning">
  <button class="btn">Warning</button>
</div>

<div class="tooltip tooltip-error" data-tip="Error">
  <button class="btn">Error</button>
</div>
```

### Force open tooltip

```html
<div class="tooltip tooltip-open" data-tip="Always visible">
  <button class="btn">Open</button>
</div>
```

### Tooltip on different elements

```html
<!-- On text -->
<div class="tooltip" data-tip="This is a tooltip">
  <span class="underline cursor-help">Hover over this text</span>
</div>

<!-- On icon -->
<div class="tooltip" data-tip="More information">
  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class="h-6 w-6 stroke-current cursor-help">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
  </svg>
</div>

<!-- On badge -->
<div class="tooltip" data-tip="New feature">
  <span class="badge badge-primary">NEW</span>
</div>
```

### Tooltip with form label

```html
<label class="form-control w-full max-w-xs">
  <div class="label">
    <span class="label-text">Email</span>
    <div class="tooltip" data-tip="Enter your email address">
      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class="h-4 w-4 stroke-current opacity-60">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
      </svg>
    </div>
  </div>
  <input type="email" class="input input-bordered" />
</label>
```

### Responsive tooltip positions

```html
<div class="tooltip tooltip-bottom md:tooltip-top lg:tooltip-right" data-tip="Responsive position">
  <button class="btn">Responsive</button>
</div>
```
