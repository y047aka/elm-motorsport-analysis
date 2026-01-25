# Dropdown

Dropdown menu component for displaying a list of options. Supports multiple implementation methods including CSS focus, Popover API, and details/summary.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `dropdown` | Component | Container for dropdown button and content |
| `dropdown-content` | Part | Content part that contains the dropdown menu |
| `dropdown-start` | Placement | Align horizontally to start of button (default) |
| `dropdown-center` | Placement | Align horizontally to center of button |
| `dropdown-end` | Placement | Align horizontally to end of button |
| `dropdown-top` | Placement | Open from top |
| `dropdown-bottom` | Placement | Open from bottom (default) |
| `dropdown-left` | Placement | Open from left |
| `dropdown-right` | Placement | Open from right |
| `dropdown-hover` | Behavior | Opens on hover too |
| `dropdown-open` | Behavior | Force open |
| `dropdown-close` | Behavior | Force close |

## Key Examples

### Basic dropdown

```html
<div class="dropdown">
  <div tabindex="0" role="button" class="btn m-1">Click</div>
  <ul tabindex="0" class="dropdown-content menu bg-base-100 rounded-box z-1 w-52 p-2 shadow">
    <li><a>Item 1</a></li>
    <li><a>Item 2</a></li>
  </ul>
</div>
```

### Position variants

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

<!-- Top + End combined -->
<div class="dropdown dropdown-top dropdown-end">
  <div tabindex="0" role="button" class="btn">Top End</div>
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

### With card content

```html
<div class="dropdown">
  <div tabindex="0" role="button" class="btn">Click</div>
  <div tabindex="0" class="dropdown-content card card-compact bg-primary text-primary-content z-1 w-64 p-2 shadow">
    <div class="card-body">
      <h3 class="card-title">Card title!</h3>
      <p>Any element can be a dropdown.</p>
    </div>
  </div>
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

### Using Popover API

```html
<button class="btn" popovertarget="popover-1" style="anchor-name:--anchor-1">Click</button>
<ul class="dropdown menu bg-base-100 rounded-box z-1 w-52 p-2 shadow" popover id="popover-1" style="position-anchor:--anchor-1">
  <li><a>Item 1</a></li>
  <li><a>Item 2</a></li>
</ul>
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
