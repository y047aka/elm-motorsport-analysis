# Stack

Layered layout utility that places children on top of each other with optional alignment.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `stack` | Component | Container that stacks children on top of each other |
| `stack-top` | Modifier | Aligns stacked items to the top |
| `stack-bottom` | Modifier | Aligns stacked items to the bottom (default) |
| `stack-start` | Modifier | Aligns stacked items horizontally to the start |
| `stack-end` | Modifier | Aligns stacked items horizontally to the end |

## Essential Examples

### Basic usage

```html
<div class="stack w-32 h-32">
  <div class="bg-primary rounded-box">Item 1</div>
  <div class="bg-secondary rounded-box">Item 2</div>
  <div class="bg-accent rounded-box">Item 3</div>
</div>
```

### With alignment

```html
<!-- Aligned to top-start -->
<div class="stack stack-top stack-start w-48 h-48">
  <div class="bg-primary rounded-box p-4">Back</div>
  <div class="bg-secondary rounded-box p-4">Middle</div>
  <div class="bg-accent rounded-box p-4">Front</div>
</div>
```

### Image stack

```html
<div class="stack w-48 h-48">
  <img src="image1.jpg" class="rounded-box w-full h-full object-cover" />
  <img src="image2.jpg" class="rounded-box w-full h-full object-cover" />
  <img src="image3.jpg" class="rounded-box w-full h-full object-cover" />
</div>
```

## Notes

- **Recommended**: Apply `w-*` and `h-*` utility classes to set uniform sizing for all stacked items
- **Recommended**: The last child in DOM order renders on top; use this to control visual layering
