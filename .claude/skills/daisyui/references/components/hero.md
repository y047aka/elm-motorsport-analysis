# Hero

Full-width banner component for landing pages and headers.

## Basic Usage

```html
<div class="hero min-h-screen bg-base-200">
  <div class="hero-content text-center">
    <div class="max-w-md">
      <h1 class="text-5xl font-bold">Hello there</h1>
      <p class="py-6">
        Provident cupiditate voluptatem et in. Quaerat fugiat ut assumenda excepturi exercitationem
        quasi. In deleniti eaque aut repudiandae et a id nisi.
      </p>
      <button class="btn btn-primary">Get Started</button>
    </div>
  </div>
</div>
```

## With Background Image

```html
<div class="hero min-h-screen" style="background-image: url(https://img.daisyui.com/images/stock/photo-1507358522600-9f71e620c44e.webp);">
  <div class="hero-overlay bg-opacity-60"></div>
  <div class="hero-content text-neutral-content text-center">
    <div class="max-w-md">
      <h1 class="mb-5 text-5xl font-bold">Hello there</h1>
      <p class="mb-5">
        Provident cupiditate voluptatem et in. Quaerat fugiat ut assumenda excepturi exercitationem
        quasi. In deleniti eaque aut repudiandae et a id nisi.
      </p>
      <button class="btn btn-primary">Get Started</button>
    </div>
  </div>
</div>
```

## With Figure (Side by Side)

```html
<div class="hero min-h-screen bg-base-200">
  <div class="hero-content flex-col lg:flex-row">
    <img
      src="https://img.daisyui.com/images/stock/photo-1635805737707-575885ab0820.webp"
      class="max-w-sm rounded-lg shadow-2xl" />
    <div>
      <h1 class="text-5xl font-bold">Box Office News!</h1>
      <p class="py-6">
        Provident cupiditate voluptatem et in. Quaerat fugiat ut assumenda excepturi exercitationem
        quasi. In deleniti eaque aut repudiandae et a id nisi.
      </p>
      <button class="btn btn-primary">Get Started</button>
    </div>
  </div>
</div>
```

## With Figure Reversed

```html
<div class="hero min-h-screen bg-base-200">
  <div class="hero-content flex-col lg:flex-row-reverse">
    <img
      src="https://img.daisyui.com/images/stock/photo-1635805737707-575885ab0820.webp"
      class="max-w-sm rounded-lg shadow-2xl" />
    <div>
      <h1 class="text-5xl font-bold">Box Office News!</h1>
      <p class="py-6">
        Provident cupiditate voluptatem et in. Quaerat fugiat ut assumenda excepturi exercitationem
        quasi. In deleniti eaque aut repudiandae et a id nisi.
      </p>
      <button class="btn btn-primary">Get Started</button>
    </div>
  </div>
</div>
```

## With Form

```html
<div class="hero min-h-screen bg-base-200">
  <div class="hero-content flex-col lg:flex-row-reverse">
    <div class="text-center lg:text-left">
      <h1 class="text-5xl font-bold">Login now!</h1>
      <p class="py-6">
        Provident cupiditate voluptatem et in. Quaerat fugiat ut assumenda excepturi exercitationem
        quasi. In deleniti eaque aut repudiandae et a id nisi.
      </p>
    </div>
    <div class="card bg-base-100 w-full max-w-sm shrink-0 shadow-2xl">
      <form class="card-body">
        <div class="form-control">
          <label class="label">
            <span class="label-text">Email</span>
          </label>
          <input type="email" placeholder="email" class="input input-bordered" required />
        </div>
        <div class="form-control">
          <label class="label">
            <span class="label-text">Password</span>
          </label>
          <input type="password" placeholder="password" class="input input-bordered" required />
          <label class="label">
            <a href="#" class="label-text-alt link link-hover">Forgot password?</a>
          </label>
        </div>
        <div class="form-control mt-6">
          <button class="btn btn-primary">Login</button>
        </div>
      </form>
    </div>
  </div>
</div>
```

## Overlay Colors

```html
<!-- Dark overlay -->
<div class="hero min-h-screen" style="background-image: url(image.jpg);">
  <div class="hero-overlay bg-black bg-opacity-70"></div>
  <div class="hero-content text-white">
    <h1 class="text-5xl font-bold">Dark Overlay</h1>
  </div>
</div>

<!-- Primary color overlay -->
<div class="hero min-h-screen" style="background-image: url(image.jpg);">
  <div class="hero-overlay bg-primary bg-opacity-80"></div>
  <div class="hero-content text-primary-content">
    <h1 class="text-5xl font-bold">Primary Overlay</h1>
  </div>
</div>

<!-- Gradient overlay -->
<div class="hero min-h-screen" style="background-image: url(image.jpg);">
  <div class="hero-overlay bg-gradient-to-r from-black to-transparent"></div>
  <div class="hero-content text-white">
    <h1 class="text-5xl font-bold">Gradient Overlay</h1>
  </div>
</div>
```

## Different Heights

```html
<!-- Minimum height 50% -->
<div class="hero min-h-[50vh] bg-base-200">
  <div class="hero-content">
    <h1 class="text-5xl font-bold">Half Height</h1>
  </div>
</div>

<!-- Fixed height -->
<div class="hero h-96 bg-base-200">
  <div class="hero-content">
    <h1 class="text-5xl font-bold">Fixed Height</h1>
  </div>
</div>
```

## With Stats

```html
<div class="hero min-h-screen bg-base-200">
  <div class="hero-content text-center">
    <div>
      <h1 class="text-5xl font-bold mb-8">Our Achievements</h1>
      <div class="stats shadow">
        <div class="stat">
          <div class="stat-title">Downloads</div>
          <div class="stat-value">31K</div>
        </div>
        <div class="stat">
          <div class="stat-title">Users</div>
          <div class="stat-value">4,200</div>
        </div>
        <div class="stat">
          <div class="stat-title">Followers</div>
          <div class="stat-value">1,200</div>
        </div>
      </div>
      <button class="btn btn-primary mt-8">Join Us</button>
    </div>
  </div>
</div>
```

## Classes Reference

| Class | Description |
|-------|-------------|
| `hero` | Container element |
| `hero-content` | Content wrapper |
| `hero-overlay` | Overlay layer (for background images) |
