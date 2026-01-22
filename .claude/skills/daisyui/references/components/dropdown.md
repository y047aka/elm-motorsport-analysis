# Dropdown

Dropdown menu component for displaying a list of options.

## Basic Usage

```html
<div class="dropdown">
  <div tabindex="0" role="button" class="btn m-1">Click</div>
  <ul tabindex="0" class="dropdown-content menu bg-base-100 rounded-box z-1 w-52 p-2 shadow">
    <li><a>Item 1</a></li>
    <li><a>Item 2</a></li>
  </ul>
</div>
```

## Dropdown Positions

```html
<!-- Bottom (default) -->
<div class="dropdown dropdown-bottom">...</div>

<!-- Top -->
<div class="dropdown dropdown-top">...</div>

<!-- Left -->
<div class="dropdown dropdown-left">...</div>

<!-- Right -->
<div class="dropdown dropdown-right">...</div>
```

## Alignment

```html
<!-- End aligned -->
<div class="dropdown dropdown-end">...</div>

<!-- Top end aligned -->
<div class="dropdown dropdown-top dropdown-end">...</div>
```

## Hover Activation

```html
<div class="dropdown dropdown-hover">
  <div tabindex="0" role="button" class="btn m-1">Hover</div>
  <ul tabindex="0" class="dropdown-content menu bg-base-100 rounded-box z-1 w-52 p-2 shadow">
    <li><a>Item 1</a></li>
    <li><a>Item 2</a></li>
  </ul>
</div>
```

## Force Open

```html
<div class="dropdown dropdown-open">
  <div tabindex="0" role="button" class="btn m-1">Open</div>
  <ul tabindex="0" class="dropdown-content menu bg-base-100 rounded-box z-1 w-52 p-2 shadow">
    <li><a>Item 1</a></li>
    <li><a>Item 2</a></li>
  </ul>
</div>
```

## With Card Content

```html
<div class="dropdown">
  <div tabindex="0" role="button" class="btn m-1">Click</div>
  <div tabindex="0" class="dropdown-content card card-compact bg-primary text-primary-content z-1 w-64 p-2 shadow">
    <div class="card-body">
      <h3 class="card-title">Card title!</h3>
      <p>you can use any element as a dropdown.</p>
    </div>
  </div>
</div>
```

## In Navbar

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

## Helper Dropdown

```html
<div class="dropdown dropdown-end">
  <div tabindex="0" role="button" class="btn btn-circle btn-ghost btn-xs text-info">
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class="h-4 w-4 stroke-current">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
    </svg>
  </div>
  <div tabindex="0" class="dropdown-content card card-compact bg-base-100 z-1 w-64 shadow">
    <div class="card-body">
      <p>Help information here</p>
    </div>
  </div>
</div>
```

## Classes Reference

| Class | Description |
|-------|-------------|
| `dropdown` | Container element |
| `dropdown-content` | Content container |
| `dropdown-end` | Aligns to end |
| `dropdown-top` | Opens to top |
| `dropdown-bottom` | Opens to bottom (default) |
| `dropdown-left` | Opens to left |
| `dropdown-right` | Opens to right |
| `dropdown-hover` | Opens on hover |
| `dropdown-open` | Force open |
