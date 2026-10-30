# Carousel

Slideshow component for cycling through images or content.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `carousel` | Component | Container element |
| `carousel-item` | Part | Individual slide within carousel |
| `carousel-start` | Modifier | Snap elements to start (default) |
| `carousel-center` | Modifier | Snap elements to center |
| `carousel-end` | Modifier | Snap elements to end |
| `carousel-horizontal` | direction | Horizontal layout [default] |
| `carousel-vertical` | direction | Vertical scrolling carousel |

## Essential Examples

### Basic usage

```html
<div class="carousel rounded-box">
  <div class="carousel-item">
    <img src="image1.jpg" alt="Slide 1" />
  </div>
  <div class="carousel-item">
    <img src="image2.jpg" alt="Slide 2" />
  </div>
  <div class="carousel-item">
    <img src="image3.jpg" alt="Slide 3" />
  </div>
</div>
```

### Full width with navigation

```html
<div class="carousel w-full">
  <div id="slide1" class="carousel-item relative w-full">
    <img src="image1.jpg" class="w-full" />
    <div class="absolute left-5 right-5 top-1/2 flex -translate-y-1/2 transform justify-between">
      <a href="#slide3" class="btn btn-circle">❮</a>
      <a href="#slide2" class="btn btn-circle">❯</a>
    </div>
  </div>
  <div id="slide2" class="carousel-item relative w-full">
    <img src="image2.jpg" class="w-full" />
    <div class="absolute left-5 right-5 top-1/2 flex -translate-y-1/2 transform justify-between">
      <a href="#slide1" class="btn btn-circle">❮</a>
      <a href="#slide3" class="btn btn-circle">❯</a>
    </div>
  </div>
</div>
```

### With indicators

```html
<div class="carousel w-full">
  <div id="item1" class="carousel-item w-full">
    <img src="image1.jpg" class="w-full" />
  </div>
  <div id="item2" class="carousel-item w-full">
    <img src="image2.jpg" class="w-full" />
  </div>
</div>
<div class="flex w-full justify-center gap-2 py-2">
  <a href="#item1" class="btn btn-xs">1</a>
  <a href="#item2" class="btn btn-xs">2</a>
</div>
```

## Notes

- **Required**: Uses CSS scroll snap for smooth scrolling behavior
- **Recommended**: Use anchor links with element IDs for slide navigation
- **Recommended**: For vertical carousel, set appropriate height constraints
