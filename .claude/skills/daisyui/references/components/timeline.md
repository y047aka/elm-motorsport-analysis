# Timeline

Ordered list of events with connecting lines and optional icons.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `timeline` | Component | Timeline container (use on `<ul>`) |
| `timeline-start` | Part | Content area at the start direction (must be inside timeline `<li>`) |
| `timeline-middle` | Part | Center area for icons or connectors (must be inside timeline `<li>`) |
| `timeline-end` | Part | Content area at the end direction (must be inside timeline `<li>`) |
| `timeline-snap-icon` | Modifier | Snaps the icon to the start instead of the middle |
| `timeline-box` | Modifier | Applies box styling to start or end content |
| `timeline-compact` | Modifier | Forces all items to one side |
| `timeline-horizontal` | direction | Horizontal layout (default) |
| `timeline-vertical` | direction | Vertical layout |

## Essential Examples

### Basic usage

```html
<ul class="timeline timeline-vertical">
  <li>
    <div class="timeline-start">Event 1</div>
    <div class="timeline-middle">
      <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
      </svg>
    </div>
    <div class="timeline-end timeline-box">Details for event 1</div>
    <hr />
  </li>
  <li>
    <hr />
    <div class="timeline-start">Event 2</div>
    <div class="timeline-middle">
      <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 text-secondary" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
      </svg>
    </div>
    <div class="timeline-end timeline-box">Details for event 2</div>
  </li>
</ul>
```

### With structure

```html
<!-- Horizontal timeline with colored connecting lines -->
<ul class="timeline timeline-horizontal">
  <li>
    <div class="timeline-start">Start</div>
    <div class="timeline-middle">
      <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="2" fill="none"/>
      </svg>
    </div>
    <div class="timeline-end timeline-box">First milestone</div>
    <hr class="bg-primary" />
  </li>
  <li>
    <hr class="bg-primary" />
    <div class="timeline-start timeline-box">Second milestone</div>
    <div class="timeline-middle">
      <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="2" fill="none"/>
      </svg>
    </div>
    <div class="timeline-end">Middle</div>
    <hr class="bg-secondary" />
  </li>
  <li>
    <hr class="bg-secondary" />
    <div class="timeline-start">End</div>
    <div class="timeline-middle">
      <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="2" fill="none"/>
      </svg>
    </div>
    <div class="timeline-end timeline-box">Final milestone</div>
  </li>
</ul>
```

## Notes

- **Required**: Use `<hr />` tags inside `<li>` elements to render connecting lines between timeline items
- **Required**: Place `<hr />` at the end of a `<li>` to connect forward, or at the beginning to connect backward
- **Recommended**: Apply background color classes (e.g., `bg-primary`) directly to `<hr />` elements for colored connecting lines
- **Recommended**: Use `timeline-box` on `timeline-start` or `timeline-end` to add card-style backgrounds to content
