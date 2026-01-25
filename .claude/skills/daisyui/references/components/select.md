# Select

Dropdown selection component for choosing from a list of options.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `select` | Component | Core styling for `<select>` elements |
| `select-ghost` | Style | "ghost style" variant without background |
| `select-neutral` | Color | Neutral color variant |
| `select-primary` | Color | Primary color variant |
| `select-secondary` | Color | Secondary color variant |
| `select-accent` | Color | Accent color variant |
| `select-info` | Color | Info color variant |
| `select-success` | Color | Success color variant |
| `select-warning` | Color | Warning color variant |
| `select-error` | Color | Error color variant |
| `select-xs` | Size | Extra small sizing |
| `select-sm` | Size | Small sizing |
| `select-md` | Size | Medium sizing (default) |
| `select-lg` | Size | Large sizing |
| `select-xl` | Size | Extra large sizing |

## Key Examples

### Basic select

```html
<select class="select w-full max-w-xs">
  <option disabled selected>Pick one</option>
  <option>Option 1</option>
  <option>Option 2</option>
  <option>Option 3</option>
</select>
```

### Select styles

```html
<select class="select select-ghost">
  <option disabled selected>Ghost</option>
  <option>Option 1</option>
</select>
```

### Select colors

```html
<select class="select select-primary">
  <option disabled selected>Primary</option>
  <option>Option 1</option>
</select>

<select class="select select-secondary">
  <option disabled selected>Secondary</option>
  <option>Option 1</option>
</select>

<select class="select select-accent">
  <option disabled selected>Accent</option>
  <option>Option 1</option>
</select>

<select class="select select-neutral">
  <option disabled selected>Neutral</option>
  <option>Option 1</option>
</select>

<select class="select select-info">
  <option disabled selected>Info</option>
  <option>Option 1</option>
</select>

<select class="select select-success">
  <option disabled selected>Success</option>
  <option>Option 1</option>
</select>

<select class="select select-warning">
  <option disabled selected>Warning</option>
  <option>Option 1</option>
</select>

<select class="select select-error">
  <option disabled selected>Error</option>
  <option>Option 1</option>
</select>
```

### Select sizes

```html
<select class="select select-xs">
  <option>Extra small</option>
</select>

<select class="select select-sm">
  <option>Small</option>
</select>

<select class="select select-md">
  <option>Medium</option>
</select>

<select class="select select-lg">
  <option>Large</option>
</select>

<select class="select select-xl">
  <option>Extra large</option>
</select>
```

### Select with label

```html
<label class="form-control w-full max-w-xs">
  <div class="label">
    <span class="label-text">Pick the best fantasy franchise</span>
  </div>
  <select class="select">
    <option disabled selected>Pick one</option>
    <option>Star Wars</option>
    <option>Harry Potter</option>
    <option>Lord of the Rings</option>
    <option>Star Trek</option>
  </select>
  <div class="label">
    <span class="label-text-alt">Choose wisely</span>
  </div>
</label>
```

### Select with option groups

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
