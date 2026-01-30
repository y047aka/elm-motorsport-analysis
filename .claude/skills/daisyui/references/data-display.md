# Data Display Components

Guide for displaying data with daisyUI. For specific component details, see individual files in `components/`.

## Quick Reference

| Component | Use Case | Base Class |
|-----------|----------|------------|
| [table](components/table.md) | Tabular data | `table` |
| [stats](components/stats.md) | Metrics, KPIs | `stats` |
| [avatar](components/avatar.md) | User images | `avatar` |
| [badge](components/badge.md) | Status labels, counts | `badge` |
| [status](components/status.md) | Status indicator dot | `status` |
| [accordion](components/accordion.md) | Expandable FAQ | `collapse` + radio |
| [collapse](components/collapse.md) | Single expandable | `collapse` |
| [timeline](components/timeline.md) | Event sequence | `timeline` |
| [list](components/list.md) | Structured rows | `list` |
| [carousel](components/carousel.md) | Image slider | `carousel` |
| [countdown](components/countdown.md) | Timer display | `countdown` |
| [chat-bubble](components/chat-bubble.md) | Chat messages | `chat` |
| [diff](components/diff.md) | Before/after compare | `diff` |
| [kbd](components/kbd.md) | Keyboard keys | `kbd` |

## Table

### Basic Table

```html
<div class="overflow-x-auto">
  <table class="table">
    <thead>
      <tr>
        <th>Name</th>
        <th>Job</th>
        <th>Status</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>John Doe</td>
        <td>Engineer</td>
        <td><span class="badge badge-success">Active</span></td>
      </tr>
    </tbody>
  </table>
</div>
```

### Table Modifiers

```
table-zebra       Alternating row colors
table-pin-rows    Sticky header/footer
table-pin-cols    Sticky th columns
```

### Table Sizes

```
table-xs, table-sm, table-md (default), table-lg, table-xl
```

## Stats

### Basic Stats

```html
<div class="stats shadow">
  <div class="stat">
    <div class="stat-title">Total Users</div>
    <div class="stat-value">89,400</div>
    <div class="stat-desc">21% more than last month</div>
  </div>
</div>
```

### Multiple Stats

```html
<div class="stats shadow">
  <div class="stat">
    <div class="stat-figure text-primary">
      <svg class="h-8 w-8"><!-- icon --></svg>
    </div>
    <div class="stat-title">Downloads</div>
    <div class="stat-value text-primary">31K</div>
  </div>
  <div class="stat">
    <div class="stat-title">Revenue</div>
    <div class="stat-value">$25,600</div>
    <div class="stat-desc text-success">+12%</div>
  </div>
</div>
```

### Stats Layout

```
stats-horizontal    Horizontal (default)
stats-vertical      Vertical stack
```

Responsive: `stats-vertical lg:stats-horizontal`

## Avatar

### Basic Avatar

```html
<div class="avatar">
  <div class="w-24 rounded-full">
    <img src="user.jpg" />
  </div>
</div>
```

### Avatar with Status

```html
<div class="avatar avatar-online">
  <div class="w-12 rounded-full">
    <img src="user.jpg" />
  </div>
</div>
```

### Placeholder Avatar

```html
<div class="avatar avatar-placeholder">
  <div class="bg-neutral text-neutral-content w-12 rounded-full">
    <span>AB</span>
  </div>
</div>
```

### Avatar Group

```html
<div class="avatar-group -space-x-6">
  <div class="avatar">
    <div class="w-12 rounded-full"><img src="user1.jpg" /></div>
  </div>
  <div class="avatar">
    <div class="w-12 rounded-full"><img src="user2.jpg" /></div>
  </div>
  <div class="avatar avatar-placeholder">
    <div class="bg-neutral text-neutral-content w-12 rounded-full">
      <span>+5</span>
    </div>
  </div>
</div>
```

## Badge

### Basic Badge

```html
<div class="badge">Default</div>
<div class="badge badge-primary">Primary</div>
<div class="badge badge-outline">Outline</div>
```

### Badge Colors

```
badge-neutral, badge-primary, badge-secondary, badge-accent
badge-info, badge-success, badge-warning, badge-error
```

### Badge Styles

```
badge-outline    Outline style
badge-dash       Dashed outline
badge-soft       Soft background
badge-ghost      Ghost style
```

### Badge Sizes

