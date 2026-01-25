# Menu

Vertical or horizontal navigation list.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `menu` | Component | Main component for `<ul>` |
| `menu-title` | Part | Section title |
| `menu-dropdown` | Part | Collapsible submenu |
| `menu-dropdown-toggle` | Part | Toggle for submenu |
| `menu-disabled` | Modifier | Disabled state |
| `menu-active` | Modifier | Active/selected state |
| `menu-focus` | Modifier | Focus styling |
| `menu-dropdown-show` | Behavior | Show submenu via JS |
| `menu-xs` | Size | Extra small |
| `menu-sm` | Size | Small |
| `menu-md` | Size | Medium (default) |
| `menu-lg` | Size | Large |
| `menu-xl` | Size | Extra large |
| `menu-vertical` | direction | Vertical layout (default) |
| `menu-horizontal` | direction | Horizontal layout |

## Essential Examples

### Basic usage

```html
<ul class="menu bg-base-200 rounded-box w-56">
  <li><a>Item 1</a></li>
  <li><a>Item 2</a></li>
  <li><a>Item 3</a></li>
</ul>
```

### With icons

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
</ul>
```

### With submenu

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
  <li><a>Item 3</a></li>
</ul>
```

### Active state

```html
<ul class="menu bg-base-200 rounded-box w-56">
  <li><a>Item 1</a></li>
  <li><a class="menu-active">Active Item</a></li>
  <li class="menu-disabled"><a>Disabled Item</a></li>
</ul>
```

### Horizontal menu

```html
<ul class="menu menu-horizontal bg-base-200 rounded-box">
  <li><a>Item 1</a></li>
  <li><a>Item 2</a></li>
  <li><a>Item 3</a></li>
</ul>
```

## Notes

- Submenu: Use `<details>` + `<summary>` for collapsible sections
- Common use: Sidebar navigation, navbar links, dropdown menus
