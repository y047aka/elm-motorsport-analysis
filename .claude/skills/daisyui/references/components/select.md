# Select

Dropdown selection component for choosing from a list of options.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `select` | Component | Base `<select>` element |
| `select-ghost` | Style | Borderless variant |
| `select-neutral` | Color | Neutral color |
| `select-primary` | Color | Primary color |
| `select-secondary` | Color | Secondary color |
| `select-accent` | Color | Accent color |
| `select-info` | Color | Info color |
| `select-success` | Color | Success color |
| `select-warning` | Color | Warning color |
| `select-error` | Color | Error color |
| `select-xs` | Size | Extra small |
| `select-sm` | Size | Small |
| `select-md` | Size | Medium (default) |
| `select-lg` | Size | Large |
| `select-xl` | Size | Extra large |

## Essential Examples

### Basic usage

```html
<select class="select w-full max-w-xs">
  <option disabled selected>Pick one</option>
  <option>Option 1</option>
  <option>Option 2</option>
  <option>Option 3</option>
</select>
```

### With structure

```html
<!-- With label and helper text -->
<label class="form-control w-full max-w-xs">
  <div class="label">
    <span class="label-text">Pick the best fantasy franchise</span>
  </div>
  <select class="select">
    <option disabled selected>Pick one</option>
    <option>Star Wars</option>
    <option>Harry Potter</option>
    <option>Lord of the Rings</option>
  </select>
  <div class="label">
    <span class="label-text-alt">Choose wisely</span>
  </div>
</label>
```

### With option groups

```html
<select class="select w-full max-w-xs">
  <option disabled selected>Select a car</option>
  <optgroup label="Swedish Cars">
    <option>Volvo</option>
    <option>Saab</option>
  </optgroup>
  <optgroup label="German Cars">
    <option>Mercedes</option>
    <option>Audi</option>
  </optgroup>
</select>
```

## Notes

- **Recommended**: Wrap with `<label class="form-control">` for labels and helper text
