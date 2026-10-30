# FAB (Floating Action Button)

Speed dial floating action button that reveals additional action buttons on activation.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `fab` | Component | FAB container for the trigger and speed dial buttons |
| `fab-close` | Part | Optional close button that replaces the main button when opened (must be inside `fab`) |
| `fab-main-action` | Part | Optional action button replacing the main button when opened (must be inside `fab`) |
| `fab-flower` | Modifier | Arranges speed dial buttons in a quarter-circle pattern instead of vertical |

## Essential Examples

### Basic usage

```html
<div class="fab">
  <div tabindex="0" role="button" class="btn btn-lg btn-circle btn-primary">
    +
  </div>
  <button class="btn btn-lg btn-circle btn-accent">A</button>
  <button class="btn btn-lg btn-circle btn-accent">B</button>
  <button class="btn btn-lg btn-circle btn-accent">C</button>
</div>
```

### With structure

```html
<!-- Flower layout with close and main-action buttons -->
<div class="fab fab-flower">
  <div tabindex="0" role="button" class="btn btn-lg btn-circle btn-primary">
    +
  </div>
  <button class="btn btn-lg btn-circle btn-close">
    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
    </svg>
  </button>
  <button class="btn btn-lg btn-circle btn-main-action btn-accent">
    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.75 10.5V6a3.75 3.75 0 10-7.5 0v4.5m11.356-1.993l1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 01-1.12-1.243l1.264-12A1.125 1.125 0 015.513 7.5h12.974c.576 0 1.059.435 1.12 1.007z" />
    </svg>
  </button>
  <button class="btn btn-lg btn-circle btn-accent">
    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.25 18.75a4.5 4.5 0 014.5-4.5h8.25a4.5 4.5 0 014.5 4.5M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0z" />
    </svg>
  </button>
</div>

<!-- Vertical layout with tooltips -->
<div class="fab">
  <div tabindex="0" role="button" class="btn btn-lg btn-circle btn-primary">
    +
  </div>
  <div class="tooltip tooltip-left" data-tip="Message">
    <button class="btn btn-lg btn-circle btn-accent">
      <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.409a2.25 2.25 0 013.182 0l2.909 2.909M3.75 21h16.5A2.25 2.25 0 0122.5 18.75V5.25A2.25 2.25 0 0020.25 3H3.75A2.25 2.25 0 001.5 5.25v13.5A2.25 2.25 0 003.75 21z" />
      </svg>
    </button>
  </div>
  <div class="tooltip tooltip-left" data-tip="Upload">
    <button class="btn btn-lg btn-circle btn-accent">
      <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.5v15m7.5-7.5H4.5" />
      </svg>
    </button>
  </div>
</div>
```

## Notes

- **Required**: The trigger button must be a `<div tabindex="0" role="button">` rather than a `<button>` element due to a Safari CSS bug that prevents buttons from receiving focus
- **Required**: The trigger must be the first child element inside the `fab` container
- **Recommended**: Use `fab-flower` for 2-4 speed dial buttons; vertical layout works better for longer lists
- **Recommended**: Wrap speed dial buttons in tooltip containers for labels in space-constrained layouts
