# Radio

Radio button for single selection from a group.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `radio` | Component | Base radio input |
| `radio-neutral` | Color | Neutral color |
| `radio-primary` | Color | Primary color |
| `radio-secondary` | Color | Secondary color |
| `radio-accent` | Color | Accent color |
| `radio-success` | Color | Success color |
| `radio-warning` | Color | Warning color |
| `radio-info` | Color | Info color |
| `radio-error` | Color | Error color |
| `radio-xs` | Size | Extra small |
| `radio-sm` | Size | Small |
| `radio-md` | Size | Medium (default) |
| `radio-lg` | Size | Large |
| `radio-xl` | Size | Extra large |

## Essential Examples

### Basic usage

```html
<input type="radio" name="radio-1" class="radio" checked />
<input type="radio" name="radio-1" class="radio" />
```

### With labels

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
```

## Notes

- **Recommended**: Wrap with `<label class="label cursor-pointer">` for clickable labels
