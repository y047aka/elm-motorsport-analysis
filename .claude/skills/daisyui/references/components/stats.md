# Stats

Component for displaying statistics and metrics.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `stats` | Component | Container for stat blocks |
| `stat` | Part | Individual stat block |
| `stat-title` | Part | Title section |
| `stat-value` | Part | Main value display |
| `stat-desc` | Part | Description section |
| `stat-figure` | Part | Icon or visual element |
| `stat-actions` | Part | Action buttons |
| `stats-horizontal` | direction | Horizontal layout (default) |
| `stats-vertical` | direction | Vertical layout |

## Essential Examples

### Basic usage

```html
<div class="stats shadow">
  <div class="stat">
    <div class="stat-title">Total Page Views</div>
    <div class="stat-value">89,400</div>
    <div class="stat-desc">21% more than last month</div>
  </div>
</div>
```

### Multiple stats

```html
<div class="stats shadow">
  <div class="stat">
    <div class="stat-title">Downloads</div>
    <div class="stat-value">31K</div>
    <div class="stat-desc">Jan 1st - Feb 1st</div>
  </div>

  <div class="stat">
    <div class="stat-title">New Users</div>
    <div class="stat-value">4,200</div>
    <div class="stat-desc">↗︎ 400 (22%)</div>
  </div>

  <div class="stat">
    <div class="stat-title">New Registers</div>
    <div class="stat-value">1,200</div>
    <div class="stat-desc">↘︎ 90 (14%)</div>
  </div>
</div>
```

### With icons

```html
<div class="stats shadow">
  <div class="stat">
    <div class="stat-figure text-primary">
      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class="inline-block h-8 w-8 stroke-current">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z"></path>
      </svg>
    </div>
    <div class="stat-title">Total Likes</div>
    <div class="stat-value text-primary">25.6K</div>
    <div class="stat-desc">21% more than last month</div>
  </div>
</div>
```

### Responsive layout

```html
<div class="stats stats-vertical lg:stats-horizontal shadow">
  <div class="stat">
    <div class="stat-title">Downloads</div>
    <div class="stat-value">31K</div>
  </div>

  <div class="stat">
    <div class="stat-title">New Users</div>
    <div class="stat-value">4,200</div>
  </div>
</div>
```

## Notes

- Layout: `stats-vertical` or `stats-horizontal` (default)
- Centering: Add `place-items-center` to individual `stat` elements
- Combine with Tailwind: `shadow`, background colors, text colors
- Common parts: `stat-figure` for icons, `stat-actions` for buttons