```
badge-xs, badge-sm, badge-md (default), badge-lg, badge-xl
```

### Empty Badge (Dot)

```html
<div class="badge badge-primary badge-xs"></div>
```

## Status

Compact indicator dots:

```html
<span class="status status-success"></span>
<span class="status status-warning"></span>
<span class="status status-error"></span>
```

### Status with Text

```html
<div class="flex items-center gap-2">
  <span class="status status-success"></span>
  <span>Online</span>
</div>
```

### Status Sizes

```
status-xs, status-sm, status-md (default), status-lg, status-xl
```

### Status with Animation

```html
<span class="status status-success animate-ping"></span>
```

## Accordion

Single-item-open behavior using radio inputs:

```html
<div class="join join-vertical w-full">
  <div class="collapse collapse-arrow join-item border border-base-300">
    <input type="radio" name="accordion" checked />
    <div class="collapse-title font-semibold">Question 1</div>
    <div class="collapse-content">Answer 1</div>
  </div>
  <div class="collapse collapse-arrow join-item border border-base-300">
    <input type="radio" name="accordion" />
    <div class="collapse-title font-semibold">Question 2</div>
    <div class="collapse-content">Answer 2</div>
  </div>
</div>
```

## Collapse

Standalone expandable panel:

```html
<div class="collapse collapse-arrow bg-base-100 border border-base-300">
  <input type="checkbox" />
  <div class="collapse-title font-semibold">Click to expand</div>
  <div class="collapse-content">Hidden content</div>
</div>
```

### Collapse Indicators

```
collapse-arrow    Rotating arrow
collapse-plus     Plus/minus toggle
```

## Timeline

```html
<ul class="timeline timeline-vertical">
  <li>
    <div class="timeline-start">2024</div>
    <div class="timeline-middle">
      <svg class="h-5 w-5"><!-- icon --></svg>
    </div>
    <div class="timeline-end timeline-box">Event description</div>
    <hr />
  </li>
  <li>
    <hr />
    <div class="timeline-start">2025</div>
    <div class="timeline-middle">
      <svg class="h-5 w-5"><!-- icon --></svg>
    </div>
    <div class="timeline-end timeline-box">Another event</div>
  </li>
</ul>
```

Use `<hr />` to create connecting lines. Add `bg-primary` to `<hr>` for colored lines.

## List

Structured rows with auto-growing columns:

```html
<ul class="list bg-base-100 rounded-box shadow-md">
  <li class="list-row">
    <div><img src="thumb.jpg" class="h-12 w-12 rounded" /></div>
    <div class="list-col-grow">
      <p class="font-bold">Title</p>
      <p class="text-sm opacity-60">Subtitle</p>
    </div>
    <button class="btn btn-ghost btn-sm">Action</button>
  </li>
</ul>
```

By default, second child grows. Use `list-col-grow` to change which column grows.

## Component Selection Guide

| Need | Use |
|------|-----|
| Spreadsheet-like data | `table` |
| Metrics dashboard | `stats` |
| User profile image | `avatar` |
| Status label/count | `badge` |
| Status indicator dot | `status` |
| FAQ list | `accordion` |
| Expandable section | `collapse` |
| Event history | `timeline` |
| Media list | `list` |
| Image gallery | `carousel` |
| Timer/countdown | `countdown` |
| Chat interface | `chat-bubble` |
| Before/after | `diff` |
| Keyboard shortcut | `kbd` |

## Common Combinations

### Table Row with Avatar + Badge

```html
<tr>
  <td>
    <div class="flex items-center gap-3">
      <div class="avatar">
        <div class="w-10 rounded-full">
          <img src="user.jpg" />
        </div>
      </div>
      <div>
        <div class="font-bold">John Doe</div>
        <div class="text-sm opacity-50">Engineer</div>
      </div>
    </div>
  </td>
  <td><span class="badge badge-success">Active</span></td>
</tr>
```

### Stats with Icon

```html
<div class="stat">
  <div class="stat-figure text-secondary">
    <svg class="h-8 w-8"><!-- icon --></svg>
  </div>
  <div class="stat-title">New Users</div>
  <div class="stat-value text-secondary">4,200</div>
  <div class="stat-desc">↗︎ 22% increase</div>
</div>
```

## Related Patterns

- [Dashboard Layout](patterns.md#dashboard-layout) - Stats + cards
- [Data Table with Actions](patterns.md#data-table-with-actions) - Full table example
