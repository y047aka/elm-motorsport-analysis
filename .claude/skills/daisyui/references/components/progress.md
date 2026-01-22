# Progress

Progress bar component for showing completion status.

## Basic Usage

```html
<progress class="progress w-56" value="0" max="100"></progress>
<progress class="progress w-56" value="10" max="100"></progress>
<progress class="progress w-56" value="40" max="100"></progress>
<progress class="progress w-56" value="70" max="100"></progress>
<progress class="progress w-56" value="100" max="100"></progress>
```

## Color Variants

```html
<progress class="progress progress-primary w-56" value="50" max="100"></progress>
<progress class="progress progress-secondary w-56" value="50" max="100"></progress>
<progress class="progress progress-accent w-56" value="50" max="100"></progress>
<progress class="progress progress-neutral w-56" value="50" max="100"></progress>
```

## State Colors

```html
<progress class="progress progress-info w-56" value="50" max="100"></progress>
<progress class="progress progress-success w-56" value="50" max="100"></progress>
<progress class="progress progress-warning w-56" value="50" max="100"></progress>
<progress class="progress progress-error w-56" value="50" max="100"></progress>
```

## Indeterminate (No Value)

```html
<progress class="progress w-56"></progress>
<progress class="progress progress-primary w-56"></progress>
<progress class="progress progress-secondary w-56"></progress>
```

## Full Width

```html
<progress class="progress progress-primary w-full" value="70" max="100"></progress>
```

## With Label

```html
<div class="flex flex-col gap-2 w-full">
  <div class="flex justify-between text-sm">
    <span>Processing...</span>
    <span>70%</span>
  </div>
  <progress class="progress progress-primary" value="70" max="100"></progress>
</div>
```

## Different Widths

```html
<progress class="progress progress-primary w-24" value="50" max="100"></progress>
<progress class="progress progress-primary w-32" value="50" max="100"></progress>
<progress class="progress progress-primary w-48" value="50" max="100"></progress>
<progress class="progress progress-primary w-56" value="50" max="100"></progress>
<progress class="progress progress-primary w-64" value="50" max="100"></progress>
```

## In Card

```html
<div class="card bg-base-100 w-72 shadow-xl">
  <div class="card-body">
    <h2 class="card-title">Download Progress</h2>
    <progress class="progress progress-primary" value="65" max="100"></progress>
    <p class="text-sm text-base-content/60">65% complete</p>
  </div>
</div>
```

## Multiple Progress Bars

```html
<div class="flex flex-col gap-4 w-full max-w-xs">
  <div>
    <div class="flex justify-between text-sm mb-1">
      <span>HTML</span>
      <span>90%</span>
    </div>
    <progress class="progress progress-primary" value="90" max="100"></progress>
  </div>
  <div>
    <div class="flex justify-between text-sm mb-1">
      <span>CSS</span>
      <span>75%</span>
    </div>
    <progress class="progress progress-secondary" value="75" max="100"></progress>
  </div>
  <div>
    <div class="flex justify-between text-sm mb-1">
      <span>JavaScript</span>
      <span>60%</span>
    </div>
    <progress class="progress progress-accent" value="60" max="100"></progress>
  </div>
</div>
```

## Dynamic Progress (JavaScript)

```html
<progress class="progress progress-primary w-56" id="my-progress" value="0" max="100"></progress>

<script>
  let value = 0;
  const progress = document.getElementById('my-progress');
  
  setInterval(() => {
    value = (value + 1) % 101;
    progress.value = value;
  }, 100);
</script>
```

## Classes Reference

| Class | Description |
|-------|-------------|
| `progress` | Base progress class |
| `progress-primary` | Primary color |
| `progress-secondary` | Secondary color |
| `progress-accent` | Accent color |
| `progress-neutral` | Neutral color |
| `progress-info` | Info state color |
| `progress-success` | Success state color |
| `progress-warning` | Warning state color |
| `progress-error` | Error state color |
