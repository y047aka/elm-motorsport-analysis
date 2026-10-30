# Sidebar Navigation

**Components**: drawer, menu, avatar, divider

Complete sidebar with user info and navigation.

```html
<div class="drawer lg:drawer-open">
  <input id="sidebar" type="checkbox" class="drawer-toggle" />
  <div class="drawer-content">
    <!-- Page content -->
    <label for="sidebar" class="btn btn-primary drawer-button lg:hidden m-4">
      Open Menu
    </label>
  </div>
  <div class="drawer-side">
    <label for="sidebar" aria-label="close sidebar" class="drawer-overlay"></label>
    <aside class="bg-base-200 min-h-full w-80 p-4">
      <!-- User info -->
      <div class="flex items-center gap-4 p-4">
        <div class="avatar">
          <div class="w-12 rounded-full">
            <img src="avatar.jpg" alt="User" />
          </div>
        </div>
        <div>
          <p class="font-bold">Jane Doe</p>
          <p class="text-sm opacity-60">jane@example.com</p>
        </div>
      </div>

      <div class="divider my-2"></div>

      <!-- Navigation -->
      <ul class="menu">
        <li class="menu-title">Main</li>
        <li><a class="menu-active">Dashboard</a></li>
        <li><a>Projects</a></li>
        <li><a>Team</a></li>
        <li class="menu-title">Settings</li>
        <li><a>Profile</a></li>
        <li><a>Preferences</a></li>
        <li>
          <details>
            <summary>Advanced</summary>
            <ul>
              <li><a>API Keys</a></li>
              <li><a>Webhooks</a></li>
            </ul>
          </details>
        </li>
      </ul>

      <div class="divider my-2"></div>

      <!-- Logout -->
      <ul class="menu">
        <li><a class="text-error">Logout</a></li>
      </ul>
    </aside>
  </div>
</div>
```

## Usage Notes

- Use `lg:drawer-open` for always-visible sidebar on large screens
- Include `drawer-overlay` for click-outside-to-close on mobile
- Use `menu-title` for section headers in navigation
- Nest `<details>` for collapsible submenus
- Apply `menu-active` to highlight current page
- Use `text-error` for destructive actions like logout

## Related Patterns

- [Dashboard Layout](./dashboard.md) - Main content area structure
- [User Profile Card](./user-profile.md) - Detailed user profile display

## Related Components

- [Drawer](../components/drawer.md)
- [Menu](../components/menu.md)
- [Avatar](../components/avatar.md)
- [Divider](../components/divider.md)
