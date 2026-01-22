# Select

Dropdown selection component for choosing from a list of options.

## Basic Usage

```html
<select class="select select-bordered w-full max-w-xs">
  <option disabled selected>Pick one</option>
  <option>Option 1</option>
  <option>Option 2</option>
  <option>Option 3</option>
</select>
```

## With Border

```html
<select class="select select-bordered">
  <option disabled selected>Pick one</option>
  <option>Option 1</option>
  <option>Option 2</option>
</select>
```

## Ghost (No Border)

```html
<select class="select select-ghost">
  <option disabled selected>Pick one</option>
  <option>Option 1</option>
  <option>Option 2</option>
</select>
```

## Color Variants

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
```

## State Colors

```html
<select class="select select-bordered select-info">
  <option disabled selected>Info</option>
  <option>Option 1</option>
</select>

<select class="select select-bordered select-success">
  <option disabled selected>Success</option>
  <option>Option 1</option>
</select>

<select class="select select-bordered select-warning">
  <option disabled selected>Warning</option>
  <option>Option 1</option>
</select>

<select class="select select-bordered select-error">
  <option disabled selected>Error</option>
  <option>Option 1</option>
</select>
```

## Sizes

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

## Disabled

```html
<select class="select select-bordered" disabled>
  <option>Disabled</option>
</select>
```

## With Label

```html
<label class="form-control w-full max-w-xs">
  <div class="label">
    <span class="label-text">Pick the best fantasy franchise</span>
    <span class="label-text-alt">Alt label</span>
  </div>
  <select class="select select-bordered">
    <option disabled selected>Pick one</option>
    <option>Star Wars</option>
    <option>Harry Potter</option>
    <option>Lord of the Rings</option>
    <option>Planet of the Apes</option>
    <option>Star Trek</option>
  </select>
  <div class="label">
    <span class="label-text-alt">Alt label</span>
    <span class="label-text-alt">Alt label</span>
  </div>
</label>
```

## With Option Groups

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

## Full Width

```html
<select class="select select-bordered w-full">
  <option disabled selected>Full width select</option>
  <option>Option 1</option>
  <option>Option 2</option>
</select>
```

## In Form

```html
<div class="form-control w-full max-w-xs">
  <label class="label">
    <span class="label-text">Country</span>
  </label>
  <select class="select select-bordered">
    <option disabled selected>Select country</option>
    <option>United States</option>
    <option>United Kingdom</option>
    <option>Japan</option>
    <option>Germany</option>
  </select>
</div>
```

## Classes Reference

| Class | Description |
|-------|-------------|
| `select` | Base select class |
| `select-bordered` | Adds border |
| `select-ghost` | No border, transparent |
| `select-primary` | Primary color focus |
| `select-secondary` | Secondary color focus |
| `select-accent` | Accent color focus |
| `select-neutral` | Neutral color focus |
| `select-info` | Info state color |
| `select-success` | Success state color |
| `select-warning` | Warning state color |
| `select-error` | Error state color |
| `select-xs` | Extra small size |
| `select-sm` | Small size |
| `select-md` | Medium size (default) |
| `select-lg` | Large size |
