# Avatar

Displays a user image or placeholder with optional status indicators.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `avatar` | Component | Container for avatar content |
| `avatar-group` | Component | Groups multiple avatars with overlap |
| `avatar-online` | Modifier | Displays green online status indicator dot |
| `avatar-offline` | Modifier | Displays gray offline status indicator dot |
| `avatar-placeholder` | Modifier | Enables text-based avatar display without image |

## Essential Examples

### Basic usage

```html
<div class="avatar">
  <div class="w-24 rounded-full">
    <img src="https://daisyui.com/images/stock/photo-1494902139d2f4c60493a71d0dde18341831973-320w.webp" />
  </div>
</div>
```

### With structure

```html
<!-- Avatar group with overlap -->
<div class="avatar-group -space-x-6">
  <div class="avatar">
    <div class="w-12 rounded-full">
      <img src="image1.jpg" />
    </div>
  </div>
  <div class="avatar">
    <div class="w-12 rounded-full">
      <img src="image2.jpg" />
    </div>
  </div>
  <div class="avatar">
    <div class="w-12 rounded-full">
      <img src="image3.jpg" />
    </div>
  </div>
</div>

<!-- Text placeholder avatar -->
<div class="avatar avatar-placeholder">
  <div class="bg-neutral text-neutral-content w-24 rounded-full">
    <span class="text-3xl">AB</span>
  </div>
</div>
```

### With status indicator

```html
<div class="avatar avatar-online">
  <div class="w-24 rounded-full">
    <img src="https://daisyui.com/images/stock/photo-1494902139d2f4c60493a71d0dde18341831973-320w.webp" />
  </div>
</div>

<div class="avatar avatar-offline">
  <div class="w-24 rounded-full">
    <img src="https://daisyui.com/images/stock/photo-1494902139d2f4c60493a71d0dde18341831973-320w.webp" />
  </div>
</div>
```

## Notes

- **Recommended**: Size is controlled via Tailwind width utilities (`w-8`, `w-12`, `w-24`, `w-32`) on the inner wrapper div, not on the avatar class itself
- **Recommended**: Shape is controlled via Tailwind border-radius utilities (`rounded`, `rounded-xl`, `rounded-full`) on the inner wrapper div
- **Recommended**: Use negative spacing (`-space-x-6`) on `avatar-group` to create the overlap effect
- **Recommended**: Use `ring` and `ring-offset` Tailwind utilities for avatar borders
- **Recommended**: Use `bg-{color} text-{color}-content` for placeholder avatars
- **Deprecated since v5**: `.avatar .online` → `avatar-online`, `.avatar .offline` → `avatar-offline`, `.avatar .placeholder` → `avatar-placeholder`
