# Input

Text input component for user data entry.

## Basic Usage

```html
<input type="text" placeholder="Type here" class="input input-bordered w-full max-w-xs" />
```

## With Border

```html
<input type="text" placeholder="Type here" class="input input-bordered" />
```

## Without Border (Ghost)

```html
<input type="text" placeholder="Type here" class="input input-ghost" />
```

## Color Variants

```html
<input type="text" class="input input-bordered input-primary" placeholder="Primary" />
<input type="text" class="input input-bordered input-secondary" placeholder="Secondary" />
<input type="text" class="input input-bordered input-accent" placeholder="Accent" />
<input type="text" class="input input-bordered input-neutral" placeholder="Neutral" />
```

## State Colors

```html
<input type="text" class="input input-bordered input-info" placeholder="Info" />
<input type="text" class="input input-bordered input-success" placeholder="Success" />
<input type="text" class="input input-bordered input-warning" placeholder="Warning" />
<input type="text" class="input input-bordered input-error" placeholder="Error" />
```

## Sizes

```html
<input type="text" class="input input-bordered input-xs" placeholder="Extra small" />
<input type="text" class="input input-bordered input-sm" placeholder="Small" />
<input type="text" class="input input-bordered input-md" placeholder="Medium" />
<input type="text" class="input input-bordered input-lg" placeholder="Large" />
```

## Disabled

```html
<input type="text" placeholder="Disabled" class="input input-bordered" disabled />
```

## With Label

```html
<label class="form-control w-full max-w-xs">
  <div class="label">
    <span class="label-text">What is your name?</span>
    <span class="label-text-alt">Top right label</span>
  </div>
  <input type="text" placeholder="Type here" class="input input-bordered w-full max-w-xs" />
  <div class="label">
    <span class="label-text-alt">Bottom left label</span>
    <span class="label-text-alt">Bottom right label</span>
  </div>
</label>
```

## With Icon

```html
<label class="input input-bordered flex items-center gap-2">
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" fill="currentColor" class="h-4 w-4 opacity-70">
    <path d="M8 8a3 3 0 1 0 0-6 3 3 0 0 0 0 6ZM12.735 14c.618 0 1.093-.561.872-1.139a6.002 6.002 0 0 0-11.215 0c-.22.578.254 1.139.872 1.139h9.47Z" />
  </svg>
  <input type="text" class="grow" placeholder="Username" />
</label>

<label class="input input-bordered flex items-center gap-2">
  <input type="text" class="grow" placeholder="Search" />
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" fill="currentColor" class="h-4 w-4 opacity-70">
    <path fill-rule="evenodd" d="M9.965 11.026a5 5 0 1 1 1.06-1.06l2.755 2.754a.75.75 0 1 1-1.06 1.06l-2.755-2.754ZM10.5 7a3.5 3.5 0 1 1-7 0 3.5 3.5 0 0 1 7 0Z" clip-rule="evenodd" />
  </svg>
</label>
```

## Password Input

```html
<label class="input input-bordered flex items-center gap-2">
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" fill="currentColor" class="h-4 w-4 opacity-70">
    <path fill-rule="evenodd" d="M14 6a4 4 0 0 1-4.899 3.899l-1.955 1.955a.5.5 0 0 1-.353.146H5v1.5a.5.5 0 0 1-.5.5h-2a.5.5 0 0 1-.5-.5v-2.293a.5.5 0 0 1 .146-.353l3.955-3.955A4 4 0 1 1 14 6Zm-4-2a.75.75 0 0 0 0 1.5.5.5 0 0 1 .5.5.75.75 0 0 0 1.5 0 2 2 0 0 0-2-2Z" clip-rule="evenodd" />
  </svg>
  <input type="password" class="grow" placeholder="Password" />
</label>
```

## Email Input

```html
<label class="input input-bordered flex items-center gap-2">
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" fill="currentColor" class="h-4 w-4 opacity-70">
    <path d="M2.5 3A1.5 1.5 0 0 0 1 4.5v.793c.026.009.051.02.076.032L7.674 8.51c.206.1.446.1.652 0l6.598-3.185A.755.755 0 0 1 15 5.293V4.5A1.5 1.5 0 0 0 13.5 3h-11Z" />
    <path d="M15 6.954 8.978 9.86a2.25 2.25 0 0 1-1.956 0L1 6.954V11.5A1.5 1.5 0 0 0 2.5 13h11a1.5 1.5 0 0 0 1.5-1.5V6.954Z" />
  </svg>
  <input type="email" class="grow" placeholder="Email" />
</label>
```

## Full Width

```html
<input type="text" placeholder="Full width" class="input input-bordered w-full" />
```

## Input Group (Join)

```html
<div class="join">
  <input class="input input-bordered join-item" placeholder="Email" />
  <button class="btn join-item rounded-r-full">Subscribe</button>
</div>
```

## Classes Reference

| Class | Description |
|-------|-------------|
| `input` | Base input class |
| `input-bordered` | Adds border |
| `input-ghost` | No border, transparent |
| `input-primary` | Primary color focus |
| `input-secondary` | Secondary color focus |
| `input-accent` | Accent color focus |
| `input-neutral` | Neutral color focus |
| `input-info` | Info state color |
| `input-success` | Success state color |
| `input-warning` | Warning state color |
| `input-error` | Error state color |
| `input-xs` | Extra small size |
| `input-sm` | Small size |
| `input-md` | Medium size (default) |
| `input-lg` | Large size |
