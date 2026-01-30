# daisyUI Common Patterns

Practical patterns combining multiple daisyUI components for common UI scenarios.

## Dashboard Layout

**Components**: stats, card, drawer

Stats row + Card content area inside a drawer layout. See `drawer.md` "With navbar" for the full drawer+navbar structure.

```html
<!-- Main content area (inside drawer-content) -->
<main class="flex-1 p-6">
  <!-- Stats row -->
  <div class="stats shadow w-full mb-6">
    <div class="stat">
      <div class="stat-title">Total Users</div>
      <div class="stat-value">89,400</div>
      <div class="stat-desc">21% more than last month</div>
    </div>
    <div class="stat">
      <div class="stat-title">Revenue</div>
      <div class="stat-value text-primary">$25,600</div>
      <div class="stat-desc">12% increase</div>
    </div>
  </div>

  <!-- Content cards -->
  <div class="card bg-base-100 shadow">
    <div class="card-body">
      <h2 class="card-title">Content</h2>
      <p>Dashboard content goes here.</p>
    </div>
  </div>
</main>
```

## Authentication Page

**Components**: card, input, checkbox, button, divider

Card-based login form combining card + input + checkbox:

```html
<div class="min-h-screen flex items-center justify-center bg-base-200">
  <div class="card w-full max-w-sm bg-base-100 shadow-xl">
    <div class="card-body">
      <h2 class="card-title justify-center text-2xl font-bold">Login</h2>

      <form class="space-y-4 mt-4">
        <label class="form-control">
          <div class="label"><span class="label-text">Email</span></div>
          <input type="email" placeholder="email@example.com" class="input w-full" required />
        </label>

        <label class="form-control">
          <div class="label"><span class="label-text">Password</span></div>
          <input type="password" placeholder="Enter password" class="input w-full" required />
          <div class="label">
            <a href="#" class="label-text-alt link link-hover">Forgot password?</a>
          </div>
        </label>

        <label class="label cursor-pointer justify-start gap-2">
          <input type="checkbox" class="checkbox checkbox-sm" />
          <span class="label-text">Remember me</span>
        </label>

        <button class="btn btn-primary w-full">Login</button>
      </form>

      <div class="divider">OR</div>
      <button class="btn btn-outline w-full">Continue with Google</button>
    </div>
  </div>
</div>
```

## Toast Notifications

**Components**: toast, alert

JavaScript toast manager for dynamic notifications:

```javascript
function showToast(message, type = 'info', duration = 3000) {
  const container = document.getElementById('toast-container') 
    || createToastContainer();
  
  const toast = document.createElement('div');
  toast.className = `alert alert-${type}`;
  toast.innerHTML = `<span>${message}</span>`;
  
  container.appendChild(toast);
  
  setTimeout(() => {
    toast.remove();
  }, duration);
}

function createToastContainer() {
  const container = document.createElement('div');
  container.id = 'toast-container';
  container.className = 'toast toast-end';
  document.body.appendChild(container);
  return container;
}

// Usage
showToast('File uploaded!', 'success');
showToast('Something went wrong', 'error');
```

## Data Table with Actions

**Components**: table, checkbox, avatar, badge, dropdown, menu, join, button

Table with row actions and pagination. See also `table.md` for base table usage and sizes.

