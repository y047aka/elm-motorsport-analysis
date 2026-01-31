# Pagination

Page navigation built with the join component and buttons to navigate between content sets.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `join` | Component | Container that groups pagination items with connected borders |
| `join-item` | Part | Individual pagination element wrapper (must be inside join) |
| `join-vertical` | Modifier | Arranges items in vertical layout |
| `join-horizontal` | Modifier | Arranges items in horizontal layout (default) |

## Essential Examples

### Basic usage

```html
<div class="join">
  <button class="join-item btn">1</button>
  <button class="join-item btn btn-active">2</button>
  <button class="join-item btn">3</button>
  <button class="join-item btn">4</button>
</div>
```

### With structure

```html
<!-- Navigation with prev/next and ellipsis -->
<div class="join">
  <button class="join-item btn">«</button>
  <button class="join-item btn">1</button>
  <button class="join-item btn btn-disabled">...</button>
  <button class="join-item btn btn-active">22</button>
  <button class="join-item btn btn-disabled">...</button>
  <button class="join-item btn">100</button>
  <button class="join-item btn">»</button>
</div>
```

### Interactive

```html
<!-- Radio input pagination (browser handles mutual exclusion) -->
<div class="join">
  <input class="join-item btn btn-square" type="radio" name="pages" aria-label="1" checked />
  <input class="join-item btn btn-square" type="radio" name="pages" aria-label="2" />
  <input class="join-item btn btn-square" type="radio" name="pages" aria-label="3" />
  <input class="join-item btn btn-square" type="radio" name="pages" aria-label="4" />
</div>
```

## Notes

- **Required**: Pagination has no dedicated `pagination` class -- it is composed from `join` + `btn` + `btn-active`
- **Recommended**: Use `btn-square` on radio input pagination items for consistent sizing
- **Recommended**: Use `aria-label` on radio inputs since they have no visible text content
- **Recommended**: Use `btn-disabled` class (not the `disabled` attribute) for ellipsis placeholder buttons to maintain visual consistency
