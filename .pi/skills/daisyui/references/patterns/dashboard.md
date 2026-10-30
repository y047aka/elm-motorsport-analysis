# Dashboard Layout

**Components**: stats, card, drawer

Stats row + Card content area inside a drawer layout. See `drawer.md` "With navbar" for the full drawer+navbar structure.

```html
<!-- Main content area (inside drawer-content) -->
<main class="flex-1 p-6">
  <!-- Stats row -->
  <div class="stats shadow w-full mb-6">
    <div class="stat">
      <div class="stat-title">Total Users</div>
      <div class="stat-value">89,400</div>
      <div class="stat-desc">21% more than last month</div>
    </div>
    <div class="stat">
      <div class="stat-title">Revenue</div>
      <div class="stat-value text-primary">$25,600</div>
      <div class="stat-desc">12% increase</div>
    </div>
  </div>

  <!-- Content cards -->
  <div class="card bg-base-100 shadow">
    <div class="card-body">
      <h2 class="card-title">Content</h2>
      <p>Dashboard content goes here.</p>
    </div>
  </div>
</main>
```

## Usage Notes

- Combine with drawer component for sidebar navigation
- Use stats component to display key metrics at a glance
- Cards provide flexible containers for various content types
- Consider responsive breakpoints for mobile layouts

## Related Patterns

- [Sidebar Navigation](./sidebar-navigation.md) - Complete sidebar with user info
- [Settings Page](./settings-page.md) - Settings panel layout

## Related Components

- [Stats](../components/stats.md)
- [Card](../components/card.md)
- [Drawer](../components/drawer.md)
