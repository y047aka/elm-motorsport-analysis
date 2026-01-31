# Search with Filters

**Components**: input, dropdown, checkbox, badge, button

Search interface with filter options.

```html
<div class="flex flex-col gap-4 max-w-2xl">
  <!-- Search bar -->
  <div class="join w-full">
    <input type="text" placeholder="Search..." class="input join-item flex-1" />
    <div class="dropdown dropdown-end">
      <label tabindex="0" class="btn join-item">
        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 4a1 1 0 011-1h16a1 1 0 011 1v2.586a1 1 0 01-.293.707l-6.414 6.414a1 1 0 00-.293.707V17l-4 4v-6.586a1 1 0 00-.293-.707L3.293 7.293A1 1 0 013 6.586V4z" />
        </svg>
        Filters
      </label>
      <div class="dropdown-content z-1 card card-sm w-64 p-2 shadow bg-base-100">
        <div class="card-body">
          <h3 class="font-bold">Filter by</h3>
          <label class="flex items-center justify-between cursor-pointer">
            <span>Active only</span>
            <input type="checkbox" class="checkbox checkbox-sm" checked />
          </label>
          <label class="flex items-center justify-between cursor-pointer">
            <span>Verified users</span>
            <input type="checkbox" class="checkbox checkbox-sm" />
          </label>
          <label class="flex items-center justify-between cursor-pointer">
            <span>Recent (7 days)</span>
            <input type="checkbox" class="checkbox checkbox-sm" />
          </label>
        </div>
      </div>
    </div>
    <button class="btn btn-primary join-item">Search</button>
  </div>

  <!-- Active filters display -->
  <div class="flex flex-wrap gap-2">
    <div class="badge badge-primary gap-1">
      Active only
      <button class="btn btn-ghost btn-xs p-0">x</button>
    </div>
    <div class="badge badge-secondary gap-1">
      Category: Design
      <button class="btn btn-ghost btn-xs p-0">x</button>
    </div>
  </div>
</div>
```

## Usage Notes

- Use `join` to combine search input, filter dropdown, and search button
- Display active filters as removable badges below the search bar
- Use `dropdown-end` to align dropdown menu to the right
- Include a clear visual indicator (filter icon) for the filter button
- Set `z-1` on dropdown content to ensure it appears above other elements
- Use `card-sm` for compact card sizing (daisyUI v5, replaces `card-compact`)

## Related Patterns

- [Data Table with Actions](./data-table.md) - Table with search and filters
- [Form with Validation](./form-validation.md) - Input patterns

## Related Components

- [Input](../components/input.md)
- [Dropdown](../components/dropdown.md)
- [Badge](../components/badge.md)
- [Join](../components/join.md)
