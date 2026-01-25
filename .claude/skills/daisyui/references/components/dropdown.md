# Dropdown

Dropdown menu component for displaying a list of options.

## Class Reference

| Class | Description |
|-------|-------------|
| `dropdown` | Container element |
| `dropdown-content` | Content container |
| `dropdown-end` | Align to end |
| `dropdown-top` | Open to top |
| `dropdown-bottom` | Open to bottom (default) |
| `dropdown-left` | Open to left |
| `dropdown-right` | Open to right |
| `dropdown-hover` | Open on hover instead of click |
| `dropdown-open` | Force open (for testing) |

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
