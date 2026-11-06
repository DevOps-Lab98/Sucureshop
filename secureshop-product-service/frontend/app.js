// app.js — talks to the Product Service REST API
// Set this to your backend's base URL (e.g. via ingress path /api)
const API_BASE = 'http://20.207.65.48:3000/api/products';

const form = document.getElementById('productForm');
const productIdField = document.getElementById('productId');
const nameField = document.getElementById('name');
const descField = document.getElementById('description');
const priceField = document.getElementById('price');
const stockField = document.getElementById('stock');
const formTitle = document.getElementById('formTitle');
const submitBtn = document.getElementById('submitBtn');
const cancelBtn = document.getElementById('cancelEdit');
const formError = document.getElementById('formError');
const listEl = document.getElementById('productList');
const statusEl = document.getElementById('apiStatus');
const refreshBtn = document.getElementById('refreshBtn');

async function checkHealth() {
  try {
    const res = await fetch(API_BASE.replace('/api/products', '') + '/healthz');
    if (res.ok) {
      statusEl.textContent = 'API connected';
      statusEl.className = 'status ok';
    } else {
      throw new Error('unhealthy');
    }
  } catch {
    statusEl.textContent = 'API unreachable';
    statusEl.className = 'status down';
  }
}

function renderProducts(products) {
  if (!products.length) {
    listEl.innerHTML = '<p class="empty">No products yet. Add one on the left.</p>';
    return;
  }
  listEl.innerHTML = products.map(p => `
    <div class="product-card" data-id="${p.id}">
      <div>
        <h3>${escapeHtml(p.name)}</h3>
        <p>${escapeHtml(p.description || '')}</p>
        <div class="product-meta">
          <span>₹${Number(p.price).toFixed(2)}</span>
          <span>Stock: ${p.stock}</span>
        </div>
      </div>
      <div class="product-actions">
        <button class="edit" data-action="edit">Edit</button>
        <button class="delete" data-action="delete">Delete</button>
      </div>
    </div>
  `).join('');
}

function escapeHtml(str) {
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}

async function loadProducts() {
  listEl.innerHTML = '<p class="empty">Loading products…</p>';
  try {
    const res = await fetch(API_BASE);
    if (!res.ok) throw new Error('Failed to load');
    const data = await res.json();
    renderProducts(data);
  } catch (err) {
    listEl.innerHTML = '<p class="empty">Could not load products. Is the API running?</p>';
  }
}

function resetForm() {
  form.reset();
  productIdField.value = '';
  formTitle.textContent = 'Add product';
  submitBtn.textContent = 'Add product';
  cancelBtn.hidden = true;
  formError.textContent = '';
}

form.addEventListener('submit', async (e) => {
  e.preventDefault();
  formError.textContent = '';

  const payload = {
    name: nameField.value.trim(),
    description: descField.value.trim(),
    price: parseFloat(priceField.value),
    stock: parseInt(stockField.value || '0', 10)
  };

  const id = productIdField.value;
  const isEdit = Boolean(id);
  const url = isEdit ? `${API_BASE}/${id}` : API_BASE;
  const method = isEdit ? 'PUT' : 'POST';

  try {
    const res = await fetch(url, {
      method,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      throw new Error((body.errors && body.errors.join(', ')) || body.error || 'Request failed');
    }
    resetForm();
    loadProducts();
  } catch (err) {
    formError.textContent = err.message;
  }
});

cancelBtn.addEventListener('click', resetForm);
refreshBtn.addEventListener('click', loadProducts);

listEl.addEventListener('click', async (e) => {
  const btn = e.target.closest('button');
  if (!btn) return;
  const card = e.target.closest('.product-card');
  const id = card.dataset.id;
  const action = btn.dataset.action;

  if (action === 'delete') {
    if (!confirm('Delete this product?')) return;
    try {
      const res = await fetch(`${API_BASE}/${id}`, { method: 'DELETE' });
      if (!res.ok && res.status !== 204) throw new Error('Delete failed');
      loadProducts();
    } catch (err) {
      alert(err.message);
    }
  }

  if (action === 'edit') {
    try {
      const res = await fetch(`${API_BASE}/${id}`);
      if (!res.ok) throw new Error('Could not load product');
      const p = await res.json();
      productIdField.value = p.id;
      nameField.value = p.name;
      descField.value = p.description || '';
      priceField.value = p.price;
      stockField.value = p.stock;
      formTitle.textContent = 'Edit product';
      submitBtn.textContent = 'Save changes';
      cancelBtn.hidden = false;
    } catch (err) {
      alert(err.message);
    }
  }
});

checkHealth();
loadProducts();