```html
<div class="overflow-x-auto">
  <table class="table">
    <thead>
      <tr>
        <th>
          <label>
            <input type="checkbox" class="checkbox" />
          </label>
        </th>
        <th>Name</th>
        <th>Email</th>
        <th>Status</th>
        <th>Actions</th>
      </tr>
    </thead>
    <tbody>
      <tr class="hover">
        <th>
          <label>
            <input type="checkbox" class="checkbox" />
          </label>
        </th>
        <td>
          <div class="flex items-center gap-3">
            <div class="avatar">
              <div class="mask mask-squircle w-10 h-10">
                <img src="avatar.jpg" alt="Avatar" />
              </div>
            </div>
            <div>
              <div class="font-bold">John Doe</div>
              <div class="text-sm opacity-50">United States</div>
            </div>
          </div>
        </td>
        <td>john@example.com</td>
        <td>
          <div class="badge badge-success gap-2">Active</div>
        </td>
        <td>
          <div class="dropdown dropdown-end">
            <label tabindex="0" class="btn btn-ghost btn-sm">⋮</label>
            <ul tabindex="0" class="dropdown-content z-[1] menu p-2 shadow bg-base-100 rounded-box w-32">
              <li><a>Edit</a></li>
              <li><a>View</a></li>
              <li><a class="text-error">Delete</a></li>
            </ul>
          </div>
        </td>
      </tr>
    </tbody>
  </table>
</div>

<!-- Pagination -->
<div class="flex justify-center mt-4">
  <div class="join">
    <button class="join-item btn">«</button>
    <button class="join-item btn">1</button>
    <button class="join-item btn btn-active">2</button>
    <button class="join-item btn">3</button>
    <button class="join-item btn">»</button>
  </div>
</div>
```

## Form with Validation Feedback

**Components**: input, join, button

Form inputs with validation states:

```html
<form class="space-y-4">
  <!-- Valid input -->
  <div class="form-control">
    <label class="label">
      <span class="label-text">Email</span>
    </label>
    <input type="email" value="valid@email.com" class="input input-bordered input-success" />
    <label class="label">
      <span class="label-text-alt text-success">Email is valid</span>
    </label>
  </div>
  
  <!-- Invalid input -->
  <div class="form-control">
    <label class="label">
      <span class="label-text">Password</span>
    </label>
    <input type="password" class="input input-bordered input-error" />
    <label class="label">
      <span class="label-text-alt text-error">Password must be at least 8 characters</span>
    </label>
  </div>
  
  <!-- Input with icon button -->
  <div class="form-control">
    <label class="label">
      <span class="label-text">Search</span>
    </label>
    <div class="join">
      <input type="text" placeholder="Search..." class="input input-bordered join-item flex-1" />
      <button class="btn btn-primary join-item">Search</button>
    </div>
  </div>
</form>
```

## Loading States

**Components**: skeleton, card

Skeleton loading for cards and lists:

```html
<!-- Skeleton card -->
<div class="card w-96 bg-base-100 shadow">
  <figure class="skeleton h-48 w-full"></figure>
  <div class="card-body">
    <div class="skeleton h-6 w-3/4"></div>
    <div class="skeleton h-4 w-full"></div>
    <div class="skeleton h-4 w-2/3"></div>
    <div class="card-actions justify-end mt-4">
      <div class="skeleton h-10 w-24"></div>
    </div>
  </div>
</div>

<!-- Skeleton list -->
<div class="flex flex-col gap-4">
  <div class="flex items-center gap-4">
    <div class="skeleton h-12 w-12 shrink-0 rounded-full"></div>
    <div class="flex flex-col gap-2 flex-1">
      <div class="skeleton h-4 w-1/2"></div>
      <div class="skeleton h-3 w-3/4"></div>
    </div>
  </div>
</div>
```

## Settings Page

**Components**: card, toggle, select, divider

User settings panel with grouped options:

