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
