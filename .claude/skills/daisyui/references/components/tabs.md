# Tabs

Tab navigation component for switching between views.

## Basic Usage

```html
<div role="tablist" class="tabs">
  <a role="tab" class="tab">Tab 1</a>
  <a role="tab" class="tab tab-active">Tab 2</a>
  <a role="tab" class="tab">Tab 3</a>
</div>
```

## Bordered Tabs

```html
<div role="tablist" class="tabs tabs-bordered">
  <a role="tab" class="tab">Tab 1</a>
  <a role="tab" class="tab tab-active">Tab 2</a>
  <a role="tab" class="tab">Tab 3</a>
</div>
```

## Lifted Tabs

```html
<div role="tablist" class="tabs tabs-lifted">
  <a role="tab" class="tab">Tab 1</a>
  <a role="tab" class="tab tab-active">Tab 2</a>
  <a role="tab" class="tab">Tab 3</a>
</div>
```

## Boxed Tabs

```html
<div role="tablist" class="tabs tabs-boxed">
  <a role="tab" class="tab">Tab 1</a>
  <a role="tab" class="tab tab-active">Tab 2</a>
  <a role="tab" class="tab">Tab 3</a>
</div>
```

## Sizes

```html
<!-- Extra small -->
<div role="tablist" class="tabs tabs-bordered tabs-xs">
  <a role="tab" class="tab">Tiny</a>
  <a role="tab" class="tab tab-active">Tiny</a>
  <a role="tab" class="tab">Tiny</a>
</div>

<!-- Small -->
<div role="tablist" class="tabs tabs-bordered tabs-sm">
  <a role="tab" class="tab">Small</a>
  <a role="tab" class="tab tab-active">Small</a>
  <a role="tab" class="tab">Small</a>
</div>

<!-- Medium (default) -->
<div role="tablist" class="tabs tabs-bordered tabs-md">
  <a role="tab" class="tab">Medium</a>
  <a role="tab" class="tab tab-active">Medium</a>
  <a role="tab" class="tab">Medium</a>
</div>

<!-- Large -->
<div role="tablist" class="tabs tabs-bordered tabs-lg">
  <a role="tab" class="tab">Large</a>
  <a role="tab" class="tab tab-active">Large</a>
  <a role="tab" class="tab">Large</a>
</div>
```

## With Tab Content

```html
<div role="tablist" class="tabs tabs-lifted">
  <input type="radio" name="my_tabs_1" role="tab" class="tab" aria-label="Tab 1" />
  <div role="tabpanel" class="tab-content bg-base-100 border-base-300 rounded-box p-6">
    Tab content 1
  </div>

  <input type="radio" name="my_tabs_1" role="tab" class="tab" aria-label="Tab 2" checked />
  <div role="tabpanel" class="tab-content bg-base-100 border-base-300 rounded-box p-6">
    Tab content 2
  </div>

  <input type="radio" name="my_tabs_1" role="tab" class="tab" aria-label="Tab 3" />
  <div role="tabpanel" class="tab-content bg-base-100 border-base-300 rounded-box p-6">
    Tab content 3
  </div>
</div>
```

## Bordered Tabs with Content

```html
<div role="tablist" class="tabs tabs-bordered">
  <input type="radio" name="my_tabs_2" role="tab" class="tab" aria-label="Tab 1" />
  <div role="tabpanel" class="tab-content p-10">Tab content 1</div>

  <input type="radio" name="my_tabs_2" role="tab" class="tab" aria-label="Tab 2" checked />
  <div role="tabpanel" class="tab-content p-10">Tab content 2</div>

  <input type="radio" name="my_tabs_2" role="tab" class="tab" aria-label="Tab 3" />
  <div role="tabpanel" class="tab-content p-10">Tab content 3</div>
</div>
```

## Disabled Tab

```html
<div role="tablist" class="tabs tabs-bordered">
  <a role="tab" class="tab">Tab 1</a>
  <a role="tab" class="tab tab-active">Tab 2</a>
  <a role="tab" class="tab tab-disabled">Disabled</a>
</div>
```

## With Icons

```html
<div role="tablist" class="tabs tabs-bordered">
  <a role="tab" class="tab">
    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
    </svg>
    Home
  </a>
  <a role="tab" class="tab tab-active">
    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
    </svg>
    Details
  </a>
  <a role="tab" class="tab">
    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
    </svg>
    Settings
  </a>
</div>
```

## Full Width

```html
<div role="tablist" class="tabs tabs-bordered w-full">
  <a role="tab" class="tab flex-1">Tab 1</a>
  <a role="tab" class="tab tab-active flex-1">Tab 2</a>
  <a role="tab" class="tab flex-1">Tab 3</a>
</div>
```

## Classes Reference

| Class | Description |
|-------|-------------|
| `tabs` | Container element |
| `tab` | Individual tab element |
| `tab-active` | Active tab state |
| `tab-disabled` | Disabled tab state |
| `tab-content` | Tab content panel |
| `tabs-bordered` | Bordered style |
| `tabs-lifted` | Lifted style |
| `tabs-boxed` | Boxed style |
| `tabs-xs` | Extra small size |
| `tabs-sm` | Small size |
| `tabs-md` | Medium size (default) |
| `tabs-lg` | Large size |
