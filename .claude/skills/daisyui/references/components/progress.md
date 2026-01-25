# Progress

Progress bar component for showing task completion or time passage.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `progress` | Component | Base class for `<progress>` tag |
| `progress-neutral` | Color | Applies neutral color scheme |
| `progress-primary` | Color | Applies primary color scheme |
| `progress-secondary` | Color | Applies secondary color scheme |
| `progress-accent` | Color | Applies accent color scheme |
| `progress-info` | Color | Applies info color scheme |
| `progress-success` | Color | Applies success color scheme |
| `progress-warning` | Color | Applies warning color scheme |
| `progress-error` | Color | Applies error color scheme |

## Key Examples

### Basic progress bars

```html
<progress class="progress w-56" value="0" max="100"></progress>
<progress class="progress w-56" value="10" max="100"></progress>
<progress class="progress w-56" value="40" max="100"></progress>
<progress class="progress w-56" value="70" max="100"></progress>
<progress class="progress w-56" value="100" max="100"></progress>
```

### Progress colors

```html
<progress class="progress progress-primary w-56" value="50" max="100"></progress>
<progress class="progress progress-secondary w-56" value="50" max="100"></progress>
<progress class="progress progress-accent w-56" value="50" max="100"></progress>
<progress class="progress progress-info w-56" value="50" max="100"></progress>
<progress class="progress progress-success w-56" value="50" max="100"></progress>
<progress class="progress progress-warning w-56" value="50" max="100"></progress>
<progress class="progress progress-error w-56" value="50" max="100"></progress>
```

### Indeterminate progress

```html
<progress class="progress w-56"></progress>
<progress class="progress progress-primary w-56"></progress>
<progress class="progress progress-secondary w-56"></progress>
```

### Progress with label

```html
<div class="flex flex-col gap-2 w-full">
  <div class="flex justify-between text-sm">
    <span>Processing...</span>
    <span>70%</span>
  </div>
  <progress class="progress progress-primary" value="70" max="100"></progress>
</div>
```

### Multiple progress bars

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

### Progress in card

```html
<div class="card bg-base-100 w-72 shadow-xl">
  <div class="card-body">
    <h2 class="card-title">Download Progress</h2>
    <progress class="progress progress-primary" value="65" max="100"></progress>
    <p class="text-sm text-base-content/60">65% complete</p>
  </div>
</div>
```
