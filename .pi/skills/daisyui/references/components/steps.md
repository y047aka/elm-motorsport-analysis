# Steps

Process flow indicator displaying sequential steps with optional color-coded progress states.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `steps` | Component | Container for step items (`<ul>`) |
| `step` | Part | Individual step node (`<li>`, must be inside `steps`) |
| `step-icon` | Part | Custom icon container within a step (`<span>`, must be inside `step`) |
| `step-neutral` | Color | Neutral color for a step |
| `step-primary` | Color | Primary color for a step |
| `step-secondary` | Color | Secondary color for a step |
| `step-accent` | Color | Accent color for a step |
| `step-info` | Color | Info color for a step |
| `step-success` | Color | Success color for a step |
| `step-warning` | Color | Warning color for a step |
| `step-error` | Color | Error color for a step |
| `steps-horizontal` | direction | Horizontal layout (default) |
| `steps-vertical` | direction | Vertical layout |

## Essential Examples

### Basic usage

```html
<ul class="steps steps-horizontal">
  <li class="step step-primary">Register</li>
  <li class="step step-primary">Choose plan</li>
  <li class="step">Purchase</li>
  <li class="step">Receive Product</li>
</ul>
```

### With custom icons

```html
<ul class="steps steps-horizontal">
  <li class="step step-success">
    <span class="step-icon">&#10003;</span>
    Register
  </li>
  <li class="step step-primary">
    <span class="step-icon">&#9733;</span>
    Choose plan
  </li>
  <li class="step">Purchase</li>
  <li class="step">Receive Product</li>
</ul>
```

### With data-content attribute

```html
<ul class="steps steps-horizontal">
  <li data-content="&#10003;" class="step step-success">Step 1</li>
  <li data-content="&#10003;" class="step step-success">Step 2</li>
  <li data-content="?" class="step step-warning">Step 3</li>
  <li class="step">Step 4</li>
</ul>
```

## Notes

- **Required**: `step` elements must be `<li>` inside a `steps` container (`<ul>`)
- **Required**: `step-icon` must be a `<span>` as the first child inside a `step`
- **Recommended**: Color classes on individual steps indicate progress state; uncolored steps represent incomplete steps
- **Recommended**: Use `data-content` attribute on `step` to display custom text or symbols inside the step circle instead of the default number
