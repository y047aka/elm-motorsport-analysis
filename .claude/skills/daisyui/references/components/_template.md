<!--
TEMPLATE GUIDE:
This template is for creating high-precision references for the daisyUI skill.
Omit general information that Claude Code already knows and focus only on daisyUI-specific information.

【KEY PRINCIPLES】
- Do NOT document color variants (primary/secondary, etc.) → Claude Code already knows these
- Do NOT document size variants (xs/sm/md/lg/xl) if they follow standard patterns → Only document special sizes
- Do NOT document responsive prefixes (`sm:btn-sm`, etc.) → Standard Tailwind functionality
- Do NOT document simple HTML attributes (disabled, etc.) → Common knowledge

【WHAT TO DOCUMENT】
1. daisyUI-specific class names (modal-box, modal-backdrop, etc.)
2. Required HTML structure (dialog elements, form method="dialog", etc.)
3. Component-specific constraints (form tag inside modal-action, etc.)
4. Browser API integration (element.showModal(), etc.)
5. daisyUI-specific modifiers (btn-wide, btn-square, etc.)

How to use:
1. Replace placeholders like {ComponentName}, {prefix}, etc.
2. Add official documentation URL ({official_url})
3. Only add supplementary explanations in Class Reference when official docs are unclear
4. Keep only necessary sections in Essential Examples
5. Delete all unnecessary sections
-->

# {ComponentName}

{One-line concise description - document daisyUI-specific features}

## Class Reference

Official documentation: {official_url}

<!--
【BASIC POLICY】
Refer to the Class name table in the official documentation.
Only add supplementary explanations in the following cases:

✅ SHOULD document:
- Detailed explanations for classes with unclear official descriptions
- Required combinations (e.g., "modal-box must be used inside modal")
- HTML structure constraints (e.g., "modal-backdrop should be used with form method='dialog'")
- Browser API integration (e.g., "modal-open is automatically added by dialog.showModal()")

❌ Should NOT document:
- Simple listing of class names already documented in official docs
- Type classifications (already in official table)
- Common color/size variants

If no supplementary notes are needed, keep only "Official documentation: {url}" in this section
-->

<!-- Only include the following when official information is unclear -->
| Class name | Notes |
|------------|-------|
| `{specific-class}` | {Detailed explanation for points unclear in official docs} |


## Essential Examples

### Basic usage

```html
<!-- Copy-paste ready minimal implementation - required classes and HTML structure only -->
```

### With structure

```html
<!-- Only include when complex HTML structure is required
     e.g., dialog elements for modal, hierarchical structure for dropdown, form method="dialog", etc.

     Delete if structure is simple (like <button class="btn">) -->
```

### Interactive

```html
<!-- Only include when browser API integration is required
     e.g., dialog.showModal(), checkbox:checked pseudo-class, etc.

     Delete if no API integration is needed -->
```

<!--
Section deletion criteria:
- "Basic usage": Required (do not delete)
- "With structure": Delete if structure is simple
- "Interactive": Delete if no browser API integration

Deprecated sections:
- "Colors and styles" → Claude Code already knows color/style patterns
- "States" → Not needed as it's HTML standard
- "Responsive" → Not needed as it's standard Tailwind functionality
- "Icon buttons" → Not needed as it's a common HTML pattern
-->

## Notes

<!--
Documentation criteria:
✅ Required: daisyUI-specific constraints (form tag in modal-action, use of dialog element, etc.)
✅ Recommended: daisyUI-specific accessibility patterns
✅ Deprecated: v4.x breaking changes, old class names
❌ Not needed: General browser behavior, HTML standard knowledge

Delete the entire Notes section if there are no notes to document
-->

- **Required**: {daisyUI-specific constraints}
- **Recommended**: {daisyUI-specific accessibility patterns}
- **Deprecated**: {Information changed in v4.x}
