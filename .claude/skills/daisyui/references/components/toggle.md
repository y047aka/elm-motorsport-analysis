# Toggle

Checkbox component styled to look like a switch button for binary on/off states.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `toggle` | Component | Checkbox that is styled to look like a switch button |
| `toggle-primary` | Color | Applies primary color styling |
| `toggle-secondary` | Color | Applies secondary color styling |
| `toggle-accent` | Color | Applies accent color styling |
| `toggle-neutral` | Color | Applies neutral color styling |
| `toggle-success` | Color | Applies success color styling |
| `toggle-warning` | Color | Applies warning color styling |
| `toggle-info` | Color | Applies info color styling |
| `toggle-error` | Color | Applies error color styling |
| `toggle-xs` | Size | Extra small variant |
| `toggle-sm` | Size | Small variant |
| `toggle-md` | Size | Medium size (default) |
| `toggle-lg` | Size | Large variant |
| `toggle-xl` | Size | Extra large variant |

## Key Examples

### Basic toggle

```html
<input type="checkbox" class="toggle" />
<input type="checkbox" class="toggle" checked />
```

### Toggle colors

```html
<input type="checkbox" class="toggle toggle-primary" checked />
<input type="checkbox" class="toggle toggle-secondary" checked />
<input type="checkbox" class="toggle toggle-accent" checked />
<input type="checkbox" class="toggle toggle-success" checked />
<input type="checkbox" class="toggle toggle-warning" checked />
<input type="checkbox" class="toggle toggle-info" checked />
<input type="checkbox" class="toggle toggle-error" checked />
```

### Toggle sizes

```html
<input type="checkbox" class="toggle toggle-xs" checked />
<input type="checkbox" class="toggle toggle-sm" checked />
<input type="checkbox" class="toggle toggle-md" checked />
<input type="checkbox" class="toggle toggle-lg" checked />
<input type="checkbox" class="toggle toggle-xl" checked />
```

### Toggle with label

```html
<div class="form-control">
  <label class="label cursor-pointer">
    <span class="label-text">Remember me</span>
    <input type="checkbox" class="toggle" />
  </label>
</div>
```

### Toggle with label on left

```html
<div class="form-control">
  <label class="label cursor-pointer justify-start gap-4">
    <input type="checkbox" class="toggle toggle-primary" />
    <span class="label-text">Enable notifications</span>
  </label>
</div>
```

### Toggle with description

```html
<div class="form-control w-full">
  <label class="label cursor-pointer">
    <div>
      <span class="label-text font-medium">Dark mode</span>
      <p class="text-xs text-base-content/60">Enable dark theme</p>
    </div>
    <input type="checkbox" class="toggle toggle-primary" />
  </label>
</div>
```

### Toggle with fieldset

```html
<fieldset class="fieldset">
  <legend class="fieldset-legend">Login options</legend>
  <label class="label">
    <input type="checkbox" class="toggle" checked />
    Remember me
  </label>
</fieldset>
```

### Toggle group in card

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
    <div class="form-control">
      <label class="label cursor-pointer">
        <span class="label-text">SMS notifications</span>
        <input type="checkbox" class="toggle toggle-primary" />
      </label>
    </div>
  </div>
</div>
```

### Toggle with custom colors

```html
<input type="checkbox" class="toggle border-indigo-600 bg-indigo-500 
  checked:border-orange-500 checked:bg-orange-400" checked />
```
