# Validator

Form input styling that automatically reflects validation state using native HTML5 validation.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `validator` | Component | Changes input color to error or success based on native validation state |
| `validator-hint` | Part | Hint text shown below input when validation fails (must be a sibling after a `validator` element) |

## Essential Examples

### Basic usage

```html
<input class="input validator" type="email" placeholder="Email" required />
<div class="validator-hint">Enter a valid email address</div>
```

### With structure

```html
<!-- Wrap in a container to isolate hint visibility per field -->
<fieldset>
  <label class="label">
    <span class="label-text">Email</span>
  </label>
  <input class="input validator" type="email" placeholder="you@example.com" required />
  <div class="validator-hint">Enter a valid email address</div>
</fieldset>

<fieldset>
  <label class="label">
    <span class="label-text">Password</span>
  </label>
  <input class="input validator" type="password" placeholder="Password" required minlength="8" />
  <div class="validator-hint">Password must be at least 8 characters</div>
</fieldset>

<!-- With select element -->
<fieldset>
  <label class="label">
    <span class="label-text">Choose an option</span>
  </label>
  <select class="select validator" required>
    <option disabled value="">Select...</option>
    <option value="a">Option A</option>
    <option value="b">Option B</option>
  </select>
  <div class="validator-hint">Please select an option</div>
</fieldset>
```

## Notes

- **Required**: `validator-hint` must be a sibling element placed after a `validator` input to show/hide based on that input's state
- **Required**: Wrap form fields in containers (e.g., `<fieldset>`) to isolate hint visibility per field; otherwise a hint may become visible due to any preceding invalid sibling
- **Recommended**: The `validator-hint` element occupies space even when hidden to prevent layout shifts; add the `hidden` class if you prefer it to only appear on validation failure
- **Recommended**: Works with all standard HTML5 validation attributes (`required`, `minlength`, `maxlength`, `pattern`, `min`, `max`, `type`)
