# Textarea

Multi-line text input component.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `textarea` | Component | Textarea base class |
| `textarea-bordered` | Style | Adds border |
| `textarea-ghost` | Style | No border, transparent |
| `textarea-primary` | Color | Primary color focus |
| `textarea-secondary` | Color | Secondary color focus |
| `textarea-accent` | Color | Accent color focus |
| `textarea-neutral` | Color | Neutral color focus |
| `textarea-info` | Color | Info state color |
| `textarea-success` | Color | Success state color |
| `textarea-warning` | Color | Warning state color |
| `textarea-error` | Color | Error state color |
| `textarea-xs` | Size | Extra small size |
| `textarea-sm` | Size | Small size |
| `textarea-md` | Size | Medium size (default) |
| `textarea-lg` | Size | Large size |

## Key Examples

### Basic textarea

```html
<textarea class="textarea" placeholder="Bio"></textarea>
<textarea class="textarea textarea-bordered" placeholder="Bio"></textarea>
<textarea class="textarea textarea-ghost" placeholder="Bio"></textarea>
```

### Textarea colors

```html
<textarea class="textarea textarea-bordered textarea-primary" placeholder="Primary"></textarea>
<textarea class="textarea textarea-bordered textarea-secondary" placeholder="Secondary"></textarea>
<textarea class="textarea textarea-bordered textarea-accent" placeholder="Accent"></textarea>
<textarea class="textarea textarea-bordered textarea-success" placeholder="Success"></textarea>
<textarea class="textarea textarea-bordered textarea-warning" placeholder="Warning"></textarea>
<textarea class="textarea textarea-bordered textarea-error" placeholder="Error"></textarea>
```

### Textarea sizes

```html
<textarea class="textarea textarea-bordered textarea-xs" placeholder="Extra small"></textarea>
<textarea class="textarea textarea-bordered textarea-sm" placeholder="Small"></textarea>
<textarea class="textarea textarea-bordered textarea-md" placeholder="Medium"></textarea>
<textarea class="textarea textarea-bordered textarea-lg" placeholder="Large"></textarea>
```

### Textarea with label

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

### Textarea with fixed height

```html
<textarea class="textarea textarea-bordered h-24" placeholder="Fixed height"></textarea>
<textarea class="textarea textarea-bordered h-32" placeholder="Taller"></textarea>
```

### Resizable textarea

```html
<!-- Vertical resize only (default) -->
<textarea class="textarea textarea-bordered resize-y" placeholder="Resize vertically"></textarea>

<!-- Both directions -->
<textarea class="textarea textarea-bordered resize" placeholder="Resize both"></textarea>

<!-- No resize -->
<textarea class="textarea textarea-bordered resize-none" placeholder="No resize"></textarea>
```

### Textarea with character count

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
