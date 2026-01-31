# Label

Text label attached to an input or select element, with optional floating animation on focus.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `label` | Component | Styles a `<span>` as a label inside an input or select wrapper |
| `floating-label` | Component | Wrapper that animates the label above the input when focused |

## Essential Examples

### Basic usage

```html
<!-- Label before input -->
<label class="input">
  <span class="label">https://</span>
  <input type="text" placeholder="URL" />
</label>

<!-- Label after input -->
<label class="input">
  <input type="text" placeholder="domain name" />
  <span class="label">.com</span>
</label>
```

### With structure

```html
<!-- Floating label -->
<label class="floating-label">
  <span>Your Email</span>
  <input type="text" placeholder="[email protected]" class="input input-md" />
</label>

<!-- Label with select -->
<label class="select">
  <span class="label">Type</span>
  <select>
    <option>Personal</option>
    <option>Business</option>
  </select>
</label>
```

## Notes

- **Required**: The `label` class must be applied to a `<span>` inside a parent element that has the `input` or `select` class
- **Required**: For `floating-label`, the parent wrapper element receives the `floating-label` class and contains a plain `<span>` (without `label` class) alongside the input
- **Recommended**: Size of the input inside `floating-label` controls the label size (e.g., `input-sm`, `input-lg`)
