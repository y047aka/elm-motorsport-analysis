# Text Rotate

Animated text rotation showing multiple lines in an infinite loop. Default duration is 10 seconds per cycle.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `text-rotate` | Component | Wrapper for rotating text animation |

## Essential Examples

### Basic usage

```html
<span class="text-rotate">
  <span>
    <span>First text</span>
    <span>Second text</span>
    <span>Third text</span>
  </span>
</span>
```

### With styling

```html
<span class="text-rotate text-4xl">
  <span>
    <span class="bg-primary text-primary-content px-2">Hello</span>
    <span class="bg-secondary text-secondary-content px-2">World</span>
    <span class="bg-accent text-accent-content px-2">Welcome</span>
  </span>
</span>
```

### Custom duration

```html
<span class="text-rotate duration-6000">
  <span>
    <span>Line 1</span>
    <span>Line 2</span>
    <span>Line 3</span>
  </span>
</span>
```

### Centered with custom line height

```html
<span class="text-rotate justify-items-center leading-[2]">
  <span>
    <span>Centered text 1</span>
    <span>Centered text 2</span>
    <span>Centered text 3</span>
  </span>
</span>
```

### In a heading

```html
<h1 class="text-3xl font-bold">
  We provide
  <span class="text-rotate text-primary">
    <span>
      <span>solutions</span>
      <span>services</span>
      <span>support</span>
    </span>
  </span>
</h1>
```

## Notes

- **Required**: Three-level nested span structure (outer → middle → text items)
- **Required**: Maximum 6 text items supported
- **Behavior**: Animation pauses on hover
- **Default**: 10 second duration per full cycle
- **Recommended**: Use `duration-*` utilities for custom timing (e.g., `duration-6000`)
- **Recommended**: Use `justify-items-center` for horizontal centering
- **Recommended**: Use `leading-*` utilities for custom line height
