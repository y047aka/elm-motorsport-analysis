# Modal

Dialog component for displaying content in a layer above the page.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `modal` | Component | Modal container |
| `modal-box` | Part | Content container (must be used inside modal) |
| `modal-action` | Part | Actions section for buttons |
| `modal-backdrop` | Part | Label that covers the page when modal is open, closes modal by clicking outside (use with `<form method="dialog">`) |
| `modal-toggle` | Part | Hidden checkbox for controlling state (alternative to dialog element) |
| `modal-open` | Modifier | Force modal to be open |
| `modal-top` | Placement | Position modal at top |
| `modal-middle` | Placement | Position at middle (default) |
| `modal-bottom` | Placement | Position modal at bottom |
| `modal-start` | Placement | Moves the modal to start horizontally |
| `modal-end` | Placement | Moves the modal to end horizontally |

## Essential Examples

### Basic usage

```html
<button class="btn" onclick="my_modal.showModal()">Open Modal</button>

<dialog id="my_modal" class="modal">
  <div class="modal-box">
    <h3 class="text-lg font-bold">Hello!</h3>
    <p class="py-4">Press ESC key or click the button below to close</p>
    <div class="modal-action">
      <form method="dialog">
        <button class="btn">Close</button>
      </form>
    </div>
  </div>
</dialog>
```

### With structure

```html
<!-- Close on outside click -->
<dialog id="my_modal" class="modal">
  <div class="modal-box">
    <h3 class="text-lg font-bold">Hello!</h3>
    <p class="py-4">Click outside to close</p>
  </div>
  <form method="dialog" class="modal-backdrop">
    <button>close</button>
  </form>
</dialog>
```

### Interactive

```html
<!-- Close button in corner -->
<button class="btn" onclick="my_modal_3.showModal()">Open Modal</button>

<dialog id="my_modal_3" class="modal">
  <div class="modal-box">
    <form method="dialog">
      <button class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2">✕</button>
    </form>
    <h3 class="text-lg font-bold">Hello!</h3>
    <p class="py-4">Content here</p>
  </div>
</dialog>
```

## Notes

- **Required**: Use `<dialog>` element with `modal` class
- **Required**: Open with `element.showModal()`, close with `element.close()`
- **Required**: For outside click to close, use `<form method="dialog" class="modal-backdrop">`
- **Required**: For action buttons to close modal, wrap in `<form method="dialog">`
- **Recommended**: Native ESC key closes modal automatically
- **Recommended**: Use `modal-bottom sm:modal-middle` for responsive positioning
