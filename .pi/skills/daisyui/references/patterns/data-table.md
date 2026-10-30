# Data Table with Actions

**Components**: table, checkbox, avatar, badge, dropdown, menu, join, button

Table with row actions and pagination. See also `table.md` for base table usage and sizes.

```html
<div class="overflow-x-auto">
  <table class="table">
    <thead>
      <tr>
        <th>
          <label>
            <input type="checkbox" class="checkbox" />
          </label>
        </th>
        <th>Name</th>
        <th>Email</th>
        <th>Status</th>
        <th>Actions</th>
      </tr>
    </thead>
    <tbody>
      <tr class="hover">
        <th>
          <label>
            <input type="checkbox" class="checkbox" />
          </label>
        </th>
        <td>
          <div class="flex items-center gap-3">
            <div class="avatar">
              <div class="mask mask-squircle w-10 h-10">
                <img src="avatar.jpg" alt="Avatar" />
              </div>
            </div>
            <div>
              <div class="font-bold">John Doe</div>
              <div class="text-sm opacity-50">United States</div>
            </div>
          </div>
        </td>
        <td>john@example.com</td>
        <td>
          <div class="badge badge-success gap-2">Active</div>
        </td>
        <td>
          <div class="dropdown dropdown-end">
            <label tabindex="0" class="btn btn-ghost btn-sm">...</label>
            <ul class="dropdown-content z-1 menu p-2 shadow bg-base-100 rounded-box w-32">
              <li><a>Edit</a></li>
              <li><a>View</a></li>
              <li><a class="text-error">Delete</a></li>
            </ul>
          </div>
        </td>
      </tr>
    </tbody>
  </table>
</div>

<!-- Pagination -->
<div class="flex justify-center mt-4">
  <div class="join">
    <button class="join-item btn"><<</button>
    <button class="join-item btn">1</button>
    <button class="join-item btn btn-active">2</button>
    <button class="join-item btn">3</button>
    <button class="join-item btn">>></button>
  </div>
</div>
```

## Usage Notes

- Wrap table in `overflow-x-auto` for horizontal scrolling on small screens
- Use `hover` class on rows for hover effect
- Dropdown actions keep the table clean while providing options
- Badge colors indicate status (success, warning, error)

## Related Components

- [Table](../components/table.md)
- [Dropdown](../components/dropdown.md)
- [Badge](../components/badge.md)
- [Join](../components/join.md)
