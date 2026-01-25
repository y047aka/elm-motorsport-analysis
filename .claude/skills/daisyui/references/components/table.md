# Table

Component for displaying tabular data with responsive features and styling options.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `table` | Component | Base class for `<table>` tag styling |
| `table-zebra` | Modifier | Applies alternating row stripe styling |
| `table-pin-rows` | Modifier | Makes rows in `<thead>` and `<tfoot>` sticky |
| `table-pin-cols` | Modifier | Makes `<th>` columns sticky during horizontal scroll |
| `table-xs` | Size | Extra small sizing |
| `table-sm` | Size | Small sizing |
| `table-md` | Size | Medium sizing (default) |
| `table-lg` | Size | Large sizing |
| `table-xl` | Size | Extra large sizing |

## Key Examples

### Basic table

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
      <tr>
        <th>3</th>
        <td>Brice Swyre</td>
        <td>Tax Accountant</td>
        <td>Red</td>
      </tr>
    </tbody>
  </table>
</div>
```

### Zebra striped table

```html
<table class="table table-zebra">
  <thead>
    <tr>
      <th>Name</th>
      <th>Job</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>John</td>
      <td>Engineer</td>
    </tr>
    <tr>
      <td>Jane</td>
      <td>Designer</td>
    </tr>
    <tr>
      <td>Bob</td>
      <td>Manager</td>
    </tr>
  </tbody>
</table>
```

### Table sizes

```html
<table class="table table-xs"><!-- Extra small --></table>
<table class="table table-sm"><!-- Small --></table>
<table class="table table-md"><!-- Medium (default) --></table>
<table class="table table-lg"><!-- Large --></table>
<table class="table table-xl"><!-- Extra large --></table>
```

### Sticky header (pinned rows)

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

### Sticky columns (pinned columns)

```html
<div class="overflow-x-auto">
  <table class="table table-pin-cols">
    <thead>
      <tr>
        <th></th>
        <td>Column 1</td>
        <td>Column 2</td>
        <td>Column 3</td>
        <th></th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <th>Row 1</th>
        <td>Data</td>
        <td>Data</td>
        <td>Data</td>
        <th>Row 1</th>
      </tr>
    </tbody>
  </table>
</div>
```

### Table with interactive elements

```html
<table class="table">
  <thead>
    <tr>
      <th>
        <input type="checkbox" class="checkbox" />
      </th>
      <th>Name</th>
      <th>Status</th>
      <th></th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th>
        <input type="checkbox" class="checkbox" />
      </th>
      <td>
        <div class="flex items-center gap-3">
          <div class="avatar">
            <div class="mask mask-squircle h-12 w-12">
              <img src="avatar.jpg" alt="Avatar" />
            </div>
          </div>
          <div>
            <div class="font-bold">Hart Hagerty</div>
            <div class="text-sm opacity-50">United States</div>
          </div>
        </div>
      </td>
      <td>
        <span class="badge badge-success">Active</span>
      </td>
      <th>
        <button class="btn btn-ghost btn-xs">details</button>
      </th>
    </tr>
  </tbody>
</table>
```

### Highlighted active row

```html
<table class="table">
  <tbody>
    <tr>
      <td>Normal row</td>
    </tr>
    <tr class="bg-base-200">
      <td>Active row</td>
    </tr>
    <tr>
      <td>Normal row</td>
    </tr>
  </tbody>
</table>
```

### Row hover effect

```html
<table class="table">
  <tbody>
    <tr class="hover:bg-base-300">
      <td>Hover over me</td>
    </tr>
    <tr class="hover:bg-base-300">
      <td>Hover over me</td>
    </tr>
  </tbody>
</table>
```

### Bordered card-style table

```html
<div class="overflow-x-auto">
  <table class="table rounded-box border border-base-content/5 bg-base-100">
    <thead>
      <tr>
        <th>Name</th>
        <th>Job</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>John</td>
        <td>Engineer</td>
      </tr>
      <tr>
        <td>Jane</td>
        <td>Designer</td>
      </tr>
    </tbody>
  </table>
</div>
```
