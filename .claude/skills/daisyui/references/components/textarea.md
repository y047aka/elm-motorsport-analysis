# Textarea

Multi-line text input component.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `textarea` | Component | Base `<textarea>` element |
| `textarea-ghost` | Style | Borderless variant |
| `textarea-neutral` | Color | Neutral color |
| `textarea-primary` | Color | Primary color |
| `textarea-secondary` | Color | Secondary color |
| `textarea-accent` | Color | Accent color |
| `textarea-info` | Color | Info color |
| `textarea-success` | Color | Success color |
| `textarea-warning` | Color | Warning color |
| `textarea-error` | Color | Error color |
| `textarea-xs` | Size | Extra small |
| `textarea-sm` | Size | Small |
| `textarea-md` | Size | Medium (default) |
| `textarea-lg` | Size | Large |
| `textarea-xl` | Size | Extra large |

## Essential Examples

### Basic usage

```html
<textarea class="textarea" placeholder="Bio"></textarea>
```

### With structure

```html
<!-- With label and helper text -->
<label class="form-control">
  <div class="label">
    <span class="label-text">Your bio</span>
  </div>
  <textarea class="textarea h-24" placeholder="Bio"></textarea>
  <div class="label">
    <span class="label-text-alt">Your bio will appear on your profile</span>
  </div>
</label>
```

### Fixed height

```html
<textarea class="textarea h-24" placeholder="Fixed height"></textarea>
<textarea class="textarea h-32" placeholder="Taller"></textarea>
```

## Notes

- **Recommended**: Control height with Tailwind classes (`h-24`, `h-32`, etc.)
- **Recommended**: Use Tailwind resize utilities: `resize-y` (vertical only), `resize-none` (disabled), `resize` (both directions)
- **Recommended**: Wrap with `<label class="form-control">` for labels and helper text
