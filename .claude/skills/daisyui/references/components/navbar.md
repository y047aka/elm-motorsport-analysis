# Navbar

Navigation bar component for site headers.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `navbar` | Component | Container element |
| `navbar-start` | Part | For the div inside navbar, to fill 50% of width |
| `navbar-center` | Part | Center section |
| `navbar-end` | Part | For the div inside navbar, to fill second 50% of width |

## Essential Examples

### Basic usage

```html
<div class="navbar bg-base-100">
  <a class="btn btn-ghost text-xl">daisyUI</a>
</div>
```

### With structure

```html
<!-- Responsive with hamburger menu -->
<div class="navbar bg-base-100">
  <div class="navbar-start">
    <div class="dropdown">
      <div tabindex="0" role="button" class="btn btn-ghost lg:hidden">
        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h8m-8 6h16" />
        </svg>
      </div>
      <ul tabindex="0" class="menu menu-sm dropdown-content bg-base-100 rounded-box z-1 mt-3 w-52 p-2 shadow">
        <li><a>Item 1</a></li>
        <li><a>Item 2</a></li>
      </ul>
    </div>
    <a class="btn btn-ghost text-xl">daisyUI</a>
  </div>
  <div class="navbar-center hidden lg:flex">
    <ul class="menu menu-horizontal px-1">
      <li><a>Item 1</a></li>
      <li><a>Item 2</a></li>
    </ul>
  </div>
  <div class="navbar-end">
    <a class="btn">Button</a>
  </div>
</div>
```

### With menu sections

```html
<div class="navbar bg-base-100">
  <div class="flex-1">
    <a class="btn btn-ghost text-xl">daisyUI</a>
  </div>
  <div class="flex-none">
    <ul class="menu menu-horizontal px-1">
      <li><a>Link</a></li>
      <li>
        <details>
          <summary>Parent</summary>
          <ul class="bg-base-100 rounded-t-none p-2">
            <li><a>Link 1</a></li>
            <li><a>Link 2</a></li>
          </ul>
        </details>
      </li>
    </ul>
  </div>
</div>
```

## Notes

- **Recommended**: For responsive design, use dropdown with `lg:hidden` / `lg:flex` pattern for mobile hamburger menu
- **Recommended**: Combine with `menu`, `dropdown`, and `btn-ghost` components
- **Deprecated since v5**: `btm-nav` → use `dock` component instead for bottom navigation
