# Mockup Browser

Browser window mockup for showcasing web content or screenshots.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `mockup-browser` | Component | Browser window container with toolbar dots |
| `mockup-browser-toolbar` | Part | Toolbar area containing the address bar (must be inside mockup-browser) |

## Essential Examples

### Basic usage

```html
<div class="mockup-browser border border-base-300 w-full">
  <div class="mockup-browser-toolbar">
    <div class="input">https://daisyui.com</div>
  </div>
  <div class="grid place-content-center border-t border-base-300 h-80">
    Hello!
  </div>
</div>
```

### With structure

```html
<!-- Content area without top border (background color fills gap) -->
<div class="mockup-browser border border-base-300 w-full">
  <div class="mockup-browser-toolbar">
    <div class="input">https://daisyui.com</div>
  </div>
  <div class="grid place-content-center h-80">
    Hello!
  </div>
</div>
```

## Notes

- **Required**: `mockup-browser-toolbar` must be placed as the first child inside `mockup-browser`
- **Recommended**: Use `border border-base-300` on the root for a clean frame appearance
- **Recommended**: Use `border-t border-base-300` on the content div when the root has a border, to visually separate toolbar from content
