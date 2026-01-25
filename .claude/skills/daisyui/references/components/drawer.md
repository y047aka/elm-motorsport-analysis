# Drawer

Sidebar component for navigation. The drawer is a wrapper for sidebar and content, controlled by a hidden checkbox.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `drawer` | Component | The wrapper for sidebar and content |
| `drawer-toggle` | Part | The hidden checkbox that controls the state of drawer |
| `drawer-content` | Part | Content part |
| `drawer-side` | Part | Sidebar part |
| `drawer-overlay` | Part | Label that covers the page when drawer is open |
| `drawer-end` | Placement | Puts drawer to the other side |
| `drawer-open` | Modifier | Forces the drawer to be open |
| `is-drawer-open:` | Variant | Applies styles when the drawer is open |
| `is-drawer-close:` | Variant | Applies styles when the drawer is closed |

## Key Examples

### Basic drawer

```html
<div class="drawer">
  <input id="my-drawer" type="checkbox" class="drawer-toggle" />
  <div class="drawer-content">
    <!-- Page content -->
    <label for="my-drawer" class="btn btn-primary drawer-button">Open drawer</label>
  </div>
  <div class="drawer-side">
    <label for="my-drawer" aria-label="close sidebar" class="drawer-overlay"></label>
    <ul class="menu bg-base-200 text-base-content min-h-full w-80 p-4">
      <li><a>Sidebar Item 1</a></li>
      <li><a>Sidebar Item 2</a></li>
    </ul>
  </div>
</div>
```

### Drawer on right side

```html
<div class="drawer drawer-end">
  <input id="my-drawer-end" type="checkbox" class="drawer-toggle" />
  <div class="drawer-content">
    <label for="my-drawer-end" class="btn btn-primary">Open drawer</label>
  </div>
  <div class="drawer-side">
    <label for="my-drawer-end" class="drawer-overlay"></label>
    <ul class="menu bg-base-200 min-h-full w-80 p-4">
      <li><a>Sidebar Item 1</a></li>
      <li><a>Sidebar Item 2</a></li>
    </ul>
  </div>
</div>
```

### Responsive drawer (mobile hidden, desktop visible)

```html
<div class="drawer lg:drawer-open">
  <input id="my-drawer-2" type="checkbox" class="drawer-toggle" />
  <div class="drawer-content flex flex-col">
    <!-- Mobile menu button -->
    <label for="my-drawer-2" class="btn btn-primary drawer-button lg:hidden">
      Open drawer
    </label>
    <!-- Page content -->
    <div class="p-4">Content</div>
  </div>
  <div class="drawer-side">
    <label for="my-drawer-2" class="drawer-overlay"></label>
    <ul class="menu bg-base-200 min-h-full w-80 p-4">
      <li><a>Sidebar Item 1</a></li>
      <li><a>Sidebar Item 2</a></li>
    </ul>
  </div>
</div>
```

### With navbar

```html
<div class="drawer">
  <input id="my-drawer-3" type="checkbox" class="drawer-toggle" />
  <div class="drawer-content flex flex-col">
    <!-- Navbar -->
    <div class="navbar bg-base-300 w-full">
      <div class="flex-none lg:hidden">
        <label for="my-drawer-3" class="btn btn-square btn-ghost">
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class="inline-block h-6 w-6 stroke-current">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"></path>
          </svg>
        </label>
      </div>
      <div class="mx-2 flex-1 px-2">Navbar Title</div>
    </div>
    <!-- Page content -->
    <div class="p-4">Content</div>
  </div>
  <div class="drawer-side">
    <label for="my-drawer-3" class="drawer-overlay"></label>
    <ul class="menu bg-base-200 min-h-full w-80 p-4">
      <li><a>Sidebar Item 1</a></li>
      <li><a>Sidebar Item 2</a></li>
    </ul>
  </div>
</div>
```

### With custom sidebar content

```html
<div class="drawer lg:drawer-open">
  <input id="my-drawer-4" type="checkbox" class="drawer-toggle" />
  <div class="drawer-content p-4">
    <label for="my-drawer-4" class="btn btn-primary drawer-button lg:hidden mb-4">
      Open drawer
    </label>
    <h1>Main Content</h1>
  </div>
  <div class="drawer-side">
    <label for="my-drawer-4" class="drawer-overlay"></label>
    <div class="bg-base-200 min-h-full w-80 p-4">
      <!-- User profile -->
      <div class="flex items-center gap-4 mb-6">
        <div class="avatar">
          <div class="w-12 rounded-full">
            <img src="avatar.jpg" />
          </div>
        </div>
        <div>
          <div class="font-bold">John Doe</div>
          <div class="text-sm opacity-60">Admin</div>
        </div>
      </div>
      
      <!-- Navigation -->
      <ul class="menu">
        <li class="menu-title">Main</li>
        <li><a>Dashboard</a></li>
        <li><a>Analytics</a></li>
      </ul>
    </div>
  </div>
</div>
```

### State-based styling with variants

```html
<div class="drawer">
  <input id="my-drawer-5" type="checkbox" class="drawer-toggle" />
  <div class="drawer-content">
    <label for="my-drawer-5" class="btn is-drawer-open:hidden">Open</label>
    <label for="my-drawer-5" class="btn is-drawer-close:hidden">Close</label>
  </div>
  <div class="drawer-side">
    <label for="my-drawer-5" class="drawer-overlay"></label>
    <div class="bg-base-200 min-h-full w-80 is-drawer-open:w-64 p-4">
      Sidebar content
    </div>
  </div>
</div>
```
