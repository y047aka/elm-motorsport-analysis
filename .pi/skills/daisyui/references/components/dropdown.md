# Dropdown

Menu component for displaying a list of options.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `dropdown` | Component | Container for button and content |
| `dropdown-content` | Part | Content container for dropdown menu |
| `dropdown-start` | Placement | Align dropdown to start of button |
| `dropdown-center` | Placement | Align dropdown to center of button |
| `dropdown-end` | Placement | Align dropdown to end of button |
| `dropdown-top` | Placement | Open dropdown upward |
| `dropdown-bottom` | Placement | Open downward (default) |
| `dropdown-left` | Placement | Open dropdown to left |
| `dropdown-right` | Placement | Open dropdown to right |
| `dropdown-hover` | Behavior | Open dropdown on hover instead of click |
| `dropdown-open` | Behavior | Force dropdown to be open |
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

### With structure

```html
<!-- Using details/summary (alternative approach) -->
<details class="dropdown">
  <summary class="btn m-1">Open or close</summary>
  <ul class="menu dropdown-content bg-base-100 rounded-box z-1 w-52 p-2 shadow">
    <li><a>Item 1</a></li>
    <li><a>Item 2</a></li>
  </ul>
</details>
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

## Notes

- **Required**: Use `tabindex="0"` on trigger and content for keyboard accessibility
- **Recommended**: Alternative implementations using `<details>` + `<summary>` or Popover API
- **Recommended**: Use `dropdown-hover` for hover activation instead of click
