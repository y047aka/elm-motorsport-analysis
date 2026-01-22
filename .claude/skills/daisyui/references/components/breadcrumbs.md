# Breadcrumbs

Navigation component showing the current page's location in a hierarchy.

## Basic Usage

```html
<div class="breadcrumbs text-sm">
  <ul>
    <li><a>Home</a></li>
    <li><a>Documents</a></li>
    <li>Add Document</li>
  </ul>
</div>
```

## With Icons

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
    <li>
      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class="h-4 w-4 stroke-current">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 13h6m-3-3v6m5 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
      </svg>
      Add Document
    </li>
  </ul>
</div>
```

## Long Path

```html
<div class="breadcrumbs text-sm">
  <ul>
    <li><a>Home</a></li>
    <li><a>Documents</a></li>
    <li><a>Folder</a></li>
    <li><a>Subfolder</a></li>
    <li><a>Another Folder</a></li>
    <li>Current Page</li>
  </ul>
</div>
```

## Max Width with Ellipsis

```html
<div class="breadcrumbs text-sm max-w-xs">
  <ul>
    <li><a>Home</a></li>
    <li><a>This is a very long folder name</a></li>
    <li>Current Page</li>
  </ul>
</div>
```

## Sizes

```html
<!-- Extra small -->
<div class="breadcrumbs text-xs">
  <ul>
    <li><a>Home</a></li>
    <li><a>Documents</a></li>
    <li>Current</li>
  </ul>
</div>

<!-- Small -->
<div class="breadcrumbs text-sm">
  <ul>
    <li><a>Home</a></li>
    <li><a>Documents</a></li>
    <li>Current</li>
  </ul>
</div>

<!-- Medium -->
<div class="breadcrumbs text-base">
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

## Custom Separator

You can customize the separator using CSS:

```css
.breadcrumbs > ul > li + li:before {
  content: "→";
}
```

## In Navbar

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

## With Different Link States

```html
<div class="breadcrumbs text-sm">
  <ul>
    <li><a class="link link-hover">Home</a></li>
    <li><a class="link link-hover">Documents</a></li>
    <li class="text-primary">Current Page</li>
  </ul>
</div>
```

## Classes Reference

| Class | Description |
|-------|-------------|
| `breadcrumbs` | Container element |

Note: Breadcrumbs use standard text utility classes for sizing (`text-sm`, `text-xs`, etc.).
