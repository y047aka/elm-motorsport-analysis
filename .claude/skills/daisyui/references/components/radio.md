# Radio

Radio button component for single selection from a group. Each set of radio inputs should have unique `name` attributes to avoid conflicts with other sets of radio inputs on the same page.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `radio` | Component | For radio input |
| `radio-neutral` | Color | Neutral color |
| `radio-primary` | Color | Primary color |
| `radio-secondary` | Color | Secondary color |
| `radio-accent` | Color | Accent color |
| `radio-success` | Color | Success color |
| `radio-warning` | Color | Warning color |
| `radio-info` | Color | Info color |
| `radio-error` | Color | Error color |
| `radio-xs` | Size | Extra small size |
| `radio-sm` | Size | Small size |
| `radio-md` | Size | Medium size (default) |
| `radio-lg` | Size | Large size |
| `radio-xl` | Size | Extra large size |

## Key Examples

### Basic radio

```html
<input type="radio" name="radio-1" class="radio" checked="checked" />
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
<input type="radio" name="radio-size" class="radio radio-xl" />
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
