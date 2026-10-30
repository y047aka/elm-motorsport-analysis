# Theme Controller

CSS-only theme switching component that changes the page theme based on checked input state.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `theme-controller` | Component | Enables theme switching on checkbox or radio inputs |

## Essential Examples

### Basic usage

```html
<!-- Toggle between two themes -->
<input type="checkbox" value="synthwave" class="toggle theme-controller" />

<!-- Checkbox variant -->
<input type="checkbox" value="synthwave" class="checkbox theme-controller" />

<!-- Radio for multiple theme options -->
<input type="radio" name="theme-radios" class="radio theme-controller" value="light" checked />
<input type="radio" name="theme-radios" class="radio theme-controller" value="dark" />
<input type="radio" name="theme-radios" class="radio theme-controller" value="retro" />
```

### With structure

```html
<!-- Toggle with labels -->
<label class="flex cursor-pointer gap-2">
  <span class="label-text">Light</span>
  <input type="checkbox" value="synthwave" class="toggle theme-controller" />
  <span class="label-text">Synthwave</span>
</label>
```

## Notes

- **Required**: The input's `value` attribute must match a valid daisyUI theme name (e.g., `light`, `dark`, `synthwave`, `retro`)
- **Required**: For radio inputs, all theme-controller radios must share the same `name` attribute
- **Recommended**: Works with `toggle`, `checkbox`, `radio`, and `swap` daisyUI components as the input wrapper
