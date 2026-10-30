# Fieldset

Container for grouping related form elements with a legend title and helper text labels.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `fieldset` | Component | Wrapper container for grouped form elements |
| `label` | Component | Text label for inputs (generic component, not fieldset-specific) |
| `fieldset-legend` | Part | Title or heading for the fieldset group |

## Essential Examples

### Basic usage

```html
<fieldset class="fieldset">
  <legend class="fieldset-legend">Page title</legend>
  <input type="text" class="input" placeholder="My awesome page" />
  <p class="label">You can edit page title later on from settings</p>
</fieldset>
```

### With structure

```html
<!-- Styled fieldset with border and multiple inputs -->
<fieldset class="fieldset bg-base-200 border border-base-300 rounded-box w-xs p-4">
  <legend class="fieldset-legend">Account Details</legend>

  <label class="label">Email</label>
  <input type="email" class="input" placeholder="you@example.com" />

  <label class="label">Password</label>
  <input type="password" class="input" placeholder="••••••••" />

  <p class="label">Must be at least 8 characters</p>
</fieldset>
```

## Notes

- **Required**: `fieldset-legend` must be applied to a `<legend>` element inside a `<fieldset>` element
- **Recommended**: Use `<p class="label">` for helper text below inputs
- **Recommended**: Combine with the `join` component to group inputs and buttons horizontally
