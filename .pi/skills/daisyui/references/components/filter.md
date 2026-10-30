# Filter

A group of radio buttons where choosing one option visually deselects the others, with optional reset functionality.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `filter` | Component | Container for radio button or checkbox filter group |
| `filter-reset` | Part | Alternative reset button when HTML form element is not used |

## Essential Examples

### Basic usage

```html
<form class="filter">
  <input class="btn btn-square" type="reset" value="&times;" />
  <input class="btn" type="radio" name="frameworks" aria-label="Svelte" />
  <input class="btn" type="radio" name="frameworks" aria-label="Vue" />
  <input class="btn" type="radio" name="frameworks" aria-label="React" />
</form>
```

### With structure

```html
<!-- Without form element: use filter-reset instead of type="reset" -->
<div class="filter">
  <input class="btn filter-reset" type="radio" name="metaframeworks" aria-label="All" />
  <input class="btn" type="radio" name="metaframeworks" aria-label="Sveltekit" />
  <input class="btn" type="radio" name="metaframeworks" aria-label="Nuxt" />
  <input class="btn" type="radio" name="metaframeworks" aria-label="Next.js" />
</div>
```

## Notes

- **Required**: When using `<form>` element, use `<input type="reset">` for the clear button. When not using a form, apply `filter-reset` class to a radio input instead
- **Recommended**: Use `aria-label` on radio inputs when no visible text label is present
- **Recommended**: All radio inputs in a filter group must share the same `name` attribute