```html
<div class="card bg-base-100 shadow-xl max-w-2xl mx-auto">
  <div class="card-body">
    <h2 class="card-title text-2xl">Settings</h2>
    
    <!-- Notifications Section -->
    <div class="py-4">
      <h3 class="font-semibold mb-4">Notifications</h3>
      <div class="space-y-4">
        <div class="form-control">
          <label class="label cursor-pointer">
            <span class="label-text">Email notifications</span>
            <input type="checkbox" class="toggle toggle-primary" checked />
          </label>
        </div>
        <div class="form-control">
          <label class="label cursor-pointer">
            <span class="label-text">Push notifications</span>
            <input type="checkbox" class="toggle toggle-primary" />
          </label>
        </div>
        <div class="form-control">
          <label class="label cursor-pointer">
            <span class="label-text">Weekly digest</span>
            <input type="checkbox" class="toggle toggle-primary" checked />
          </label>
        </div>
      </div>
    </div>

    <div class="divider"></div>

    <!-- Preferences Section -->
    <div class="py-4">
      <h3 class="font-semibold mb-4">Preferences</h3>
      <div class="space-y-4">
        <label class="form-control w-full">
          <div class="label"><span class="label-text">Language</span></div>
          <select class="select select-bordered w-full">
            <option>English</option>
            <option>Japanese</option>
            <option>Spanish</option>
          </select>
        </label>
        <label class="form-control w-full">
          <div class="label"><span class="label-text">Timezone</span></div>
          <select class="select select-bordered w-full">
            <option>UTC</option>
            <option>Asia/Tokyo</option>
            <option>America/New_York</option>
          </select>
        </label>
      </div>
    </div>

    <div class="card-actions justify-end mt-4">
      <button class="btn btn-ghost">Cancel</button>
      <button class="btn btn-primary">Save Changes</button>
    </div>
  </div>
</div>
```

## User Profile Card

**Components**: card, avatar, badge, stats

User information display with metrics:

```html
<div class="card bg-base-100 shadow-xl w-96">
  <div class="card-body items-center text-center">
    <div class="avatar avatar-online">
      <div class="w-24 rounded-full ring ring-primary ring-offset-base-100 ring-offset-2">
        <img src="avatar.jpg" alt="User avatar" />
      </div>
    </div>
    <h2 class="card-title mt-4">Jane Doe</h2>
    <p class="text-base-content/60">Product Designer</p>
    <div class="flex gap-2 mt-2">
      <div class="badge badge-primary">Design</div>
      <div class="badge badge-secondary">UX</div>
      <div class="badge badge-accent">Research</div>
    </div>
    
    <div class="stats stats-vertical lg:stats-horizontal shadow mt-6 w-full">
      <div class="stat place-items-center">
        <div class="stat-title">Projects</div>
        <div class="stat-value text-primary">31</div>
      </div>
      <div class="stat place-items-center">
        <div class="stat-title">Followers</div>
        <div class="stat-value">4.2K</div>
      </div>
      <div class="stat place-items-center">
        <div class="stat-title">Following</div>
        <div class="stat-value text-secondary">89</div>
      </div>
    </div>

    <div class="card-actions mt-4">
      <button class="btn btn-primary">Follow</button>
      <button class="btn btn-ghost">Message</button>
    </div>
  </div>
</div>
```

## Confirmation Modal

**Components**: modal, button

Destructive action confirmation dialog:

```html
<button class="btn btn-error" onclick="confirm_modal.showModal()">Delete Item</button>

<dialog id="confirm_modal" class="modal modal-bottom sm:modal-middle">
  <div class="modal-box">
    <h3 class="text-lg font-bold">Confirm Deletion</h3>
    <p class="py-4">Are you sure you want to delete this item? This action cannot be undone.</p>
    <div class="modal-action">
      <form method="dialog">
        <button class="btn btn-ghost">Cancel</button>
      </form>
      <button class="btn btn-error" onclick="deleteItem(); confirm_modal.close();">Delete</button>
    </div>
  </div>
  <form method="dialog" class="modal-backdrop">
    <button>close</button>
  </form>
</dialog>
```

## Search with Filters

**Components**: input, dropdown, checkbox, badge, button

Search interface with filter options:

