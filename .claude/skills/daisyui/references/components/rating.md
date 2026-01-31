# Rating

Star rating component using masked radio inputs or read-only div elements.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `rating` | Component | Container for rating radio inputs or divs |
| `rating-half` | Modifier | Enables half-star increments (requires `mask-half-1` / `mask-half-2` pattern) |
| `rating-hidden` | Modifier | Hides a radio input (provides reset/clear functionality as the first option in rating groups) |
| `rating-xs` | Size | Extra small |
| `rating-sm` | Size | Small |
| `rating-md` | Size | Medium (default) |
| `rating-lg` | Size | Large |
| `rating-xl` | Size | Extra large |

## Essential Examples

### Basic usage

```html
<div class="rating">
  <input type="radio" name="rating-1" class="mask mask-star" aria-label="1 star" />
  <input type="radio" name="rating-1" class="mask mask-star" aria-label="2 star" checked />
  <input type="radio" name="rating-1" class="mask mask-star" aria-label="3 star" />
  <input type="radio" name="rating-1" class="mask mask-star" aria-label="4 star" />
  <input type="radio" name="rating-1" class="mask mask-star" aria-label="5 star" />
</div>
```

### Half-star rating

```html
<div class="rating rating-half">
  <input type="radio" name="rating-2" class="rating-hidden" />
  <input type="radio" name="rating-2" class="mask mask-star-2 mask-half-1 bg-orange-400" aria-label="0.5 star" />
  <input type="radio" name="rating-2" class="mask mask-star-2 mask-half-2 bg-orange-400" aria-label="1 star" />
  <input type="radio" name="rating-2" class="mask mask-star-2 mask-half-1 bg-orange-400" aria-label="1.5 star" checked />
  <input type="radio" name="rating-2" class="mask mask-star-2 mask-half-2 bg-orange-400" aria-label="2 star" />
  <input type="radio" name="rating-2" class="mask mask-star-2 mask-half-1 bg-orange-400" aria-label="2.5 star" />
  <input type="radio" name="rating-2" class="mask mask-star-2 mask-half-2 bg-orange-400" aria-label="3 star" />
  <input type="radio" name="rating-2" class="mask mask-star-2 mask-half-1 bg-orange-400" aria-label="3.5 star" />
  <input type="radio" name="rating-2" class="mask mask-star-2 mask-half-2 bg-orange-400" aria-label="4 star" />
  <input type="radio" name="rating-2" class="mask mask-star-2 mask-half-1 bg-orange-400" aria-label="4.5 star" />
  <input type="radio" name="rating-2" class="mask mask-star-2 mask-half-2 bg-orange-400" aria-label="5 star" />
</div>
```

### Read-only rating

```html
<div class="rating">
  <div class="mask mask-star" aria-label="1 star"></div>
  <div class="mask mask-star" aria-label="2 star"></div>
  <div class="mask mask-star" aria-label="3 star" aria-current="true"></div>
  <div class="mask mask-star" aria-label="4 star"></div>
  <div class="mask mask-star" aria-label="5 star"></div>
</div>
```

## Notes

- **Required**: Each rating group must use a unique `name` attribute to avoid conflicts with other ratings on the same page
- **Required**: Half-star pattern alternates `mask-half-1` and `mask-half-2` classes on consecutive inputs; the first `rating-hidden` input enables clearing the selection
- **Recommended**: Use `aria-label` on each input for accessibility; use `aria-current="true"` on the selected div in read-only mode
- **Recommended**: Use `mask-heart` instead of `mask-star` for heart-shaped ratings
