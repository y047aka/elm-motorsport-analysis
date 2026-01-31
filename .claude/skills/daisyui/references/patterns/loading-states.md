# Loading States

**Components**: skeleton, card

Skeleton loading for cards and lists.

```html
<!-- Skeleton card -->
<div class="card w-96 bg-base-100 shadow">
  <figure class="skeleton h-48 w-full"></figure>
  <div class="card-body">
    <div class="skeleton h-6 w-3/4"></div>
    <div class="skeleton h-4 w-full"></div>
    <div class="skeleton h-4 w-2/3"></div>
    <div class="card-actions justify-end mt-4">
      <div class="skeleton h-10 w-24"></div>
    </div>
  </div>
</div>

<!-- Skeleton list -->
<div class="flex flex-col gap-4">
  <div class="flex items-center gap-4">
    <div class="skeleton h-12 w-12 shrink-0 rounded-full"></div>
    <div class="flex flex-col gap-2 flex-1">
      <div class="skeleton h-4 w-1/2"></div>
      <div class="skeleton h-3 w-3/4"></div>
    </div>
  </div>
</div>
```

## Common Skeleton Patterns

```html
<!-- Text block skeleton -->
<div class="space-y-2">
  <div class="skeleton h-4 w-full"></div>
  <div class="skeleton h-4 w-full"></div>
  <div class="skeleton h-4 w-3/4"></div>
</div>

<!-- Avatar with text skeleton -->
<div class="flex items-center gap-4">
  <div class="skeleton h-16 w-16 rounded-full"></div>
  <div class="flex flex-col gap-2">
    <div class="skeleton h-4 w-32"></div>
    <div class="skeleton h-3 w-24"></div>
  </div>
</div>

<!-- Button skeleton -->
<div class="skeleton h-12 w-32 rounded-btn"></div>
```

## Usage Notes

- Match skeleton dimensions to actual content for smooth transitions
- Use `rounded-full` for circular skeletons (avatars)
- Use `rounded-btn` for button skeletons
- Apply width utilities (`w-1/2`, `w-3/4`, etc.) for varied line lengths
- Skeleton has built-in animation effect

## Related Components

- [Skeleton](../components/skeleton.md)
- [Card](../components/card.md)
- [Loading](../components/loading.md)
