# Accordion

Collapsible content panels that expand one at a time, built on top of the collapse component.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `collapse` | Component | Base container for each accordion item |
| `collapse-title` | Part | Title/header section of accordion item |
| `collapse-content` | Part | Content section that expands and collapses |
| `collapse-arrow` | Modifier | Adds rotating arrow icon indicator |
| `collapse-plus` | Modifier | Adds plus/minus icon indicator |
| `collapse-open` | Modifier | Forces item to remain open |
| `collapse-close` | Modifier | Forces item to remain closed |

## Essential Examples

### Basic usage

```html
<div class="collapse bg-base-100 border border-base-300">
  <input type="radio" name="my-accordion-1" checked="checked" />
  <div class="collapse-title font-semibold">Question 1</div>
  <div class="collapse-content text-sm">Answer text goes here.</div>
</div>

<div class="collapse bg-base-100 border border-base-300">
  <input type="radio" name="my-accordion-1" />
  <div class="collapse-title font-semibold">Question 2</div>
  <div class="collapse-content text-sm">Answer text goes here.</div>
</div>
```

### With structure

```html
<!-- Joined accordion with arrow indicators -->
<div class="join join-vertical bg-base-100">
  <div class="collapse collapse-arrow join-item border border-base-300">
    <input type="radio" name="my-accordion-2" checked="checked" />
    <div class="collapse-title font-semibold">Question 1</div>
    <div class="collapse-content text-sm">Answer text goes here.</div>
  </div>
  <div class="collapse collapse-arrow join-item border border-base-300">
    <input type="radio" name="my-accordion-2" />
    <div class="collapse-title font-semibold">Question 2</div>
    <div class="collapse-content text-sm">Answer text goes here.</div>
  </div>
</div>
```

### With details element

```html
<!-- Using native details/summary for searchable content -->
<details class="collapse bg-base-100 border border-base-300" name="my-accordion-3" open>
  <summary class="collapse-title font-semibold">Question 1</summary>
  <div class="collapse-content text-sm">Answer text goes here.</div>
</details>

<details class="collapse bg-base-100 border border-base-300" name="my-accordion-3">
  <summary class="collapse-title font-semibold">Question 2</summary>
  <div class="collapse-content text-sm">Answer text goes here.</div>
</details>
```

## Notes

- **Required**: Use matching `name` attribute on radio inputs (or details elements) to enforce single-item-open behavior
- **Required**: Only the `<input type="radio">` with `checked` attribute will be open initially
- **Recommended**: Use `<details>` element method when browser search functionality within collapsed content is needed
- **Recommended**: Wrap items in `join join-vertical` with `join-item` on each collapse for seamless borders
