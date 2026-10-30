# Chat

Conversation layout component for displaying message bubbles with sender alignment.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `chat` | Component | Container for one message and its metadata |
| `chat-image` | Part | Author image container |
| `chat-header` | Part | Text displayed above the chat bubble |
| `chat-footer` | Part | Text displayed below the chat bubble |
| `chat-bubble` | Part | The message bubble |
| `chat-start` | Placement | Aligns chat bubble to the start (left) |
| `chat-end` | Placement | Aligns chat bubble to the end (right) |
| `chat-bubble-neutral` | Color | Neutral color bubble |
| `chat-bubble-primary` | Color | Primary color bubble |
| `chat-bubble-secondary` | Color | Secondary color bubble |
| `chat-bubble-accent` | Color | Accent color bubble |
| `chat-bubble-info` | Color | Info color bubble |
| `chat-bubble-success` | Color | Success color bubble |
| `chat-bubble-warning` | Color | Warning color bubble |
| `chat-bubble-error` | Color | Error color bubble |

## Essential Examples

### Basic usage

```html
<div class="chat chat-start">
  <div class="chat-bubble">Hello there!</div>
</div>

<div class="chat chat-end">
  <div class="chat-bubble">Hi, how are you?</div>
</div>
```

### With structure

```html
<!-- Full chat message with avatar, header, and footer -->
<div class="chat chat-start">
  <div class="chat-image avatar">
    <div class="w-10 rounded-full">
      <img src="https://daisyui.com/images/stock/photo-1494902139d2f4c60493a71d0dde18341831973-320w.webp" alt="avatar" />
    </div>
  </div>
  <div class="chat-header">Obi-Wan <time datetime="2023-01-01 12:45" class="text-xs opacity-50">12:45</time></div>
  <div class="chat-bubble">How unwise of you!</div>
  <div class="chat-footer opacity-50">Seen at 12:46</div>
</div>

<div class="chat chat-end">
  <div class="chat-image avatar">
    <div class="w-10 rounded-full">
      <img src="https://daisyui.com/images/stock/photo-1494902139d2f4c60493a71d0dde18341831973-320w.webp" alt="avatar" />
    </div>
  </div>
  <div class="chat-header">Ahsoka <time datetime="2023-01-01 12:46" class="text-xs opacity-50">12:46</time></div>
  <div class="chat-bubble">It is I, Ahsoka!</div>
  <div class="chat-footer opacity-50">Delivered</div>
</div>
```

## Notes

- **Required**: Each message must use either `chat-start` or `chat-end` placement class to determine alignment
- **Recommended**: `chat-image` expects an `avatar` component as a child for proper styling of the author image
