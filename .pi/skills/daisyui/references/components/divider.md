# Divider

A divider line between two elements, supporting horizontal and vertical orientation with optional text labels.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `divider` | Component | Base class for divider (horizontal by default) |
| `divider-neutral` | Color | Neutral color |
| `divider-primary` | Color | Primary color |
| `divider-secondary` | Color | Secondary color |
| `divider-accent` | Color | Accent color |
| `divider-success` | Color | Success color |
| `divider-warning` | Color | Warning color |
| `divider-info` | Color | Info color |
| `divider-error` | Color | Error color |
| `divider-vertical` | direction | Vertical orientation for side-by-side elements |
| `divider-horizontal` | direction | Horizontal orientation (explicit, same as default) |
| `divider-start` | Placement | Pushes the divider text to the start |
| `divider-end` | Placement | Pushes the divider text to the end |

## Essential Examples

### Basic usage

```html
<div class="flex w-full flex-col">
  <div class="card bg-base-300 rounded-box grid h-20 place-items-center">
    content
  </div>
  <div class="divider">OR</div>
  <div class="card bg-base-300 rounded-box grid h-20 place-items-center">
    content
  </div>
</div>
```

### With structure

```html
<!-- Vertical divider between side-by-side elements -->
<div class="flex w-full">
  <div class="card bg-base-300 rounded-box grid h-20 flex-1 place-items-center">
    content
  </div>
  <div class="divider divider-vertical">OR</div>
  <div class="card bg-base-300 rounded-box grid h-20 flex-1 place-items-center">
    content
  </div>
</div>
```

## Notes

- **Recommended**: Text content inside the divider element is rendered as a centered label on the divider line
