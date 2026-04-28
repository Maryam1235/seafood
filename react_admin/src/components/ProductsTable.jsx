import { useEffect, useState } from 'react';
import { collection, onSnapshot, doc, deleteDoc, updateDoc } from 'firebase/firestore';
import { db } from '../firebase';
import { Eye, Pencil, Trash2 } from 'lucide-react';
import styles from './ProductsTable.module.css';

export default function ProductsTable({ onAddProduct, onEditProduct }) {
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
        <button className={styles.addBtn} onClick={onAddProduct}>+ Add Product</button>
      </div>

      {/* Stats */}
      <div className={styles.statsRow}>
        {[
          { label: 'Total Products', value: products.length,                                    color: '#4f46e5', bg: '#e0e7ff' },
          { label: 'Active',         value: products.filter(p => p.isAvailable).length,         color: '#065f46', bg: '#d1fae5' },
          { label: 'Inactive',       value: products.filter(p => !p.isAvailable).length,        color: '#dc2626', bg: '#fee2e2' },
          { label: 'Categories',     value: new Set(products.map(p => p.category).filter(Boolean)).size, color: '#7c3aed', bg: '#ede9fe' },
          { label: 'Sellers',        value: new Set(products.map(p => p.sellerId).filter(Boolean)).size, color: '#0369a1', bg: '#e0f2fe' },
        ].map(s => (
          <div key={s.label} className={styles.statCard} style={{ borderTop: `3px solid ${s.color}` }}>
            <div className={styles.statValue} style={{ color: s.color }}>{s.value}</div>
            <div className={styles.statLabel}>{s.label}</div>
          </div>
        ))}
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
                      <Eye size={16} />
                    </button>
                    <button className={styles.editBtn} onClick={() => onEditProduct({...p})} title="Edit">
                      <Pencil size={16} />
                    </button>
                    <button className={styles.deleteBtn} onClick={() => handleDelete(p.id)} title="Delete">
                      <Trash2 size={14} />
                    </button>
                  </div>
                </td>
              </tr>
            );})}
          </tbody>
        </table>
      </div>

      {/* Pagination */}
      {totalPages > 0 && (
        <div className={styles.pagination}>
          <button className={styles.pageBtn} onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page === 1}>← Previous</button>
          <span className={styles.pageInfo}>Page {page} of {totalPages || 1} ({filtered.length} products)</span>
          <button className={styles.pageBtn} onClick={() => setPage(p => Math.min(totalPages, p + 1))} disabled={page === totalPages || totalPages === 0}>Next →</button>
        </div>
      )}

      {/* View Modal */}
      {viewProduct && (
        <div className={styles.overlay} onClick={() => setViewProduct(null)}>
          <div className={styles.modal} onClick={e => e.stopPropagation()}>
            {/* Header */}
            <div className={styles.modalHeader}>
              <h3>Product Details</h3>
              <button className={styles.closeBtn} onClick={() => setViewProduct(null)}>✕</button>
            </div>

            <div className={styles.modalBody}>
              {/* Product image + name hero */}
              <div className={styles.productHero}>
                {viewProduct.imageUrl
                  ? <img src={viewProduct.imageUrl} alt={viewProduct.name} className={styles.heroImg} />
                  : <div className={styles.heroPlaceholder}>📦</div>
                }
                <div className={styles.heroInfo}>
                  <h2 className={styles.heroName}>{viewProduct.name}</h2>
                  <span className={`${styles.heroBadge} ${viewProduct.isAvailable ? styles.active : styles.inactive}`}>
                    {viewProduct.isAvailable ? 'Active' : 'Inactive'}
                  </span>
                  <p className={styles.heroPrice}>TShs {viewProduct.price?.toLocaleString()} / {viewProduct.unit}</p>
                  <p className={styles.heroStock}>Stock: {viewProduct.stock} {viewProduct.unit}</p>
                </div>
              </div>

              {/* Seller info */}
              <div className={styles.sectionTitle}>Seller Information</div>
              <div className={styles.infoCard}>
                <div className={styles.sellerRow}>
                  <div className={styles.sellerAvatarLg}>
                    {(viewProduct.seller?.username || '?').charAt(0).toUpperCase()}
                  </div>
                  <div>
                    <div className={styles.sellerNameLg}>{viewProduct.seller?.username || 'Unknown'}</div>
                    <div className={styles.sellerEmailLg}>{viewProduct.seller?.email || 'N/A'}</div>
                  </div>
                </div>
              </div>

              {/* Product details */}
              <div className={styles.sectionTitle}>Product Details</div>
              <div className={styles.infoCard}>
                {[
                  ['Category', viewProduct.category],
                  ['Location', viewProduct.location],
                  ['Added', viewProduct.createdAt ? new Date(viewProduct.createdAt).toLocaleDateString() : 'N/A'],
                ].map(([label, value]) => (
                  <div key={label} className={styles.detailRow}>
                    <span className={styles.detailLabel}>{label}</span>
                    <span className={styles.detailValue}>{value || 'N/A'}</span>
                  </div>
                ))}
              </div>

              {/* Description */}
              {viewProduct.description && (
                <>
                  <div className={styles.sectionTitle}>Description</div>
                  <div className={styles.descBox}>{viewProduct.description}</div>
                </>
              )}
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
