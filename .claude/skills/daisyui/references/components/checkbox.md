# Checkbox

Checkbox input component for boolean selections.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `checkbox` | Component | Base checkbox component |
| `checkbox-primary` | Color | Primary color style |
| `checkbox-secondary` | Color | Secondary color style |
| `checkbox-accent` | Color | Accent color style |
| `checkbox-neutral` | Color | Neutral color style |
| `checkbox-success` | Color | Success color style |
| `checkbox-warning` | Color | Warning color style |
| `checkbox-info` | Color | Info color style |
| `checkbox-error` | Color | Error color style |
| `checkbox-xs` | Size | Extra small size |
| `checkbox-sm` | Size | Small size |
| `checkbox-md` | Size | Medium size (default) |
| `checkbox-lg` | Size | Large size |
| `checkbox-xl` | Size | Extra large size |

## Key Examples

### Basic checkbox

```html
<input type="checkbox" class="checkbox" />
<input type="checkbox" class="checkbox" checked />
```

### With fieldset and label

```html
<fieldset class="fieldset bg-base-100 border-base-300 rounded-box w-64 border p-4">
  <legend class="fieldset-legend">Login options</legend>
  <label class="label">
    <input type="checkbox" checked class="checkbox" />
    Remember me
  </label>
</fieldset>
```

### Sizes

```html
<input type="checkbox" class="checkbox checkbox-xs" />
<input type="checkbox" class="checkbox checkbox-sm" />
<input type="checkbox" class="checkbox checkbox-md" />
<input type="checkbox" class="checkbox checkbox-lg" />
<input type="checkbox" class="checkbox checkbox-xl" />
```

### Color variants

```html
<input type="checkbox" class="checkbox checkbox-primary" checked />
<input type="checkbox" class="checkbox checkbox-secondary" checked />
<input type="checkbox" class="checkbox checkbox-accent" checked />
<input type="checkbox" class="checkbox checkbox-success" checked />
<input type="checkbox" class="checkbox checkbox-error" checked />
```

### Disabled

```html
<input type="checkbox" class="checkbox" disabled />
<input type="checkbox" class="checkbox" checked disabled />
```

### Indeterminate state

```html
<input type="checkbox" class="checkbox" id="indeterminate" />
<script>
  document.getElementById('indeterminate').indeterminate = true;
</script>
```

### Custom colors

```html
<input type="checkbox" checked
  class="checkbox border-indigo-600 bg-indigo-500 checked:border-orange-500 checked:bg-orange-400" />
```
