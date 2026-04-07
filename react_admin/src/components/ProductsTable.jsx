import { useEffect, useState } from 'react';
import { collection, onSnapshot, doc, deleteDoc, updateDoc } from 'firebase/firestore';
import { db } from '../firebase';
import styles from './ProductsTable.module.css';

export default function ProductsTable({ onAddProduct }) {
  const [products, setProducts] = useState([]);
  const [sellers, setSellers]   = useState({});  // uid -> userData
  const [search, setSearch]     = useState('');
  const [category, setCategory] = useState('all');
  const [status, setStatus]     = useState('all');
  const [sortBy, setSortBy]     = useState('newest');
  const [viewProduct, setViewProduct] = useState(null);
  const [page, setPage]         = useState(1);
  const PAGE_SIZE = 10;

  useEffect(() => {
    const unsub1 = onSnapshot(collection(db, 'products'), (snap) => {
      setProducts(snap.docs.map(d => ({ id: d.id, ...d.data() })));
    });
    // Load all sellers
    const unsub2 = onSnapshot(collection(db, 'users'), (snap) => {
      const map = {};
      snap.docs.forEach(d => { map[d.id] = d.data(); });
      setSellers(map);
    });
    return () => { unsub1(); unsub2(); };
  }, []);

  const handleDelete = async (id) => {
    if (window.confirm('Are you sure you want to delete this product?')) {
      await deleteDoc(doc(db, 'products', id));
    }
  };

  const toggleAvailability = async (id, current) => {
    await updateDoc(doc(db, 'products', id), { isAvailable: !current });
  };

  const categories = ['all', ...new Set(products.map(p => p.category).filter(Boolean))];

  const filtered = products
    .filter(p => {
      const q = search.toLowerCase();
      const matchSearch = !q ||
        (p.name || '').toLowerCase().includes(q) ||
        (p.category || '').toLowerCase().includes(q) ||
        (p.location || '').toLowerCase().includes(q);
      const matchCat = category === 'all' || p.category === category;
      const matchStatus = status === 'all' ||
        (status === 'active' && p.isAvailable) ||
        (status === 'inactive' && !p.isAvailable);
      return matchSearch && matchCat && matchStatus;
    })
    .sort((a, b) => {
      if (sortBy === 'oldest') return (a.createdAt || 0) - (b.createdAt || 0);
      if (sortBy === 'price_high') return (b.price || 0) - (a.price || 0);
      if (sortBy === 'price_low') return (a.price || 0) - (b.price || 0);
      if (sortBy === 'name') return (a.name || '').localeCompare(b.name || '');
      return (b.createdAt || 0) - (a.createdAt || 0);
    });

  const totalPages = Math.ceil(filtered.length / PAGE_SIZE);
  const paginated  = filtered.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);

  const resetPage = () => setPage(1);

  return (
    <div>
      <div className={styles.header}>
        <h2 className={styles.title}>Product Management</h2>
        <div style={{display:'flex', alignItems:'center', gap:'12px'}}>
          <span className={styles.count}>{filtered.length} products</span>
          <button className={styles.addBtn} onClick={onAddProduct}>+ Add Product</button>
        </div>
      </div>

      {/* Toolbar */}
      <div className={styles.toolbar}>
        <input className={styles.search} placeholder="Search by name, category, location..."
          value={search} onChange={e => { setSearch(e.target.value); resetPage(); }} />
        <select className={styles.filter} value={category} onChange={e => { setCategory(e.target.value); resetPage(); }}>
          {categories.map(c => <option key={c} value={c}>{c === 'all' ? 'All Categories' : c}</option>)}
        </select>
        <select className={styles.filter} value={status} onChange={e => { setStatus(e.target.value); resetPage(); }}>
          <option value="all">All Status</option>
          <option value="active">Active</option>
          <option value="inactive">Inactive</option>
        </select>
        <select className={styles.filter} value={sortBy} onChange={e => { setSortBy(e.target.value); resetPage(); }}>
          <option value="newest">Newest</option>
          <option value="oldest">Oldest</option>
          <option value="price_high">Price ↑</option>
          <option value="price_low">Price ↓</option>
          <option value="name">Name A-Z</option>
        </select>
      </div>

      {/* Table */}
      <div className={styles.tableWrap}>
        <table className={styles.table}>
          <thead>
            <tr>
              <th>Product</th>
              <th>Seller</th>
              <th>Category</th>
              <th>Price</th>
              <th>Stock</th>
              <th>Location</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {paginated.length === 0 ? (
              <tr><td colSpan={8} className={styles.empty}>No products found</td></tr>
            ) : paginated.map(p => {
              const seller = sellers[p.sellerId];
              return (
              <tr key={p.id}>
                <td>
                  <div className={styles.productCell}>
                    {p.imageUrl
                      ? <img src={p.imageUrl} alt={p.name} className={styles.thumb} />
                      : <div className={styles.noImg}>📦</div>
                    }
                    <span className={styles.productName}>{p.name || 'N/A'}</span>
                  </div>
                </td>
                <td>
                  <div className={styles.sellerCell}>
                    <div className={styles.sellerAvatar}>{(seller?.username || '?').charAt(0).toUpperCase()}</div>
                    <div>
                      <div className={styles.sellerName}>{seller?.username || 'Unknown'}</div>
                      <div className={styles.sellerEmail}>{seller?.email || ''}</div>
                    </div>
                  </div>
                </td>
                <td><span className={styles.catBadge}>{p.category || 'N/A'}</span></td>
                <td className={styles.price}>TShs {p.price?.toLocaleString()} / {p.unit}</td>
                <td>{p.stock} {p.unit}</td>
                <td>{p.location || 'N/A'}</td>
                <td>
                  <button
                    className={`${styles.statusBtn} ${p.isAvailable ? styles.active : styles.inactive}`}
                    onClick={() => toggleAvailability(p.id, p.isAvailable)}
                  >
                    {p.isAvailable ? 'Active' : 'Inactive'}
                  </button>
                </td>
                <td>
                  <div className={styles.actions}>
                    <button className={styles.viewBtn} onClick={() => setViewProduct({...p, seller})} title="View">
                      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                        <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/>
                        <circle cx="12" cy="12" r="3"/>
                      </svg>
                    </button>
                    <button className={styles.deleteBtn} onClick={() => handleDelete(p.id)} title="Delete">🗑</button>
                  </div>
                </td>
              </tr>
            );})}
          </tbody>
        </table>
      </div>

      {/* Pagination */}
      {totalPages > 1 && (
        <div className={styles.pagination}>
          <button className={styles.pageBtn} onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page === 1}>← Previous</button>
          <span className={styles.pageInfo}>Page {page} of {totalPages} ({filtered.length} products)</span>
          <button className={styles.pageBtn} onClick={() => setPage(p => Math.min(totalPages, p + 1))} disabled={page === totalPages}>Next →</button>
        </div>
      )}

      {/* View Modal */}
      {viewProduct && (
        <div className={styles.overlay} onClick={() => setViewProduct(null)}>
          <div className={styles.modal} onClick={e => e.stopPropagation()}>
            <div className={styles.modalHeader}>
              <h3>Product Details</h3>
              <button className={styles.closeBtn} onClick={() => setViewProduct(null)}>✕</button>
            </div>
            {viewProduct.imageUrl && (
              <img src={viewProduct.imageUrl} alt={viewProduct.name} className={styles.modalImg} />
            )}
            <div className={styles.viewGrid}>
              {[
                ['Name', viewProduct.name],
                ['Seller', viewProduct.seller?.username || 'Unknown'],
                ['Seller Email', viewProduct.seller?.email || 'N/A'],
                ['Category', viewProduct.category],
                ['Price', `TShs ${viewProduct.price?.toLocaleString()} / ${viewProduct.unit}`],
                ['Stock', `${viewProduct.stock} ${viewProduct.unit}`],
                ['Location', viewProduct.location],
                ['Description', viewProduct.description],
                ['Status', viewProduct.isAvailable ? 'Active' : 'Inactive'],
                ['Added', viewProduct.createdAt ? new Date(viewProduct.createdAt).toLocaleDateString() : 'N/A'],
              ].map(([label, value]) => (
                <div key={label} className={styles.viewRow}>
                  <span className={styles.viewLabel}>{label}</span>
                  <span className={styles.viewValue}>{value || 'N/A'}</span>
                </div>
              ))}
            </div>
            <div className={styles.modalFooter}>
              <button className={styles.cancelBtn} onClick={() => setViewProduct(null)}>Close</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
