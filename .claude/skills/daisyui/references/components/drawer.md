# Drawer

Sidebar component controlled by a hidden checkbox.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `drawer` | Component | Wrapper for sidebar and content |
| `drawer-toggle` | Part | Hidden checkbox controlling state |
| `drawer-content` | Part | Main content area |
| `drawer-side` | Part | Sidebar area |
| `drawer-overlay` | Part | Overlay covering page when open |
| `drawer-end` | Placement | Position drawer on right side |
| `drawer-open` | Modifier | Force drawer open |
| `is-drawer-open:` | Variant | Apply styles when open |
| `is-drawer-close:` | Variant | Apply styles when closed |

## Essential Examples

### Basic drawer

```html
<div class="drawer">
  <input id="my-drawer" type="checkbox" class="drawer-toggle" />
  <div class="drawer-content">
    <label for="my-drawer" class="btn btn-primary">Open drawer</label>
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

### Responsive drawer (mobile overlay, desktop persistent)

```html
<div class="drawer lg:drawer-open">
  <input id="my-drawer-2" type="checkbox" class="drawer-toggle" />
  <div class="drawer-content flex flex-col">
    <label for="my-drawer-2" class="btn btn-primary drawer-button lg:hidden">
      Open drawer
    </label>
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

## Notes

- Controlled via checkbox: Use matching IDs on `<input>` and `<label>`
- Position: Add `drawer-end` for right-side drawer
- Responsive: Use `lg:drawer-open` for persistent desktop sidebar
- Variants: `is-drawer-open:` and `is-drawer-close:` for conditional styling
