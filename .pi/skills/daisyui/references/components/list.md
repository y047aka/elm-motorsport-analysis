# List

Vertical flex layout for structured list rows with auto-growing columns.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `list` | Component | Vertical flex container for list rows |
| `list-row` | Component | Horizontal grid row inside a list; must be used inside `list` |
| `list-col-wrap` | Modifier | Forces a direct child of `list-row` to wrap to the next line |
| `list-col-grow` | Modifier | Makes a direct child of `list-row` fill remaining horizontal space |

## Essential Examples

### Basic usage

```html
<ul class="list bg-base-100 rounded-box shadow-md">
  <li class="list-row">
    <div>01</div>
    <div>Title</div>
    <button class="btn btn-ghost btn-square">
      <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
        <path fill-rule="evenodd" d="M10.293 3.293a1 1 0 011.414 0l6 6a1 1 0 010 1.414l-6 6a1 1 0 01-1.414-1.414L14.586 11H3a1 1 0 110-2h11.586l-4.293-4.293a1 1 0 010-1.414z" clip-rule="evenodd" />
      </svg>
    </button>
  </li>
</ul>
```

### With structure

```html
<!-- Custom grow target (third column grows instead of default second) -->
<ul class="list bg-base-100 rounded-box shadow-md">
  <li class="list-row">
    <div>01</div>
    <div><img src="image.jpg" class="h-12 w-12 rounded" /></div>
    <div class="list-col-grow">
      <p>Title</p>
      <p class="text-xs text-base-500">Subtitle</p>
    </div>
    <button class="btn btn-ghost btn-square">Action</button>
  </li>
</ul>

<!-- Wrapping column to next line -->
<ul class="list bg-base-100 rounded-box shadow-md">
  <li class="list-row">
    <div><img src="image.jpg" class="h-12 w-12 rounded" /></div>
    <div>Title</div>
    <p class="list-col-wrap text-xs">Description that wraps below the row</p>
    <button class="btn btn-ghost btn-square">Action</button>
  </li>
</ul>
```

## Notes

- **Required**: By default the second child in a `list-row` expands to fill available space; use `list-col-grow` on a different child to override this behavior
- **Required**: `list-col-wrap` and `list-col-grow` must be applied to direct children of `list-row`
