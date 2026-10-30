# Checkbox

Checkbox input for boolean selections.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `checkbox` | Component | Base checkbox |
| `checkbox-primary` | Color | Primary color |
| `checkbox-secondary` | Color | Secondary color |
| `checkbox-accent` | Color | Accent color |
| `checkbox-neutral` | Color | Neutral color |
| `checkbox-success` | Color | Success color |
| `checkbox-warning` | Color | Warning color |
| `checkbox-info` | Color | Info color |
| `checkbox-error` | Color | Error color |
| `checkbox-xs` | Size | Extra small |
| `checkbox-sm` | Size | Small |
| `checkbox-md` | Size | Medium (default) |
| `checkbox-lg` | Size | Large |
| `checkbox-xl` | Size | Extra large |

## Essential Examples

### Basic usage

```html
<input type="checkbox" class="checkbox" />
<input type="checkbox" class="checkbox" checked />
```

### With label

```html
<label class="label">
  <input type="checkbox" checked class="checkbox" />
  Remember me
</label>
```

### Interactive

```html
<!-- Indeterminate state -->
<input type="checkbox" class="checkbox" id="indeterminate" />
<script>
  document.getElementById('indeterminate').indeterminate = true;
</script>
```

## Notes

- **Required**: Indeterminate state must be set via JavaScript `element.indeterminate = true`
