# Radio

Radio button component for single selection from a group.

## Class Reference

| Class | Description |
|-------|-------------|
| `radio` | Base radio class |
| `radio-primary` | Primary color |
| `radio-secondary` | Secondary color |
| `radio-accent` | Accent color |
| `radio-neutral` | Neutral color |
| `radio-info` | Info state color |
| `radio-success` | Success state color |
| `radio-warning` | Warning state color |
| `radio-error` | Error state color |
| `radio-xs` | Extra small size |
| `radio-sm` | Small size |
| `radio-md` | Medium size (default) |
| `radio-lg` | Large size |

## Key Examples

### Basic radio

```html
<input type="radio" name="radio-1" class="radio" checked />
<input type="radio" name="radio-1" class="radio" />
```

### Color variants

```html
<input type="radio" name="radio-2" class="radio radio-primary" checked />
<input type="radio" name="radio-3" class="radio radio-secondary" checked />
<input type="radio" name="radio-4" class="radio radio-accent" checked />
<input type="radio" name="radio-5" class="radio radio-success" checked />
<input type="radio" name="radio-6" class="radio radio-error" checked />
```

### Sizes

```html
<input type="radio" name="radio-size" class="radio radio-xs" />
<input type="radio" name="radio-size" class="radio radio-sm" />
<input type="radio" name="radio-size" class="radio radio-md" />
<input type="radio" name="radio-size" class="radio radio-lg" />
```

### With label (form-control)

```html
<div class="form-control">
  <label class="label cursor-pointer">
    <span class="label-text">Red pill</span>
    <input type="radio" name="radio-pills" class="radio" checked />
  </label>
</div>
<div class="form-control">
  <label class="label cursor-pointer">
    <span class="label-text">Blue pill</span>
    <input type="radio" name="radio-pills" class="radio" />
  </label>
</div>
```

### Label on left

```html
<div class="form-control">
  <label class="label cursor-pointer justify-start gap-2">
    <input type="radio" name="radio-left" class="radio" checked />
    <span class="label-text">Option A</span>
  </label>
</div>
<div class="form-control">
  <label class="label cursor-pointer justify-start gap-2">
    <input type="radio" name="radio-left" class="radio" />
    <span class="label-text">Option B</span>
  </label>
</div>
```

### With description

```html
<div class="form-control">
  <label class="label cursor-pointer">
    <div>
      <span class="label-text font-medium">Standard shipping</span>
      <p class="text-xs text-base-content/60">4-10 business days</p>
    </div>
    <input type="radio" name="shipping" class="radio radio-primary" checked />
  </label>
</div>
<div class="form-control">
  <label class="label cursor-pointer">
    <div>
      <span class="label-text font-medium">Express shipping</span>
      <p class="text-xs text-base-content/60">2-5 business days</p>
    </div>
    <input type="radio" name="shipping" class="radio radio-primary" />
  </label>
</div>
```
