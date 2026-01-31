# Hover Gallery

Image gallery that shows different images on horizontal hover. First image displays by default, others appear based on cursor position.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `hover-gallery` | Component | Container for hover-based image gallery |

## Essential Examples

### Basic usage

```html
<figure class="hover-gallery max-w-60">
  <img src="image-1.webp" alt="Image 1" />
  <img src="image-2.webp" alt="Image 2" />
  <img src="image-3.webp" alt="Image 3" />
  <img src="image-4.webp" alt="Image 4" />
</figure>
```

### Inside a card

```html
<div class="card card-sm bg-base-200 max-w-60 shadow">
  <figure class="hover-gallery">
    <img src="image-1.webp" alt="Image 1" />
    <img src="image-2.webp" alt="Image 2" />
    <img src="image-3.webp" alt="Image 3" />
    <img src="image-4.webp" alt="Image 4" />
  </figure>
  <div class="card-body">
    <h2 class="card-title flex justify-between">
      Product Name
      <span class="font-normal">$25</span>
    </h2>
    <p>Product description</p>
  </div>
</div>
```

### With more images

```html
<figure class="hover-gallery max-w-80">
  <img src="image-1.webp" alt="Image 1" />
  <img src="image-2.webp" alt="Image 2" />
  <img src="image-3.webp" alt="Image 3" />
  <img src="image-4.webp" alt="Image 4" />
  <img src="image-5.webp" alt="Image 5" />
  <img src="image-6.webp" alt="Image 6" />
</figure>
```

## Notes

- **Required**: Maximum 10 images supported
- **Recommended**: Use `<figure>` element as container
- **Recommended**: Set width constraint with `max-w-*` utilities
- **Recommended**: Ideal for e-commerce product cards, portfolios, and image galleries
