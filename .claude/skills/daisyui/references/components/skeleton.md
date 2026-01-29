# Skeleton

Loading placeholder with pulsing animation for content that has not yet loaded.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `skeleton` | Component | Pulsing placeholder div |
| `skeleton-text` | Modifier | Animates text color instead of background (for inline text placeholders) |

## Essential Examples

### Basic usage

```html
<div class="skeleton h-32 w-32"></div>
```

### With structure

```html
<div class="flex w-52 flex-col gap-4">
  <div class="flex items-center gap-4">
    <div class="skeleton h-16 w-16 shrink-0 rounded-full"></div>
    <div class="flex flex-col gap-4">
      <div class="skeleton h-4 w-20"></div>
      <div class="skeleton h-4 w-28"></div>
    </div>
  </div>
  <div class="skeleton h-32 w-full"></div>
</div>
```

### Text placeholder

```html
<span class="skeleton skeleton-text">AI is thinking harder...</span>
```

## Notes

- **Recommended**: Use Tailwind sizing utilities (`h-*`, `w-*`) to match the dimensions of the content being loaded
- **Recommended**: Use `rounded-full` for avatar placeholders, `rounded-box` or `rounded-lg` for card placeholders
- **Recommended**: Use `skeleton-text` for inline text loading states where the placeholder wraps around existing text content
