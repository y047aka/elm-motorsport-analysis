# Tooltip

Tooltip component for showing additional information on hover.

## Basic Usage

```html
<div class="tooltip" data-tip="Hello">
  <button class="btn">Hover me</button>
</div>
```

## Positions

```html
<!-- Top (default) -->
<div class="tooltip tooltip-top" data-tip="Top tooltip">
  <button class="btn">Top</button>
</div>

<!-- Bottom -->
<div class="tooltip tooltip-bottom" data-tip="Bottom tooltip">
  <button class="btn">Bottom</button>
</div>

<!-- Left -->
<div class="tooltip tooltip-left" data-tip="Left tooltip">
  <button class="btn">Left</button>
</div>

<!-- Right -->
<div class="tooltip tooltip-right" data-tip="Right tooltip">
  <button class="btn">Right</button>
</div>
```

## Force Open

```html
<div class="tooltip tooltip-open" data-tip="Always visible">
  <button class="btn">Open</button>
</div>
```

## Color Variants

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

<div class="tooltip tooltip-neutral" data-tip="Neutral">
  <button class="btn">Neutral</button>
</div>
```

## State Colors

```html
<div class="tooltip tooltip-info" data-tip="Info tooltip">
  <button class="btn">Info</button>
</div>

<div class="tooltip tooltip-success" data-tip="Success tooltip">
  <button class="btn">Success</button>
</div>

<div class="tooltip tooltip-warning" data-tip="Warning tooltip">
  <button class="btn">Warning</button>
</div>

<div class="tooltip tooltip-error" data-tip="Error tooltip">
  <button class="btn">Error</button>
</div>
```

## On Different Elements

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

## Responsive Tooltip

```html
<div class="tooltip tooltip-bottom md:tooltip-top lg:tooltip-right" data-tip="Responsive position">
  <button class="btn">Responsive</button>
</div>
```

## Multiline Tooltip

```html
<div class="tooltip" data-tip="Line 1&#10;Line 2&#10;Line 3">
  <button class="btn">Multiline</button>
</div>
```

## With Form Elements

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

## In Table Header

```html
<table class="table">
  <thead>
    <tr>
      <th>
        <div class="tooltip" data-tip="User's full name">
          Name
        </div>
      </th>
      <th>
        <div class="tooltip" data-tip="User's email address">
          Email
        </div>
      </th>
      <th>
        <div class="tooltip" data-tip="Account status">
          Status
        </div>
      </th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>John Doe</td>
      <td>john@example.com</td>
      <td><span class="badge badge-success">Active</span></td>
    </tr>
  </tbody>
</table>
```

## Long Content

```html
<div class="tooltip" data-tip="This is a very long tooltip text that explains something in detail. It will wrap to multiple lines if necessary.">
  <button class="btn">Long tooltip</button>
</div>
```

## Classes Reference

| Class | Description |
|-------|-------------|
| `tooltip` | Container element |
| `tooltip-open` | Force tooltip to show |
| `tooltip-top` | Position at top (default) |
| `tooltip-bottom` | Position at bottom |
| `tooltip-left` | Position at left |
| `tooltip-right` | Position at right |
| `tooltip-primary` | Primary color |
| `tooltip-secondary` | Secondary color |
| `tooltip-accent` | Accent color |
| `tooltip-neutral` | Neutral color |
| `tooltip-info` | Info state color |
| `tooltip-success` | Success state color |
| `tooltip-warning` | Warning state color |
| `tooltip-error` | Error state color |

Note: Tooltip content is set via the `data-tip` attribute.
