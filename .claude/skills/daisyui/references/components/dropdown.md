# Dropdown

Menu component for displaying a list of options.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `dropdown` | Component | Container for button and content |
| `dropdown-content` | Part | Content container |
| `dropdown-start` | Placement | Align to start of button (default) |
| `dropdown-center` | Placement | Align to center of button |
| `dropdown-end` | Placement | Align to end of button |
| `dropdown-top` | Placement | Open upward |
| `dropdown-bottom` | Placement | Open downward (default) |
| `dropdown-left` | Placement | Open to left |
| `dropdown-right` | Placement | Open to right |
| `dropdown-hover` | Behavior | Open on hover |
| `dropdown-open` | Behavior | Force open |
| `dropdown-close` | Behavior | Force close |

## Essential Examples

### Basic usage

```html
<div class="dropdown">
  <div tabindex="0" role="button" class="btn m-1">Click</div>
  <ul tabindex="0" class="dropdown-content menu bg-base-100 rounded-box z-1 w-52 p-2 shadow">
    <li><a>Item 1</a></li>
    <li><a>Item 2</a></li>
  </ul>
</div>
```

### Placement

```html
<!-- Top -->
<div class="dropdown dropdown-top">
  <div tabindex="0" role="button" class="btn">Top</div>
  <ul tabindex="0" class="dropdown-content menu bg-base-100 rounded-box z-1 w-52 p-2 shadow">
    <li><a>Item 1</a></li>
    <li><a>Item 2</a></li>
  </ul>
</div>

<!-- End aligned -->
<div class="dropdown dropdown-end">
  <div tabindex="0" role="button" class="btn">End</div>
  <ul tabindex="0" class="dropdown-content menu bg-base-100 rounded-box z-1 w-52 p-2 shadow">
    <li><a>Item 1</a></li>
    <li><a>Item 2</a></li>
  </ul>
</div>
```

### Hover activation

```html
<div class="dropdown dropdown-hover">
  <div tabindex="0" role="button" class="btn">Hover</div>
  <ul tabindex="0" class="dropdown-content menu bg-base-100 rounded-box z-1 w-52 p-2 shadow">
    <li><a>Item 1</a></li>
    <li><a>Item 2</a></li>
  </ul>
</div>
```

### Using details/summary

```html
<details class="dropdown">
  <summary class="btn m-1">Open or close</summary>
  <ul class="menu dropdown-content bg-base-100 rounded-box z-1 w-52 p-2 shadow">
    <li><a>Item 1</a></li>
    <li><a>Item 2</a></li>
  </ul>
</details>
```

### In navbar

```html
<div class="navbar bg-base-100">
  <div class="flex-1">
    <a class="btn btn-ghost text-xl">daisyUI</a>
  </div>
  <div class="flex-none">
    <div class="dropdown dropdown-end">
      <div tabindex="0" role="button" class="btn btn-ghost btn-circle avatar">
        <div class="w-10 rounded-full">
          <img alt="Avatar" src="avatar.jpg" />
        </div>
      </div>
      <ul tabindex="0" class="dropdown-content menu bg-base-100 rounded-box z-1 mt-3 w-52 p-2 shadow">
        <li><a>Profile</a></li>
        <li><a>Settings</a></li>
        <li><a>Logout</a></li>
      </ul>
    </div>
  </div>
</div>
```

## Notes

- Alternative: Use `<details>` + `<summary>` or Popover API
- Requires `tabindex="0"` for keyboard accessibility
