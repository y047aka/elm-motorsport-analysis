# Radio

Radio button component for single selection from a group.

## Basic Usage

```html
<input type="radio" name="radio-1" class="radio" checked />
<input type="radio" name="radio-1" class="radio" />
```

## Color Variants

```html
<input type="radio" name="radio-2" class="radio radio-primary" checked />
<input type="radio" name="radio-3" class="radio radio-secondary" checked />
<input type="radio" name="radio-4" class="radio radio-accent" checked />
<input type="radio" name="radio-5" class="radio radio-neutral" checked />
```

## State Colors

```html
<input type="radio" name="radio-6" class="radio radio-info" checked />
<input type="radio" name="radio-7" class="radio radio-success" checked />
<input type="radio" name="radio-8" class="radio radio-warning" checked />
<input type="radio" name="radio-9" class="radio radio-error" checked />
```

## Sizes

```html
<input type="radio" name="radio-10" class="radio radio-xs" />
<input type="radio" name="radio-10" class="radio radio-sm" />
<input type="radio" name="radio-10" class="radio radio-md" />
<input type="radio" name="radio-10" class="radio radio-lg" />
```

## Disabled

```html
<input type="radio" name="radio-disabled" class="radio" disabled />
<input type="radio" name="radio-disabled" class="radio" checked disabled />
```

## With Label

```html
<div class="form-control">
  <label class="label cursor-pointer">
    <span class="label-text">Red pill</span>
    <input type="radio" name="radio-example" class="radio" checked />
  </label>
</div>
<div class="form-control">
  <label class="label cursor-pointer">
    <span class="label-text">Blue pill</span>
    <input type="radio" name="radio-example" class="radio" />
  </label>
</div>
```

## Label on Left

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

## Radio Group with Description

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

## In Card

```html
<div class="card bg-base-100 shadow-xl">
  <div class="card-body">
    <h2 class="card-title">Select Plan</h2>
    <div class="form-control">
      <label class="label cursor-pointer">
        <span class="label-text">Basic - $9/mo</span>
        <input type="radio" name="plan" class="radio radio-primary" checked />
      </label>
    </div>
    <div class="form-control">
      <label class="label cursor-pointer">
        <span class="label-text">Pro - $19/mo</span>
        <input type="radio" name="plan" class="radio radio-primary" />
      </label>
    </div>
    <div class="form-control">
      <label class="label cursor-pointer">
        <span class="label-text">Enterprise - $49/mo</span>
        <input type="radio" name="plan" class="radio radio-primary" />
      </label>
    </div>
  </div>
</div>
```

## Horizontal Radio Group

```html
<div class="flex gap-4">
  <label class="label cursor-pointer gap-2">
    <input type="radio" name="radio-horizontal" class="radio radio-sm" checked />
    <span class="label-text">Yes</span>
  </label>
  <label class="label cursor-pointer gap-2">
    <input type="radio" name="radio-horizontal" class="radio radio-sm" />
    <span class="label-text">No</span>
  </label>
  <label class="label cursor-pointer gap-2">
    <input type="radio" name="radio-horizontal" class="radio radio-sm" />
    <span class="label-text">Maybe</span>
  </label>
</div>
```

## Classes Reference

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
