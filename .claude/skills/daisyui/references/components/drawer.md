# Drawer

Sidebar component for navigation, typically hidden on mobile.

## Basic Usage

```html
<div class="drawer">
  <input id="my-drawer" type="checkbox" class="drawer-toggle" />
  <div class="drawer-content">
    <!-- Page content here -->
    <label for="my-drawer" class="btn btn-primary drawer-button">Open drawer</label>
  </div>
  <div class="drawer-side">
    <label for="my-drawer" aria-label="close sidebar" class="drawer-overlay"></label>
    <ul class="menu bg-base-200 text-base-content min-h-full w-80 p-4">
      <!-- Sidebar content here -->
      <li><a>Sidebar Item 1</a></li>
      <li><a>Sidebar Item 2</a></li>
    </ul>
  </div>
</div>
```

## Drawer on Right Side

```html
<div class="drawer drawer-end">
  <input id="my-drawer-end" type="checkbox" class="drawer-toggle" />
  <div class="drawer-content">
    <label for="my-drawer-end" class="btn btn-primary drawer-button">Open drawer</label>
  </div>
  <div class="drawer-side">
    <label for="my-drawer-end" aria-label="close sidebar" class="drawer-overlay"></label>
    <ul class="menu bg-base-200 text-base-content min-h-full w-80 p-4">
      <li><a>Sidebar Item 1</a></li>
      <li><a>Sidebar Item 2</a></li>
    </ul>
  </div>
</div>
```

## Responsive Drawer

```html
<div class="drawer lg:drawer-open">
  <input id="my-drawer-2" type="checkbox" class="drawer-toggle" />
  <div class="drawer-content flex flex-col items-center justify-center">
    <!-- Page content here -->
    <label for="my-drawer-2" class="btn btn-primary drawer-button lg:hidden">
      Open drawer
    </label>
  </div>
  <div class="drawer-side">
    <label for="my-drawer-2" aria-label="close sidebar" class="drawer-overlay"></label>
    <ul class="menu bg-base-200 text-base-content min-h-full w-80 p-4">
      <li><a>Sidebar Item 1</a></li>
      <li><a>Sidebar Item 2</a></li>
    </ul>
  </div>
</div>
```

## With Navbar

```html
<div class="drawer">
  <input id="my-drawer-3" type="checkbox" class="drawer-toggle" />
  <div class="drawer-content flex flex-col">
    <!-- Navbar -->
    <div class="navbar bg-base-300 w-full">
      <div class="flex-none lg:hidden">
        <label for="my-drawer-3" aria-label="open sidebar" class="btn btn-square btn-ghost">
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class="inline-block h-6 w-6 stroke-current">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"></path>
          </svg>
        </label>
      </div>
      <div class="mx-2 flex-1 px-2">Navbar Title</div>
      <div class="hidden flex-none lg:block">
        <ul class="menu menu-horizontal">
          <li><a>Navbar Item 1</a></li>
          <li><a>Navbar Item 2</a></li>
        </ul>
      </div>
    </div>
    <!-- Page content here -->
    <div class="p-4">Content</div>
  </div>
  <div class="drawer-side">
    <label for="my-drawer-3" aria-label="close sidebar" class="drawer-overlay"></label>
    <ul class="menu bg-base-200 min-h-full w-80 p-4">
      <li><a>Sidebar Item 1</a></li>
      <li><a>Sidebar Item 2</a></li>
    </ul>
  </div>
</div>
```

## With Full-Height Sidebar

```html
<div class="drawer lg:drawer-open">
  <input id="my-drawer-4" type="checkbox" class="drawer-toggle" />
  <div class="drawer-content">
    <!-- Page content here -->
    <div class="p-4">
      <label for="my-drawer-4" class="btn btn-primary drawer-button lg:hidden">
        Open drawer
      </label>
      <h1 class="text-2xl font-bold mt-4">Page Content</h1>
      <p>Your page content goes here...</p>
    </div>
  </div>
  <div class="drawer-side">
    <label for="my-drawer-4" aria-label="close sidebar" class="drawer-overlay"></label>
    <aside class="bg-base-200 min-h-full w-80">
      <div class="p-4 text-xl font-bold">Brand</div>
      <ul class="menu p-4 pt-0">
        <li><a class="active">Dashboard</a></li>
        <li><a>Projects</a></li>
        <li><a>Tasks</a></li>
        <li><a>Settings</a></li>
      </ul>
    </aside>
  </div>
</div>
```

## Force Open (for testing)

```html
<div class="drawer drawer-open">
  <input id="my-drawer-open" type="checkbox" class="drawer-toggle" />
  <div class="drawer-content">
    <p>Drawer is always open</p>
  </div>
  <div class="drawer-side">
    <label for="my-drawer-open" class="drawer-overlay"></label>
    <ul class="menu bg-base-200 min-h-full w-80 p-4">
      <li><a>Sidebar Item 1</a></li>
    </ul>
  </div>
</div>
```

## With Custom Sidebar Content

```html
<div class="drawer lg:drawer-open">
  <input id="my-drawer-5" type="checkbox" class="drawer-toggle" />
  <div class="drawer-content p-4">
    <label for="my-drawer-5" class="btn btn-primary drawer-button lg:hidden mb-4">
      Open drawer
    </label>
    <h1>Main Content</h1>
  </div>
  <div class="drawer-side">
    <label for="my-drawer-5" class="drawer-overlay"></label>
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
        <li class="menu-title">Settings</li>
        <li><a>Account</a></li>
        <li><a>Preferences</a></li>
      </ul>
    </div>
  </div>
</div>
```

## Classes Reference

| Class | Description |
|-------|-------------|
| `drawer` | Container element |
| `drawer-toggle` | Hidden checkbox for toggle |
| `drawer-content` | Main content container |
| `drawer-side` | Sidebar container |
| `drawer-overlay` | Overlay behind sidebar |
| `drawer-button` | Button styling (optional) |
| `drawer-end` | Position drawer on right |
| `drawer-open` | Force drawer open |
| `lg:drawer-open` | Open on large screens |
