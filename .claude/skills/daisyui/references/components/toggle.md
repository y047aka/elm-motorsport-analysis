# Toggle

Switch/toggle component for binary on/off states.

## Basic Usage

```html
<input type="checkbox" class="toggle" />
```

## Checked State

```html
<input type="checkbox" class="toggle" checked />
```

## Color Variants

```html
<input type="checkbox" class="toggle toggle-primary" checked />
<input type="checkbox" class="toggle toggle-secondary" checked />
<input type="checkbox" class="toggle toggle-accent" checked />
<input type="checkbox" class="toggle toggle-neutral" checked />
```

## State Colors

```html
<input type="checkbox" class="toggle toggle-info" checked />
<input type="checkbox" class="toggle toggle-success" checked />
<input type="checkbox" class="toggle toggle-warning" checked />
<input type="checkbox" class="toggle toggle-error" checked />
```

## Sizes

```html
<input type="checkbox" class="toggle toggle-xs" />
<input type="checkbox" class="toggle toggle-sm" />
<input type="checkbox" class="toggle toggle-md" />
<input type="checkbox" class="toggle toggle-lg" />
```

## Disabled

```html
<input type="checkbox" class="toggle" disabled />
<input type="checkbox" class="toggle" checked disabled />
```

## With Label

```html
<div class="form-control">
  <label class="label cursor-pointer">
    <span class="label-text">Remember me</span>
    <input type="checkbox" class="toggle" />
  </label>
</div>
```

## Label on Left

```html
<div class="form-control">
  <label class="label cursor-pointer justify-start gap-4">
    <input type="checkbox" class="toggle toggle-primary" />
    <span class="label-text">Enable notifications</span>
  </label>
</div>
```

## With Description

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

## Toggle Group

```html
<div class="space-y-2">
  <div class="form-control">
    <label class="label cursor-pointer">
      <span class="label-text">Wi-Fi</span>
      <input type="checkbox" class="toggle toggle-primary" checked />
    </label>
  </div>
  <div class="form-control">
    <label class="label cursor-pointer">
      <span class="label-text">Bluetooth</span>
      <input type="checkbox" class="toggle toggle-primary" checked />
    </label>
  </div>
  <div class="form-control">
    <label class="label cursor-pointer">
      <span class="label-text">Airplane mode</span>
      <input type="checkbox" class="toggle toggle-primary" />
    </label>
  </div>
</div>
```

## In Card

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

## Indeterminate State

```html
<input type="checkbox" class="toggle" id="toggle-indeterminate" />
<script>
  document.getElementById('toggle-indeterminate').indeterminate = true;
</script>
```

## Classes Reference

| Class | Description |
|-------|-------------|
| `toggle` | Base toggle class |
| `toggle-primary` | Primary color |
| `toggle-secondary` | Secondary color |
| `toggle-accent` | Accent color |
| `toggle-neutral` | Neutral color |
| `toggle-info` | Info state color |
| `toggle-success` | Success state color |
| `toggle-warning` | Warning state color |
| `toggle-error` | Error state color |
| `toggle-xs` | Extra small size |
| `toggle-sm` | Small size |
| `toggle-md` | Medium size (default) |
| `toggle-lg` | Large size |
