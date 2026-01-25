# Textarea

Multi-line text input component for forms.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `textarea` | Component | Base class for `<textarea>` elements |
| `textarea-ghost` | Style | Applies ghost styling (no background) |
| `textarea-neutral` | Color | Neutral color variant |
| `textarea-primary` | Color | Primary color variant |
| `textarea-secondary` | Color | Secondary color variant |
| `textarea-accent` | Color | Accent color variant |
| `textarea-info` | Color | Info color variant |
| `textarea-success` | Color | Success color variant |
| `textarea-warning` | Color | Warning color variant |
| `textarea-error` | Color | Error color variant |
| `textarea-xs` | Size | Extra small sizing |
| `textarea-sm` | Size | Small sizing |
| `textarea-md` | Size | Medium sizing (default) |
| `textarea-lg` | Size | Large sizing |
| `textarea-xl` | Size | Extra large sizing |

## Key Examples

### Basic textarea

```html
<textarea class="textarea" placeholder="Bio"></textarea>
```

### Ghost style

```html
<textarea class="textarea textarea-ghost" placeholder="Bio"></textarea>
```

### With fieldset and labels

```html
<fieldset class="fieldset">
  <legend class="fieldset-legend">Your bio</legend>
  <textarea class="textarea h-24" placeholder="Bio"></textarea>
  <div class="label">Optional</div>
</fieldset>
```

### Textarea colors

```html
<textarea class="textarea textarea-primary" placeholder="Primary"></textarea>
<textarea class="textarea textarea-secondary" placeholder="Secondary"></textarea>
<textarea class="textarea textarea-accent" placeholder="Accent"></textarea>
<textarea class="textarea textarea-neutral" placeholder="Neutral"></textarea>
<textarea class="textarea textarea-info" placeholder="Info"></textarea>
<textarea class="textarea textarea-success" placeholder="Success"></textarea>
<textarea class="textarea textarea-warning" placeholder="Warning"></textarea>
<textarea class="textarea textarea-error" placeholder="Error"></textarea>
```

### Textarea sizes

```html
<textarea class="textarea textarea-xs" placeholder="Extra small"></textarea>
<textarea class="textarea textarea-sm" placeholder="Small"></textarea>
<textarea class="textarea textarea-md" placeholder="Medium"></textarea>
<textarea class="textarea textarea-lg" placeholder="Large"></textarea>
<textarea class="textarea textarea-xl" placeholder="Extra large"></textarea>
```

### Disabled state

```html
<textarea class="textarea" placeholder="Bio" disabled></textarea>
```

### With fixed height

```html
<textarea class="textarea h-24" placeholder="Fixed height"></textarea>
<textarea class="textarea h-32" placeholder="Taller"></textarea>
```

### Resizable textarea

```html
<!-- Vertical resize only (default) -->
<textarea class="textarea resize-y" placeholder="Resize vertically"></textarea>

<!-- Both directions -->
<textarea class="textarea resize" placeholder="Resize both"></textarea>

<!-- No resize -->
<textarea class="textarea resize-none" placeholder="No resize"></textarea>
```

### With label using form-control

```html
<label class="form-control">
  <div class="label">
    <span class="label-text">Your bio</span>
    <span class="label-text-alt">Alt label</span>
  </div>
  <textarea class="textarea h-24" placeholder="Bio"></textarea>
  <div class="label">
    <span class="label-text-alt">Your bio will appear on your profile</span>
  </div>
</label>
```

### With character count

```html
<label class="form-control">
  <div class="label">
    <span class="label-text">Message</span>
  </div>
  <textarea class="textarea h-24" placeholder="Your message" maxlength="200"></textarea>
  <div class="label">
    <span class="label-text-alt">0/200</span>
  </div>
</label>
```
