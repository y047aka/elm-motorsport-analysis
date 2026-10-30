# Mockup Phone

Phone device mockup with camera notch and display area.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `mockup-phone` | Component | Phone device container with rounded frame |
| `mockup-phone-camera` | Part | Camera notch element at the top (must be inside mockup-phone) |
| `mockup-phone-display` | Part | Screen display area for content (must be inside mockup-phone) |

## Essential Examples

### Basic usage

```html
<div class="mockup-phone">
  <div class="mockup-phone-camera"></div>
  <div class="mockup-phone-display">
    Hello!
  </div>
</div>
```

### With structure

```html
<!-- Phone with styled display content -->
<div class="mockup-phone">
  <div class="mockup-phone-camera"></div>
  <div class="mockup-phone-display text-white grid place-content-center bg-neutral-900">
    It's Glowtime.
  </div>
</div>
```

## Notes

- **Required**: `mockup-phone-camera` must appear before `mockup-phone-display` inside `mockup-phone`
- **Required**: `mockup-phone-display` must be present for content rendering
- **Recommended**: Use `border-{color}` Tailwind utilities to customize the phone frame color
- **Recommended**: Place `<img>` inside `mockup-phone-display` for wallpaper or screenshot previews
