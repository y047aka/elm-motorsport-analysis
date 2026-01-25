# Toggle

Switch/toggle component for binary on/off states.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `toggle` | Component | Toggle base class |
| `toggle-primary` | Color | Primary color |
| `toggle-secondary` | Color | Secondary color |
| `toggle-accent` | Color | Accent color |
| `toggle-neutral` | Color | Neutral color |
| `toggle-info` | Color | Info state color |
| `toggle-success` | Color | Success state color |
| `toggle-warning` | Color | Warning state color |
| `toggle-error` | Color | Error state color |
| `toggle-xs` | Size | Extra small size |
| `toggle-sm` | Size | Small size |
| `toggle-md` | Size | Medium size (default) |
| `toggle-lg` | Size | Large size |

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
<input type="checkbox" class="toggle toggle-error" checked />
```

### Toggle sizes

```html
<input type="checkbox" class="toggle toggle-xs" />
<input type="checkbox" class="toggle toggle-sm" />
<input type="checkbox" class="toggle toggle-md" />
<input type="checkbox" class="toggle toggle-lg" />
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
