# Pricing Cards

**Components**: card, badge, button, divider, list

SaaS pricing comparison layout.

```html
<div class="flex flex-col lg:flex-row gap-6 justify-center p-6">
  <!-- Free tier -->
  <div class="card bg-base-100 shadow-xl w-80">
    <div class="card-body">
      <h2 class="card-title">Free</h2>
      <p class="text-3xl font-bold">$0<span class="text-base font-normal">/mo</span></p>
      <p class="text-base-content/60">For individuals getting started</p>
      
      <div class="divider"></div>
      
      <ul class="space-y-2">
        <li class="flex items-center gap-2">
          <svg class="h-5 w-5 text-success" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
          </svg>
          5 projects
        </li>
        <li class="flex items-center gap-2">
          <svg class="h-5 w-5 text-success" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
          </svg>
          1GB storage
        </li>
        <li class="flex items-center gap-2 opacity-50">
          <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
          Custom domain
        </li>
      </ul>
      
      <div class="card-actions mt-6">
        <button class="btn btn-outline w-full">Get Started</button>
      </div>
    </div>
  </div>

  <!-- Pro tier (featured) -->
  <div class="card bg-primary text-primary-content shadow-xl w-80">
    <div class="card-body">
      <div class="flex justify-between items-center">
        <h2 class="card-title">Pro</h2>
        <div class="badge badge-secondary">Popular</div>
      </div>
      <p class="text-3xl font-bold">$19<span class="text-base font-normal opacity-80">/mo</span></p>
      <p class="opacity-80">For professionals and small teams</p>
      
      <div class="divider before:bg-primary-content/20 after:bg-primary-content/20"></div>
      
      <ul class="space-y-2">
        <li class="flex items-center gap-2">
          <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
          </svg>
          Unlimited projects
        </li>
        <li class="flex items-center gap-2">
          <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
          </svg>
          100GB storage
        </li>
        <li class="flex items-center gap-2">
          <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
          </svg>
          Custom domain
        </li>
      </ul>
      
      <div class="card-actions mt-6">
        <button class="btn btn-secondary w-full">Subscribe</button>
      </div>
    </div>
  </div>

  <!-- Enterprise tier -->
  <div class="card bg-base-100 shadow-xl w-80">
    <div class="card-body">
      <h2 class="card-title">Enterprise</h2>
      <p class="text-3xl font-bold">Custom</p>
      <p class="text-base-content/60">For large organizations</p>
      
      <div class="divider"></div>
      
      <ul class="space-y-2">
        <li class="flex items-center gap-2">
          <svg class="h-5 w-5 text-success" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
          </svg>
          Everything in Pro
        </li>
        <li class="flex items-center gap-2">
          <svg class="h-5 w-5 text-success" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
          </svg>
          SSO & SAML
        </li>
      </ul>
      
      <div class="card-actions mt-6">
        <button class="btn btn-outline w-full">Contact Sales</button>
      </div>
    </div>
  </div>
</div>
```

## Usage Notes

- Use `bg-primary text-primary-content` to highlight the recommended tier
- Add "Popular" badge to draw attention to featured plan
- Use check/x icons to show included/excluded features
- Reduce opacity for unavailable features
- Stack cards vertically on mobile with `flex-col lg:flex-row`

## Related Components

- [Card](../components/card.md)
- [Badge](../components/badge.md)
- [Button](../components/button.md)
- [Divider](../components/divider.md)
