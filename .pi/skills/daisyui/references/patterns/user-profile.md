# User Profile Card

**Components**: card, avatar, badge, stats

User information display with metrics.

```html
<div class="card bg-base-100 shadow-xl w-96">
  <div class="card-body items-center text-center">
    <div class="avatar avatar-online">
      <div class="w-24 rounded-full ring ring-primary ring-offset-base-100 ring-offset-2">
        <img src="avatar.jpg" alt="User avatar" />
      </div>
    </div>
    <h2 class="card-title mt-4">Jane Doe</h2>
    <p class="text-base-content/60">Product Designer</p>
    <div class="flex gap-2 mt-2">
      <div class="badge badge-primary">Design</div>
      <div class="badge badge-secondary">UX</div>
      <div class="badge badge-accent">Research</div>
    </div>
    
    <div class="stats stats-vertical lg:stats-horizontal shadow mt-6 w-full">
      <div class="stat place-items-center">
        <div class="stat-title">Projects</div>
        <div class="stat-value text-primary">31</div>
      </div>
      <div class="stat place-items-center">
        <div class="stat-title">Followers</div>
        <div class="stat-value">4.2K</div>
      </div>
      <div class="stat place-items-center">
        <div class="stat-title">Following</div>
        <div class="stat-value text-secondary">89</div>
      </div>
    </div>

    <div class="card-actions mt-4">
      <button class="btn btn-primary">Follow</button>
      <button class="btn btn-ghost">Message</button>
    </div>
  </div>
</div>
```

## Avatar Status Indicators

```html
<!-- Online -->
<div class="avatar avatar-online">...</div>

<!-- Offline -->
<div class="avatar avatar-offline">...</div>
```

## Usage Notes

- Center content with `items-center text-center` on card-body
- Use `ring` utilities for avatar border effect
- Badges display user skills or tags
- Stats component shows key metrics
- Use `stats-vertical` on mobile, `lg:stats-horizontal` on larger screens

## Related Patterns

- [Settings Page](./settings-page.md) - User settings panel
- [Sidebar Navigation](./sidebar-navigation.md) - User info in sidebar

## Related Components

- [Card](../components/card.md)
- [Avatar](../components/avatar.md)
- [Badge](../components/badge.md)
- [Stats](../components/stats.md)
