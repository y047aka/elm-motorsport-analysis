# Modal

Dialog component for displaying content in a layer above the page.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `modal` | Component | Modal container |
| `modal-box` | Part | Content container |
| `modal-action` | Part | Actions section (buttons) |
| `modal-backdrop` | Part | Overlay for closing on outside click |
| `modal-toggle` | Part | Hidden checkbox controlling state |
| `modal-open` | Modifier | Force modal open |
| `modal-top` | Placement | Position at top |
| `modal-middle` | Placement | Position at middle (default) |
| `modal-bottom` | Placement | Position at bottom |
| `modal-start` | Placement | Moves the modal to start horizontally |
| `modal-end` | Placement | Moves the modal to end horizontally |

## Essential Examples

### Basic usage (dialog element)

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

### Close on outside click

```html
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

### Close button in corner

```html
<dialog id="my_modal" class="modal">
  <div class="modal-box">
    <form method="dialog">
      <button class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2">✕</button>
    </form>
    <h3 class="text-lg font-bold">Hello!</h3>
    <p class="py-4">Content here</p>
  </div>
</dialog>
```

### Responsive position

```html
<dialog class="modal modal-bottom sm:modal-middle">
  <div class="modal-box">
    <h3 class="text-lg font-bold">Responsive Modal</h3>
    <p class="py-4">Bottom on mobile, centered on desktop</p>
  </div>
</dialog>
```

## Notes

- Control: `element.showModal()` to open, `element.close()` to close
- Close on outside click: Use `<form method="dialog" class="modal-backdrop">`
- Close on ESC: Native `<dialog>` behavior
- Alternative: Use checkbox toggle method with `modal-toggle` class
