# Toggle

Switch-style checkbox for binary on/off states.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `toggle` | Component | Switch-styled checkbox |
| `toggle-primary` | Color | Primary color |
| `toggle-secondary` | Color | Secondary color |
| `toggle-accent` | Color | Accent color |
| `toggle-neutral` | Color | Neutral color |
| `toggle-success` | Color | Success color |
| `toggle-warning` | Color | Warning color |
| `toggle-info` | Color | Info color |
| `toggle-error` | Color | Error color |
| `toggle-xs` | Size | Extra small |
| `toggle-sm` | Size | Small |
| `toggle-md` | Size | Medium (default) |
| `toggle-lg` | Size | Large |
| `toggle-xl` | Size | Extra large |

## Essential Examples

### Basic usage

```html
<input type="checkbox" class="toggle" />
<input type="checkbox" class="toggle" checked />
```

### With label

```html
<div class="form-control">
  <label class="label cursor-pointer">
    <span class="label-text">Remember me</span>
    <input type="checkbox" class="toggle" />
  </label>
</div>
```

### Label on left

```html
<div class="form-control">
  <label class="label cursor-pointer justify-start gap-4">
    <input type="checkbox" class="toggle toggle-primary" />
    <span class="label-text">Enable notifications</span>
  </label>
</div>
```

### Settings panel

```html
<div class="card bg-base-100 shadow-xl">
  <div class="card-body">
    <h2 class="card-title">Settings</h2>
    <div class="form-control">
      <label class="label cursor-pointer">
        <span class="label-text">Email notifications</span>
        <input type="checkbox" class="toggle toggle-primary" checked />
      </label>
    </div>
    <div class="form-control">
      <label class="label cursor-pointer">
        <span class="label-text">Push notifications</span>
        <input type="checkbox" class="toggle toggle-primary" />
      </label>
    </div>
  </div>
</div>
```

## Notes

- Use `<label class="label cursor-pointer">` for clickable labels
- Disabled: Add `disabled` attribute
