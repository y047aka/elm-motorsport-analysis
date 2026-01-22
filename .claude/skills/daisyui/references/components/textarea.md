# Textarea

Multi-line text input component.

## Basic Usage

```html
<textarea class="textarea" placeholder="Bio"></textarea>
```

## With Border

```html
<textarea class="textarea textarea-bordered" placeholder="Bio"></textarea>
```

## Ghost (No Border)

```html
<textarea class="textarea textarea-ghost" placeholder="Bio"></textarea>
```

## Color Variants

```html
<textarea class="textarea textarea-bordered textarea-primary" placeholder="Primary"></textarea>
<textarea class="textarea textarea-bordered textarea-secondary" placeholder="Secondary"></textarea>
<textarea class="textarea textarea-bordered textarea-accent" placeholder="Accent"></textarea>
<textarea class="textarea textarea-bordered textarea-neutral" placeholder="Neutral"></textarea>
```

## State Colors

```html
<textarea class="textarea textarea-bordered textarea-info" placeholder="Info"></textarea>
<textarea class="textarea textarea-bordered textarea-success" placeholder="Success"></textarea>
<textarea class="textarea textarea-bordered textarea-warning" placeholder="Warning"></textarea>
<textarea class="textarea textarea-bordered textarea-error" placeholder="Error"></textarea>
```

## Sizes

```html
<textarea class="textarea textarea-bordered textarea-xs" placeholder="Extra small"></textarea>
<textarea class="textarea textarea-bordered textarea-sm" placeholder="Small"></textarea>
<textarea class="textarea textarea-bordered textarea-md" placeholder="Medium"></textarea>
<textarea class="textarea textarea-bordered textarea-lg" placeholder="Large"></textarea>
```

## Disabled

```html
<textarea class="textarea textarea-bordered" placeholder="Disabled" disabled></textarea>
```

## With Label

```html
<label class="form-control">
  <div class="label">
    <span class="label-text">Your bio</span>
    <span class="label-text-alt">Alt label</span>
  </div>
  <textarea class="textarea textarea-bordered h-24" placeholder="Bio"></textarea>
  <div class="label">
    <span class="label-text-alt">Your bio will appear on your profile</span>
  </div>
</label>
```

## Full Width

```html
<textarea class="textarea textarea-bordered w-full" placeholder="Full width"></textarea>
```

## Fixed Height

```html
<textarea class="textarea textarea-bordered h-24" placeholder="Fixed height"></textarea>
<textarea class="textarea textarea-bordered h-32" placeholder="Taller"></textarea>
<textarea class="textarea textarea-bordered h-48" placeholder="Even taller"></textarea>
```

## Resizable

```html
<!-- Vertical resize only (default browser behavior) -->
<textarea class="textarea textarea-bordered resize-y" placeholder="Resize vertically"></textarea>

<!-- Both directions -->
<textarea class="textarea textarea-bordered resize" placeholder="Resize both"></textarea>

<!-- No resize -->
<textarea class="textarea textarea-bordered resize-none" placeholder="No resize"></textarea>
```

## With Character Count

```html
<label class="form-control">
  <div class="label">
    <span class="label-text">Message</span>
  </div>
  <textarea class="textarea textarea-bordered h-24" placeholder="Your message" maxlength="200"></textarea>
  <div class="label">
    <span class="label-text-alt">0/200</span>
  </div>
</label>
```

## Classes Reference

| Class | Description |
|-------|-------------|
| `textarea` | Base textarea class |
| `textarea-bordered` | Adds border |
| `textarea-ghost` | No border, transparent |
| `textarea-primary` | Primary color focus |
| `textarea-secondary` | Secondary color focus |
| `textarea-accent` | Accent color focus |
| `textarea-neutral` | Neutral color focus |
| `textarea-info` | Info state color |
| `textarea-success` | Success state color |
| `textarea-warning` | Warning state color |
| `textarea-error` | Error state color |
| `textarea-xs` | Extra small size |
| `textarea-sm` | Small size |
| `textarea-md` | Medium size (default) |
| `textarea-lg` | Large size |
