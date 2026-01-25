# Checkbox

Checkbox input component for boolean selections.

## Class Reference

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

## Key Examples

### Basic checkbox

```html
<input type="checkbox" class="checkbox" />
<input type="checkbox" class="checkbox" checked />
```

### Color variants

```html
<input type="checkbox" class="checkbox checkbox-primary" checked />
<input type="checkbox" class="checkbox checkbox-secondary" checked />
<input type="checkbox" class="checkbox checkbox-accent" checked />
<input type="checkbox" class="checkbox checkbox-success" checked />
<input type="checkbox" class="checkbox checkbox-error" checked />
```

### Sizes

```html
<input type="checkbox" class="checkbox checkbox-xs" />
<input type="checkbox" class="checkbox checkbox-sm" />
<input type="checkbox" class="checkbox checkbox-md" />
<input type="checkbox" class="checkbox checkbox-lg" />
```

### Disabled

```html
<input type="checkbox" class="checkbox" disabled />
<input type="checkbox" class="checkbox" checked disabled />
```

### With label (form-control)

```html
<div class="form-control">
  <label class="label cursor-pointer">
    <span class="label-text">Remember me</span>
    <input type="checkbox" class="checkbox" />
  </label>
</div>

<!-- Label on left -->
<div class="form-control">
  <label class="label cursor-pointer justify-start gap-2">
    <input type="checkbox" class="checkbox" />
    <span class="label-text">Remember me</span>
  </label>
</div>
```

### Indeterminate state

```html
<input type="checkbox" class="checkbox" id="indeterminate" />
<script>
  document.getElementById('indeterminate').indeterminate = true;
</script>
```
