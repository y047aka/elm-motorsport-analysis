# Mockup Window

OS desktop window mockup with title bar dots.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `mockup-window` | Component | Desktop window container with title bar traffic-light dots |

## Essential Examples

### Basic usage

```html
<div class="mockup-window border border-base-300 w-full">
  <div class="grid place-content-center border-t border-base-300 h-80">
    Hello!
  </div>
</div>
```

### With structure

```html
<!-- Window with background color (no border-t needed on content) -->
<div class="mockup-window bg-base-100 border border-base-300 w-full">
  <div class="grid place-content-center h-80">
    Hello!
  </div>
</div>
```

## Notes

- **Required**: Use `border` and `border-base-300` for the window frame
- **Recommended**: Use `border-t` and `border-base-300` to separate the toolbar from content
- **Recommended**: Use `bg-base-100` for the content area background
