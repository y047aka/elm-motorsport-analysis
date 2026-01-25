# Modal

Dialog component for displaying content in a layer above the page.

## Class Reference

| Class | Description |
|-------|-------------|
| `modal` | Container element |
| `modal-box` | Content container |
| `modal-action` | Actions container |
| `modal-backdrop` | Backdrop element (for click-outside-to-close) |
| `modal-toggle` | Hidden checkbox for toggle method |
| `modal-open` | Force modal open (for testing) |
| `modal-top` | Position at top |
| `modal-middle` | Position at middle (default) |
| `modal-bottom` | Position at bottom |

## Key Examples

### Basic modal (dialog element)

```html
<!-- Button to open modal -->
<button class="btn" onclick="my_modal.showModal()">Open Modal</button>

<!-- Modal -->
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

### Close button inside modal

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
<!-- Bottom on mobile, middle on larger screens -->
<dialog class="modal modal-bottom sm:modal-middle">
  <div class="modal-box">
    <h3 class="text-lg font-bold">Responsive Modal</h3>
    <p class="py-4">Bottom on mobile, centered on desktop</p>
  </div>
</dialog>
```

### Custom width

```html
<dialog class="modal">
  <div class="modal-box w-11/12 max-w-5xl">
    <h3 class="text-lg font-bold">Wide Modal</h3>
    <p class="py-4">This modal is wider than default</p>
  </div>
</dialog>
```

### Confirmation modal

```html
<dialog id="confirm_modal" class="modal">
  <div class="modal-box">
    <h3 class="text-lg font-bold">Confirm Action</h3>
    <p class="py-4">Are you sure you want to proceed?</p>
    <div class="modal-action">
      <form method="dialog">
        <button class="btn btn-error">Delete</button>
        <button class="btn">Cancel</button>
      </form>
    </div>
  </div>
</dialog>
```

## JavaScript Control

```javascript
// Open modal
document.getElementById('my_modal').showModal();

// Close modal
document.getElementById('my_modal').close();
```

## Alternative: Checkbox Toggle Method

```html
<!-- Toggle button -->
<label for="my-modal" class="btn">Open Modal</label>

<!-- Hidden checkbox -->
<input type="checkbox" id="my-modal" class="modal-toggle" />

<!-- Modal -->
<div class="modal" role="dialog">
  <div class="modal-box">
    <h3 class="text-lg font-bold">Hello!</h3>
    <p class="py-4">This modal uses checkbox toggle</p>
    <div class="modal-action">
      <label for="my-modal" class="btn">Close</label>
    </div>
  </div>
  <label class="modal-backdrop" for="my-modal">Close</label>
</div>
```
