# Navigation Components

Guide for building navigation with daisyUI. For specific component details, see individual files in `components/`.

## Quick Reference

| Component | Use Case | Base Class |
|-----------|----------|------------|
| [navbar](components/navbar.md) | Site header, top navigation | `navbar` |
| [menu](components/menu.md) | Navigation list, sidebar menu | `menu` |
| [drawer](components/drawer.md) | Sidebar, mobile overlay menu | `drawer` |
| [dropdown](components/dropdown.md) | Dropdown menu | `dropdown` |
| [tabs](components/tabs.md) | Content section switching | `tabs` |
| [steps](components/steps.md) | Process flow, wizard progress | `steps` |
| [breadcrumbs](components/breadcrumbs.md) | Page hierarchy navigation | `breadcrumbs` |
| [pagination](components/pagination.md) | Page navigation | `join` + `btn` |
| [link](components/link.md) | Styled anchor links | `link` |

## Responsive Patterns

### Mobile Hamburger / Desktop Full Menu

```html
<div class="navbar bg-base-100">
  <div class="navbar-start">
    <!-- Mobile hamburger -->
    <div class="dropdown">
      <div tabindex="0" role="button" class="btn btn-ghost lg:hidden">
        <svg class="h-5 w-5"><!-- hamburger icon --></svg>
      </div>
      <ul tabindex="0" class="menu menu-sm dropdown-content bg-base-100 rounded-box z-1 mt-3 w-52 p-2 shadow">
        <li><a>Item 1</a></li>
        <li><a>Item 2</a></li>
      </ul>
    </div>
    <a class="btn btn-ghost text-xl">Logo</a>
  </div>
  <!-- Desktop menu -->
  <div class="navbar-center hidden lg:flex">
    <ul class="menu menu-horizontal px-1">
      <li><a>Item 1</a></li>
      <li><a>Item 2</a></li>
    </ul>
  </div>
  <div class="navbar-end">
    <a class="btn">Action</a>
  </div>
</div>
```

Key classes: `lg:hidden` (mobile only), `hidden lg:flex` (desktop only)

### Responsive Drawer

Mobile: overlay sidebar. Desktop: persistent sidebar.

```html
<div class="drawer lg:drawer-open">
  <input id="drawer" type="checkbox" class="drawer-toggle" />
  <div class="drawer-content">
    <!-- Toggle button (mobile only) -->
    <label for="drawer" class="btn btn-primary lg:hidden">Open</label>
    <div class="p-4">Content</div>
  </div>
  <div class="drawer-side">
    <label for="drawer" class="drawer-overlay"></label>
    <ul class="menu bg-base-200 min-h-full w-80 p-4">
      <li><a>Item 1</a></li>
      <li><a>Item 2</a></li>
    </ul>
  </div>
</div>
```

## Menu Patterns

### Vertical Menu with Sections

```html
<ul class="menu bg-base-200 rounded-box w-56">
  <li class="menu-title">Section 1</li>
  <li><a>Item 1</a></li>
  <li><a class="menu-active">Active Item</a></li>
  <li class="menu-disabled"><a>Disabled</a></li>
  <li class="menu-title">Section 2</li>
  <li><a>Item 2</a></li>
</ul>
```

### Collapsible Submenu

Use `<details>` + `<summary>` for native toggle:

```html
<ul class="menu bg-base-200 rounded-box w-56">
  <li><a>Item 1</a></li>
  <li>
    <details open>
      <summary>Parent</summary>
      <ul>
        <li><a>Submenu 1</a></li>
        <li><a>Submenu 2</a></li>
      </ul>
    </details>
  </li>
</ul>
```

### Horizontal Menu

```html
<ul class="menu menu-horizontal bg-base-200 rounded-box">
  <li><a>Item 1</a></li>
  <li><a>Item 2</a></li>
</ul>
```

## Tab Patterns

### Tabs with Content (Radio Input)

Auto-switching content without JavaScript:

```html
<div role="tablist" class="tabs tabs-lift">
  <input type="radio" name="tabs" role="tab" class="tab" aria-label="Tab 1" />
  <div role="tabpanel" class="tab-content bg-base-100 border-base-300 rounded-box p-6">
    Content 1
  </div>

  <input type="radio" name="tabs" role="tab" class="tab" aria-label="Tab 2" checked />
  <div role="tabpanel" class="tab-content bg-base-100 border-base-300 rounded-box p-6">
    Content 2
  </div>
</div>
```

### Tab Styles

```
tabs-border    Bottom border style
tabs-lift      Lift effect style
tabs-box       Box style
```

## Steps (Process Flow)

```html
<ul class="steps">
  <li class="step step-primary">Register</li>
  <li class="step step-primary">Verify</li>
  <li class="step">Payment</li>
  <li class="step">Complete</li>
</ul>
```

Color classes indicate completed/current steps.

## Pagination

Built with `join` + `btn`:

```html
<div class="join">
  <button class="join-item btn">«</button>
  <button class="join-item btn">1</button>
  <button class="join-item btn btn-active">2</button>
  <button class="join-item btn">3</button>
  <button class="join-item btn">»</button>
</div>
```

## Dropdown

### Basic Dropdown

```html
<div class="dropdown">
  <div tabindex="0" role="button" class="btn">Click</div>
  <ul tabindex="0" class="dropdown-content menu bg-base-100 rounded-box z-1 w-52 p-2 shadow">
    <li><a>Item 1</a></li>
    <li><a>Item 2</a></li>
  </ul>
</div>
```

### Dropdown Placement

```
dropdown-top, dropdown-bottom (default)
dropdown-start, dropdown-center, dropdown-end
```

Commonly used in navbar for mobile hamburger menus and user account menus.

## Component Selection Guide

| Need | Use |
|------|-----|
| Site header | `navbar` |
| Sidebar menu | `menu` (inside `drawer`) |
| Mobile sidebar overlay | `drawer` |
| Dropdown menu | `dropdown` |
| Section tabs | `tabs` |
| Wizard/process steps | `steps` |
| Page hierarchy | `breadcrumbs` |
| Page numbers | `join` + `btn` |
| Text links | `link` |

## Size Classes

`menu` and `tabs` support sizes:

```
{component}-xs    Extra small
{component}-sm    Small
{component}-md    Medium (default)
{component}-lg    Large
{component}-xl    Extra large
```

## Related Patterns

- [Dashboard Layout](patterns.md#dashboard-layout) - Stats + drawer layout
- [Data Table with Actions](patterns.md#data-table-with-actions) - Table with pagination
