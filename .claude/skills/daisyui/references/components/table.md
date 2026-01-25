# Table

Component for displaying tabular data.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `table` | Component | Base `<table>` styling |
| `table-zebra` | Modifier | Alternating row stripes |
| `table-pin-rows` | Modifier | Sticky header/footer |
| `table-pin-cols` | Modifier | Sticky `<th>` columns |
| `table-xs` | Size | Extra small |
| `table-sm` | Size | Small |
| `table-md` | Size | Medium (default) |
| `table-lg` | Size | Large |
| `table-xl` | Size | Extra large |

## Essential Examples

### Basic usage

```html
<div class="overflow-x-auto">
  <table class="table">
    <thead>
      <tr>
        <th></th>
        <th>Name</th>
        <th>Job</th>
        <th>Favorite Color</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <th>1</th>
        <td>Cy Ganderton</td>
        <td>Quality Control Specialist</td>
        <td>Blue</td>
      </tr>
      <tr>
        <th>2</th>
        <td>Hart Hagerty</td>
        <td>Desktop Support Technician</td>
        <td>Purple</td>
      </tr>
    </tbody>
  </table>
</div>
```

### Zebra striped

```html
<table class="table table-zebra">
  <thead>
    <tr>
      <th>Name</th>
      <th>Job</th>
    </tr>
  </thead>
  <tbody>
    <tr><td>John</td><td>Engineer</td></tr>
    <tr><td>Jane</td><td>Designer</td></tr>
    <tr><td>Bob</td><td>Manager</td></tr>
  </tbody>
</table>
```

### Sticky header

```html
<div class="overflow-x-auto h-96">
  <table class="table table-pin-rows">
    <thead>
      <tr>
        <th>Name</th>
        <th>Job</th>
      </tr>
    </thead>
    <tbody>
      <!-- Many rows here -->
    </tbody>
  </table>
</div>
```

### With interactive elements

```html
<table class="table">
  <thead>
    <tr>
      <th><input type="checkbox" class="checkbox" /></th>
      <th>Name</th>
      <th>Status</th>
      <th></th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th><input type="checkbox" class="checkbox" /></th>
      <td>Hart Hagerty</td>
      <td><span class="badge badge-success">Active</span></td>
      <th><button class="btn btn-ghost btn-xs">details</button></th>
    </tr>
  </tbody>
</table>
```

## Notes

- Wrap with `overflow-x-auto` for responsive horizontal scrolling
- Active row: Add `bg-base-200` class to `<tr>`
- Hover: Add `hover:bg-base-300` to rows
