# Checkbox

Checkbox input component for boolean selections.

## Basic Usage

```html
<input type="checkbox" class="checkbox" />
```

## Checked State

```html
<input type="checkbox" class="checkbox" checked />
```

## Color Variants

```html
<input type="checkbox" class="checkbox checkbox-primary" checked />
<input type="checkbox" class="checkbox checkbox-secondary" checked />
<input type="checkbox" class="checkbox checkbox-accent" checked />
<input type="checkbox" class="checkbox checkbox-neutral" checked />
```

## State Colors

```html
<input type="checkbox" class="checkbox checkbox-info" checked />
<input type="checkbox" class="checkbox checkbox-success" checked />
<input type="checkbox" class="checkbox checkbox-warning" checked />
<input type="checkbox" class="checkbox checkbox-error" checked />
```

## Sizes

```html
<input type="checkbox" class="checkbox checkbox-xs" />
<input type="checkbox" class="checkbox checkbox-sm" />
<input type="checkbox" class="checkbox checkbox-md" />
<input type="checkbox" class="checkbox checkbox-lg" />
```

## Disabled

```html
<input type="checkbox" class="checkbox" disabled />
<input type="checkbox" class="checkbox" checked disabled />
```

## Indeterminate State

```html
<input type="checkbox" class="checkbox" id="indeterminate" />
<script>
  document.getElementById('indeterminate').indeterminate = true;
</script>
```

## With Label

```html
<div class="form-control">
  <label class="label cursor-pointer">
    <span class="label-text">Remember me</span>
    <input type="checkbox" class="checkbox" />
  </label>
</div>
```

## Label on Right

```html
<div class="form-control">
  <label class="label cursor-pointer justify-start gap-2">
    <input type="checkbox" class="checkbox" />
    <span class="label-text">Remember me</span>
  </label>
</div>
```

## With Description

```html
<div class="form-control">
  <label class="label cursor-pointer">
    <div>
      <span class="label-text">Enable notifications</span>
      <p class="text-xs text-base-content/60">You will receive email notifications</p>
    </div>
    <input type="checkbox" class="checkbox checkbox-primary" />
  </label>
</div>
```

## Checkbox Group

```html
<div class="form-control">
  <label class="label cursor-pointer">
    <span class="label-text">Option 1</span>
    <input type="checkbox" class="checkbox" />
  </label>
</div>
<div class="form-control">
  <label class="label cursor-pointer">
    <span class="label-text">Option 2</span>
    <input type="checkbox" class="checkbox" />
  </label>
</div>
<div class="form-control">
  <label class="label cursor-pointer">
    <span class="label-text">Option 3</span>
    <input type="checkbox" class="checkbox" />
  </label>
</div>
```

## In Card

```html
<div class="card bg-base-100 shadow-xl">
  <div class="card-body">
    <h2 class="card-title">Settings</h2>
    <div class="form-control">
      <label class="label cursor-pointer">
        <span class="label-text">Dark mode</span>
        <input type="checkbox" class="checkbox checkbox-primary" />
      </label>
    </div>
    <div class="form-control">
      <label class="label cursor-pointer">
        <span class="label-text">Notifications</span>
        <input type="checkbox" class="checkbox checkbox-primary" checked />
      </label>
    </div>
  </div>
</div>
```

## Classes Reference

| Class | Description |
|-------|-------------|
| `checkbox` | Base checkbox class |
| `checkbox-primary` | Primary color |
| `checkbox-secondary` | Secondary color |
| `checkbox-accent` | Accent color |
| `checkbox-neutral` | Neutral color |
| `checkbox-info` | Info state color |
| `checkbox-success` | Success state color |
| `checkbox-warning` | Warning state color |
| `checkbox-error` | Error state color |
| `checkbox-xs` | Extra small size |
| `checkbox-sm` | Small size |
| `checkbox-md` | Medium size (default) |
| `checkbox-lg` | Large size |