```html
<div class="flex flex-col gap-4 max-w-2xl">
  <!-- Search bar -->
  <div class="join w-full">
    <input type="text" placeholder="Search..." class="input input-bordered join-item flex-1" />
    <div class="dropdown dropdown-end">
      <label tabindex="0" class="btn join-item">
        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 4a1 1 0 011-1h16a1 1 0 011 1v2.586a1 1 0 01-.293.707l-6.414 6.414a1 1 0 00-.293.707V17l-4 4v-6.586a1 1 0 00-.293-.707L3.293 7.293A1 1 0 013 6.586V4z" />
        </svg>
        Filters
      </label>
      <div tabindex="0" class="dropdown-content z-[1] card card-compact w-64 p-2 shadow bg-base-100">
        <div class="card-body">
          <h3 class="font-bold">Filter by</h3>
          <div class="form-control">
            <label class="label cursor-pointer">
              <span class="label-text">Active only</span>
              <input type="checkbox" class="checkbox checkbox-sm" checked />
            </label>
          </div>
          <div class="form-control">
            <label class="label cursor-pointer">
              <span class="label-text">Verified users</span>
              <input type="checkbox" class="checkbox checkbox-sm" />
            </label>
          </div>
          <div class="form-control">
            <label class="label cursor-pointer">
              <span class="label-text">Recent (7 days)</span>
              <input type="checkbox" class="checkbox checkbox-sm" />
            </label>
          </div>
        </div>
      </div>
    </div>
    <button class="btn btn-primary join-item">Search</button>
  </div>

  <!-- Active filters display -->
  <div class="flex flex-wrap gap-2">
    <div class="badge badge-primary gap-1">
      Active only
      <button class="btn btn-ghost btn-xs p-0">✕</button>
    </div>
    <div class="badge badge-secondary gap-1">
      Category: Design
      <button class="btn btn-ghost btn-xs p-0">✕</button>
    </div>
  </div>
</div>
```

## Sidebar Navigation

**Components**: drawer, menu, avatar, divider

Complete sidebar with user info and navigation:

```html
<div class="drawer lg:drawer-open">
  <input id="sidebar" type="checkbox" class="drawer-toggle" />
  <div class="drawer-content">
    <!-- Page content -->
    <label for="sidebar" class="btn btn-primary drawer-button lg:hidden m-4">
      Open Menu
    </label>
  </div>
  <div class="drawer-side">
    <label for="sidebar" aria-label="close sidebar" class="drawer-overlay"></label>
    <aside class="bg-base-200 min-h-full w-80 p-4">
      <!-- User info -->
      <div class="flex items-center gap-4 p-4">
        <div class="avatar">
          <div class="w-12 rounded-full">
            <img src="avatar.jpg" alt="User" />
          </div>
        </div>
        <div>
          <p class="font-bold">Jane Doe</p>
          <p class="text-sm opacity-60">jane@example.com</p>
        </div>
      </div>

      <div class="divider my-2"></div>

      <!-- Navigation -->
      <ul class="menu">
        <li class="menu-title">Main</li>
        <li><a class="menu-active">Dashboard</a></li>
        <li><a>Projects</a></li>
        <li><a>Team</a></li>
        <li class="menu-title">Settings</li>
        <li><a>Profile</a></li>
        <li><a>Preferences</a></li>
        <li>
          <details>
            <summary>Advanced</summary>
            <ul>
              <li><a>API Keys</a></li>
              <li><a>Webhooks</a></li>
            </ul>
          </details>
        </li>
      </ul>

      <div class="divider my-2"></div>

      <!-- Logout -->
      <ul class="menu">
        <li><a class="text-error">Logout</a></li>
      </ul>
    </aside>
  </div>
</div>
```

## Pricing Cards

**Components**: card, badge, button, divider, list

SaaS pricing comparison:

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
        <li class="flex items-center gap-2">
          <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
          </svg>
          Priority support
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
          Unlimited storage
        </li>
        <li class="flex items-center gap-2">
          <svg class="h-5 w-5 text-success" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
          </svg>
          SSO & SAML
        </li>
        <li class="flex items-center gap-2">
          <svg class="h-5 w-5 text-success" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
          </svg>
          Dedicated support
        </li>
      </ul>
      
      <div class="card-actions mt-6">
        <button class="btn btn-outline w-full">Contact Sales</button>
      </div>
    </div>
  </div>
</div>
```
