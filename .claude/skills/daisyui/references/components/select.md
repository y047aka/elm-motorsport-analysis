# Select

Dropdown selection component for choosing from a list of options.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `select` | Component | Select base class |
| `select-bordered` | Style | Adds border |
| `select-ghost` | Style | No border, transparent |
| `select-primary` | Color | Primary color focus |
| `select-secondary` | Color | Secondary color focus |
| `select-accent` | Color | Accent color focus |
| `select-neutral` | Color | Neutral color focus |
| `select-info` | Color | Info state color |
| `select-success` | Color | Success state color |
| `select-warning` | Color | Warning state color |
| `select-error` | Color | Error state color |
| `select-xs` | Size | Extra small size |
| `select-sm` | Size | Small size |
| `select-md` | Size | Medium size (default) |
| `select-lg` | Size | Large size |

## Key Examples

### Basic select

```html
<select class="select select-bordered w-full max-w-xs">
  <option disabled selected>Pick one</option>
  <option>Option 1</option>
  <option>Option 2</option>
  <option>Option 3</option>
</select>
```

### Select styles

```html
<select class="select select-bordered">
  <option disabled selected>Bordered</option>
  <option>Option 1</option>
</select>

<select class="select select-ghost">
  <option disabled selected>Ghost</option>
  <option>Option 1</option>
</select>
```

### Select colors

```html
<select class="select select-bordered select-primary">
  <option disabled selected>Primary</option>
  <option>Option 1</option>
</select>

<select class="select select-bordered select-secondary">
  <option disabled selected>Secondary</option>
  <option>Option 1</option>
</select>

<select class="select select-bordered select-accent">
  <option disabled selected>Accent</option>
  <option>Option 1</option>
</select>

<select class="select select-bordered select-success">
  <option disabled selected>Success</option>
  <option>Option 1</option>
</select>

<select class="select select-bordered select-error">
  <option disabled selected>Error</option>
  <option>Option 1</option>
</select>
```

### Select sizes

```html
<select class="select select-bordered select-xs">
  <option>Extra small</option>
</select>

<select class="select select-bordered select-sm">
  <option>Small</option>
</select>

<select class="select select-bordered select-md">
  <option>Medium</option>
</select>

<select class="select select-bordered select-lg">
  <option>Large</option>
</select>
```

### Select with label

```html
<label class="form-control w-full max-w-xs">
  <div class="label">
    <span class="label-text">Pick the best fantasy franchise</span>
  </div>
  <select class="select select-bordered">
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
<select class="select select-bordered w-full max-w-xs">
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
