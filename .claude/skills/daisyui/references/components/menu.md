# Menu

Vertical or horizontal list of navigation links.

## Basic Usage

```html
<ul class="menu bg-base-200 rounded-box w-56">
  <li><a>Item 1</a></li>
  <li><a>Item 2</a></li>
  <li><a>Item 3</a></li>
</ul>
```

## With Title

```html
<ul class="menu bg-base-200 rounded-box w-56">
  <li class="menu-title">Title</li>
  <li><a>Item 1</a></li>
  <li><a>Item 2</a></li>
  <li><a>Item 3</a></li>
</ul>
```

## With Icons

```html
<ul class="menu bg-base-200 rounded-box w-56">
  <li>
    <a>
      <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
      </svg>
      Home
    </a>
  </li>
  <li>
    <a>
      <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
      </svg>
      Details
    </a>
  </li>
  <li>
    <a>
      <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
      </svg>
      Stats
    </a>
  </li>
</ul>
```

## With Submenu (Details)

```html
<ul class="menu bg-base-200 rounded-box w-56">
  <li><a>Item 1</a></li>
  <li>
    <details open>
      <summary>Parent</summary>
      <ul>
        <li><a>Submenu 1</a></li>
        <li><a>Submenu 2</a></li>
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
    </details>
  </li>
  <li><a>Item 3</a></li>
</ul>
```

## Active Item

```html
<ul class="menu bg-base-200 rounded-box w-56">
  <li><a>Item 1</a></li>
  <li><a class="active">Active Item</a></li>
  <li><a>Item 3</a></li>
</ul>
```

## Focus Item

```html
<ul class="menu bg-base-200 rounded-box w-56">
  <li><a>Item 1</a></li>
  <li><a class="focus">Focused Item</a></li>
  <li><a>Item 3</a></li>
</ul>
```

## Disabled Item

```html
<ul class="menu bg-base-200 rounded-box w-56">
  <li><a>Item 1</a></li>
  <li class="disabled"><a>Disabled Item</a></li>
  <li><a>Item 3</a></li>
</ul>
```

## Horizontal Menu

```html
<ul class="menu menu-horizontal bg-base-200 rounded-box">
  <li><a>Item 1</a></li>
  <li><a>Item 2</a></li>
  <li><a>Item 3</a></li>
</ul>
```

## Sizes

```html
<!-- Extra small -->
<ul class="menu menu-xs bg-base-200 rounded-box w-56">
  <li><a>Item 1</a></li>
  <li><a>Item 2</a></li>
</ul>

<!-- Small -->
<ul class="menu menu-sm bg-base-200 rounded-box w-56">
  <li><a>Item 1</a></li>
  <li><a>Item 2</a></li>
</ul>

<!-- Medium (default) -->
<ul class="menu menu-md bg-base-200 rounded-box w-56">
  <li><a>Item 1</a></li>
  <li><a>Item 2</a></li>
</ul>

<!-- Large -->
<ul class="menu menu-lg bg-base-200 rounded-box w-56">
  <li><a>Item 1</a></li>
  <li><a>Item 2</a></li>
</ul>
```

## With Badge

```html
<ul class="menu bg-base-200 rounded-box w-56">
  <li>
    <a>
      Inbox
      <span class="badge badge-sm">99+</span>
    </a>
  </li>
  <li>
    <a>
      Updates
      <span class="badge badge-sm badge-warning">NEW</span>
    </a>
  </li>
  <li><a>Stats</a></li>
</ul>
```

## Responsive (Horizontal on Large)

```html
<ul class="menu menu-vertical lg:menu-horizontal bg-base-200 rounded-box">
  <li><a>Item 1</a></li>
  <li><a>Item 2</a></li>
  <li><a>Item 3</a></li>
</ul>
```

## Collapsible Submenu

```html
<ul class="menu bg-base-200 rounded-box w-56">
  <li>
    <details>
      <summary>Click to open</summary>
      <ul>
        <li><a>Submenu 1</a></li>
        <li><a>Submenu 2</a></li>
      </ul>
    </details>
  </li>
</ul>
```

## Classes Reference

| Class | Description |
|-------|-------------|
| `menu` | Container element |
| `menu-title` | Title/header item |
| `menu-horizontal` | Horizontal layout |
| `menu-vertical` | Vertical layout (default) |
| `menu-xs` | Extra small size |
| `menu-sm` | Small size |
| `menu-md` | Medium size (default) |
| `menu-lg` | Large size |
| `active` | Active state (on anchor) |
| `focus` | Focus state (on anchor) |
| `disabled` | Disabled state (on li) |
