# Join

Container for grouping multiple items with seamless borders and shared border radius.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `join` | Component | Container that groups items and applies border radius to first and last item |
| `join-item` | Component | Individual item inside a join container; must be a direct or nested child of `join` |
| `join-vertical` | direction | Stacks items vertically |
| `join-horizontal` | direction | Arranges items horizontally (default) |

## Essential Examples

### Basic usage

```html
<div class="join">
  <button class="btn join-item">Button</button>
  <button class="btn join-item">Button</button>
  <button class="btn join-item">Button</button>
</div>
```

### With structure

```html
<!-- Vertical layout -->
<div class="join join-vertical">
  <button class="btn join-item">Button</button>
  <button class="btn join-item">Button</button>
  <button class="btn join-item">Button</button>
</div>

<!-- Mixed content types -->
<div class="join">
  <input class="input join-item" placeholder="Search" />
  <select class="select join-item">
    <option>Filter</option>
  </select>
  <button class="btn join-item">Search</button>
</div>
```

## Notes

- **Required**: Each child element must have the `join-item` class applied
- **Recommended**: Use `join-vertical lg:join-horizontal` for responsive layouts that switch direction at breakpoints
