# Breadcrumbs

Navigation component showing the current page's location in a hierarchy.

## Class Reference

| Class | Description |
|-------|-------------|
| `breadcrumbs` | Container element |

Note: Use Tailwind text utilities (`text-sm`, `text-xs`, etc.) for sizing.

## Key Examples

### Basic breadcrumbs

```html
<div class="breadcrumbs text-sm">
  <ul>
    <li><a>Home</a></li>
    <li><a>Documents</a></li>
    <li>Add Document</li>
  </ul>
</div>
```

### Breadcrumbs with icons

```html
<div class="breadcrumbs text-sm">
  <ul>
    <li>
      <a>
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class="h-4 w-4 stroke-current">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z"></path>
        </svg>
        Home
      </a>
    </li>
    <li>
      <a>
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class="h-4 w-4 stroke-current">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z"></path>
        </svg>
        Documents
      </a>
    </li>
    <li>Add Document</li>
  </ul>
</div>
```

### Different sizes

```html
<!-- Small -->
<div class="breadcrumbs text-sm">
  <ul>
    <li><a>Home</a></li>
    <li><a>Documents</a></li>
    <li>Current</li>
  </ul>
</div>

<!-- Large -->
<div class="breadcrumbs text-lg">
  <ul>
    <li><a>Home</a></li>
    <li><a>Documents</a></li>
    <li>Current</li>
  </ul>
</div>
```

### In navbar

```html
<div class="navbar bg-base-100">
  <div class="flex-1">
    <div class="breadcrumbs text-sm">
      <ul>
        <li><a>Home</a></li>
        <li><a>Products</a></li>
        <li>Category</li>
      </ul>
    </div>
  </div>
</div>
```

## Customization

### Custom separator (CSS)

```css
.breadcrumbs > ul > li + li:before {
  content: "→";
}
```
