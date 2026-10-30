# Calendar

Styling for third-party calendar libraries (Cally, Pikaday, React Day Picker).

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `cally` | Component | Styles for the Cally web component calendar |
| `pika-single` | Component | Styles for the Pikaday datepicker input |
| `react-day-picker` | Component | Styles for the React Day Picker component |

## Essential Examples

### Basic usage

```html
<!-- Cally web component (works in any framework) -->
<calendar-date class="cally bg-base-100 border border-base-300 shadow-lg rounded-box">
  <svg aria-label="Previous" class="fill-current size-4" slot="previous" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
    <path fill="currentColor" d="M15.75 19.5 8.25 12l7.5-7.5"></path>
  </svg>
  <svg aria-label="Next" class="fill-current size-4" slot="next" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
    <path fill="currentColor" d="m8.25 4.5 7.5 7.5-7.5 7.5"></path>
  </svg>
  <calendar-month></calendar-month>
</calendar-date>

<!-- Pikaday input -->
<input class="input pika-single" type="text" placeholder="Select date" />

<!-- React Day Picker (in JSX) -->
<!-- <DayPicker className="react-day-picker" /> -->
```

## Notes

- **Required**: daisyUI styles these libraries automatically; do not import the libraries' own CSS files
- **Required**: Navigation SVGs in Cally must use the `slot="previous"` and `slot="next"` attributes to enable the web component to position them correctly in the calendar header
- **Recommended**: For simple date input without a library, use native `<input type="date" class="input" />`
- **Recommended**: Cally is the most portable option as it is a standard web component with no framework dependency
