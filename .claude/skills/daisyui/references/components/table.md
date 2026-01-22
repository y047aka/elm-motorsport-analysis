# Table

Component for displaying tabular data.

## Basic Usage

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

## Zebra Rows

```html
<table class="table table-zebra">
  <!-- Alternating row colors -->
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
```

## Active/Hover Rows

```html
<table class="table">
  <thead>
    <tr>
      <th>Name</th>
      <th>Job</th>
    </tr>
  </thead>
  <tbody>
    <!-- Active row -->
    <tr class="bg-base-200">
      <td>John</td>
      <td>Engineer</td>
    </tr>
    <!-- Hover effect -->
    <tr class="hover">
      <td>Jane</td>
      <td>Designer</td>
    </tr>
    <!-- Hover on all rows -->
    <tr class="hover:bg-base-300">
      <td>Bob</td>
      <td>Manager</td>
    </tr>
  </tbody>
</table>
```

## Table Sizes

```html
<!-- Extra small -->
<table class="table table-xs">...</table>

<!-- Small -->
<table class="table table-sm">...</table>

<!-- Medium (default) -->
<table class="table table-md">...</table>

<!-- Large -->
<table class="table table-lg">...</table>
```

## Pinned Rows (Sticky Header)

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

## Pinned Columns (Sticky Columns)

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

## Pinned Rows and Columns

```html
<div class="overflow-x-auto h-96">
  <table class="table table-pin-rows table-pin-cols">
    <!-- Both header rows and first/last columns are sticky -->
  </table>
</div>
```

## With Visual Elements

```html
<table class="table">
  <thead>
    <tr>
      <th>
        <label>
          <input type="checkbox" class="checkbox" />
        </label>
      </th>
      <th>Name</th>
      <th>Job</th>
      <th>Status</th>
      <th></th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th>
        <label>
          <input type="checkbox" class="checkbox" />
        </label>
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
        Zemlak, Daniel and Leannon
        <br />
        <span class="badge badge-ghost badge-sm">Desktop Support Technician</span>
      </td>
      <td>
        <span class="badge badge-success">Active</span>
      </td>
      <th>
        <button class="btn btn-ghost btn-xs">details</button>
      </th>
    </tr>
  </tbody>
  <tfoot>
    <tr>
      <th></th>
      <th>Name</th>
      <th>Job</th>
      <th>Status</th>
      <th></th>
    </tr>
  </tfoot>
</table>
```

## Classes Reference

| Class | Description |
|-------|-------------|
| `table` | Base table class |
| `table-zebra` | Alternating row colors |
| `table-pin-rows` | Sticky header rows |
| `table-pin-cols` | Sticky first/last columns |
| `table-xs` | Extra small size |
| `table-sm` | Small size |
| `table-md` | Medium size (default) |
| `table-lg` | Large size |
| `hover` | Row hover effect (on tr) |
