# File Input

An input field for uploading files with styled file selection button.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `file-input` | Component | Base class for file input styling |
| `file-input-ghost` | Style | Ghost/transparent appearance variant |
| `file-input-neutral` | Color | Neutral color |
| `file-input-primary` | Color | Primary color |
| `file-input-secondary` | Color | Secondary color |
| `file-input-accent` | Color | Accent color |
| `file-input-info` | Color | Info color |
| `file-input-success` | Color | Success color |
| `file-input-warning` | Color | Warning color |
| `file-input-error` | Color | Error color |
| `file-input-xs` | Size | Extra small |
| `file-input-sm` | Size | Small |
| `file-input-md` | Size | Medium (default) |
| `file-input-lg` | Size | Large |
| `file-input-xl` | Size | Extra large |

## Essential Examples

### Basic usage

```html
<input type="file" class="file-input" />
```

### With structure

```html
<!-- With label and helper text inside a fieldset -->
<fieldset class="fieldset">
  <legend class="fieldset-legend">Pick a file</legend>
  <input type="file" class="file-input" />
  <p class="label">Max size 2MB</p>
</fieldset>
```

## Notes

- **Required**: Must be applied to `<input type="file">` element
- **Recommended**: Wrap in a `fieldset` with `fieldset-legend` for accessible labeling
