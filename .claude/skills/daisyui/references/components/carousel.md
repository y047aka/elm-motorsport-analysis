# Carousel

Slideshow component for cycling through images or content.

## Basic Usage

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

## Snap to Center

```html
<div class="carousel carousel-center rounded-box">
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

## Snap to End

```html
<div class="carousel carousel-end rounded-box">
  <div class="carousel-item">
    <img src="image1.jpg" alt="Slide 1" />
  </div>
  <div class="carousel-item">
    <img src="image2.jpg" alt="Slide 2" />
  </div>
</div>
```

## Full Width Slides

```html
<div class="carousel w-full">
  <div id="slide1" class="carousel-item relative w-full">
    <img src="image1.jpg" class="w-full" />
    <div class="absolute left-5 right-5 top-1/2 flex -translate-y-1/2 transform justify-between">
      <a href="#slide4" class="btn btn-circle">❮</a>
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
  <div id="slide3" class="carousel-item relative w-full">
    <img src="image3.jpg" class="w-full" />
    <div class="absolute left-5 right-5 top-1/2 flex -translate-y-1/2 transform justify-between">
      <a href="#slide2" class="btn btn-circle">❮</a>
      <a href="#slide4" class="btn btn-circle">❯</a>
    </div>
  </div>
  <div id="slide4" class="carousel-item relative w-full">
    <img src="image4.jpg" class="w-full" />
    <div class="absolute left-5 right-5 top-1/2 flex -translate-y-1/2 transform justify-between">
      <a href="#slide3" class="btn btn-circle">❮</a>
      <a href="#slide1" class="btn btn-circle">❯</a>
    </div>
  </div>
</div>
```

## With Indicators

```html
<div class="carousel w-full">
  <div id="item1" class="carousel-item w-full">
    <img src="image1.jpg" class="w-full" />
  </div>
  <div id="item2" class="carousel-item w-full">
    <img src="image2.jpg" class="w-full" />
  </div>
  <div id="item3" class="carousel-item w-full">
    <img src="image3.jpg" class="w-full" />
  </div>
  <div id="item4" class="carousel-item w-full">
    <img src="image4.jpg" class="w-full" />
  </div>
</div>
<div class="flex w-full justify-center gap-2 py-2">
  <a href="#item1" class="btn btn-xs">1</a>
  <a href="#item2" class="btn btn-xs">2</a>
  <a href="#item3" class="btn btn-xs">3</a>
  <a href="#item4" class="btn btn-xs">4</a>
</div>
```

## Vertical Carousel

```html
<div class="carousel carousel-vertical rounded-box h-96">
  <div class="carousel-item h-full">
    <img src="image1.jpg" />
  </div>
  <div class="carousel-item h-full">
    <img src="image2.jpg" />
  </div>
  <div class="carousel-item h-full">
    <img src="image3.jpg" />
  </div>
</div>
```

## Half Width Items

```html
<div class="carousel rounded-box w-96">
  <div class="carousel-item w-1/2">
    <img src="image1.jpg" class="w-full" />
  </div>
  <div class="carousel-item w-1/2">
    <img src="image2.jpg" class="w-full" />
  </div>
  <div class="carousel-item w-1/2">
    <img src="image3.jpg" class="w-full" />
  </div>
</div>
```

## Full Bleed Carousel

```html
<div class="carousel carousel-center bg-neutral rounded-box max-w-md space-x-4 p-4">
  <div class="carousel-item">
    <img src="image1.jpg" class="rounded-box" />
  </div>
  <div class="carousel-item">
    <img src="image2.jpg" class="rounded-box" />
  </div>
  <div class="carousel-item">
    <img src="image3.jpg" class="rounded-box" />
  </div>
</div>
```

## With Cards

```html
<div class="carousel carousel-center bg-base-200 rounded-box max-w-md space-x-4 p-4">
  <div class="carousel-item">
    <div class="card bg-base-100 w-64">
      <div class="card-body">
        <h2 class="card-title">Card 1</h2>
        <p>Content</p>
      </div>
    </div>
  </div>
  <div class="carousel-item">
    <div class="card bg-base-100 w-64">
      <div class="card-body">
        <h2 class="card-title">Card 2</h2>
        <p>Content</p>
      </div>
    </div>
  </div>
</div>
```

## Classes Reference

| Class | Description |
|-------|-------------|
| `carousel` | Container element |
| `carousel-item` | Individual slide |
| `carousel-center` | Snap to center |
| `carousel-end` | Snap to end |
| `carousel-vertical` | Vertical scrolling |
