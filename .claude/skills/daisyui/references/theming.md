# daisyUI Themes

How to use and customize daisyUI themes.

## Enable Built-in Themes

By default, `light` and `dark` themes are enabled. Configure themes in CSS:

```css
@import "tailwindcss";
@plugin "daisyui" {
  themes: light --default, dark --prefersdark, cupcake;
}
```

- `--default` flag sets the default theme
- `--prefersdark` flag sets the default for dark mode (prefers-color-scheme: dark)

## Apply Themes

Use `data-theme` attribute:

```html
<html data-theme="dark">
  <div data-theme="light">Theme can be nested</div>
</html>
```

## Built-in Themes

daisyUI includes 35 built-in themes. Common ones include:

- **Light themes**: light, cupcake, bumblebee, emerald, corporate, wireframe, cmyk, autumn, lemonade, winter
- **Dark themes**: dark, synthwave, retro, cyberpunk, halloween, forest, dracula, business, night, coffee, dim, sunset, abyss

For the complete list of 35 themes, see: https://daisyui.com/docs/themes/

### Enable All Themes

```css
@import "tailwindcss";
@plugin "daisyui" {
  themes: all;
}
```

### Disable Themes

```css
@import "tailwindcss";
@plugin "daisyui" {
  themes: false;
}
```

## Create Custom Theme

Add a custom theme using `@plugin "daisyui/theme" {}`:

```css
@import "tailwindcss";
@plugin "daisyui";
@plugin "daisyui/theme" {
  name: "mytheme";
  default: true; /* set as default */
  prefersdark: false; /* set as default dark mode */
  color-scheme: light; /* browser UI color scheme */

  /* Base colors */
  --color-base-100: oklch(98% 0.02 240);
  --color-base-200: oklch(95% 0.03 240);
  --color-base-300: oklch(92% 0.04 240);
  --color-base-content: oklch(20% 0.05 240);

  /* Brand colors */
  --color-primary: oklch(55% 0.3 240);
  --color-primary-content: oklch(98% 0.01 240);
  --color-secondary: oklch(70% 0.25 200);
  --color-secondary-content: oklch(98% 0.01 200);
  --color-accent: oklch(65% 0.25 160);
  --color-accent-content: oklch(98% 0.01 160);
  --color-neutral: oklch(50% 0.05 240);
  --color-neutral-content: oklch(98% 0.01 240);

  /* State colors */
  --color-info: oklch(70% 0.2 220);
  --color-info-content: oklch(98% 0.01 220);
  --color-success: oklch(65% 0.25 140);
  --color-success-content: oklch(98% 0.01 140);
  --color-warning: oklch(80% 0.25 80);
  --color-warning-content: oklch(20% 0.05 80);
  --color-error: oklch(65% 0.3 30);
  --color-error-content: oklch(98% 0.01 30);

  /* Border radius */
  --radius-selector: 1rem;
  --radius-field: 0.25rem;
  --radius-box: 0.5rem;

  /* Base sizes */
  --size-selector: 0.25rem;
  --size-field: 0.25rem;

  /* Border size */
  --border: 1px;

  /* Effects */
  --depth: 1;
  --noise: 0;
}
```

## Customize Existing Theme

Override specific properties of a built-in theme:

```css
@import "tailwindcss";
@plugin "daisyui";
@plugin "daisyui/theme" {
  name: "light";
  default: true;
  --color-primary: blue;
  --color-secondary: teal;
}
```

All other values inherit from the original theme.

## Theme-Specific Styles

Apply custom styles for a specific theme:

```css
[data-theme="light"] {
  .my-btn {
    background-color: #1EA1F1;
    border-color: #1EA1F1;
  }
  .my-btn:hover {
    background-color: #1C96E1;
    border-color: #1C96E1;
  }
}
```

## Tailwind Dark Mode Integration

Configure daisyUI themes to work with Tailwind's `dark:` prefix:

```css
@import "tailwindcss";
@plugin "daisyui" {
  themes: winter --default, night --prefersdark;
}

@custom-variant dark (&:where([data-theme=night], [data-theme=night] *));
```

```html
<div class="p-10 dark:p-20">
  I will have 10 padding on winter theme and 20 padding on night theme
</div>
```
