import { useEffect, useState } from 'react';
import { collection, onSnapshot, doc, updateDoc, deleteDoc } from 'firebase/firestore';
import { db } from '../firebase';
import { Eye, Pencil, Trash2 } from 'lucide-react';
import styles from './OrdersTable.module.css';

const STATUS_COLORS = {
  pending:   { bg: '#fef3c7', text: '#b45309' },
  confirmed: { bg: '#dbeafe', text: '#1d4ed8' },
  delivered: { bg: '#d1fae5', text: '#065f46' },
  cancelled: { bg: '#fee2e2', text: '#dc2626' },
};

export default function OrdersTable() {
  const [orders, setOrders]       = useState([]);
  const [users, setUsers]         = useState({});
  const [search, setSearch]       = useState('');
  const [statusFilter, setStatus] = useState('all');
  const [sortBy, setSort]         = useState('newest');
  const [viewOrder, setViewOrder] = useState(null);
  const [editOrder, setEditOrder] = useState(null);
  const [page, setPage]           = useState(1);
  const PAGE_SIZE = 10;

  useEffect(() => {
    const unsub1 = onSnapshot(collection(db, 'orders'), snap =>
      setOrders(snap.docs.map(d => ({ id: d.id, ...d.data() }))));
    const unsub2 = onSnapshot(collection(db, 'users'), snap => {
      const map = {};
      snap.docs.forEach(d => { map[d.id] = d.data(); });
      setUsers(map);
    });
    return () => { unsub1(); unsub2(); };
  }, []);

  const updateStatus = async (id, status) => {
    await updateDoc(doc(db, 'orders', id), { status });
  };

  const handleDelete = async (id) => {
    if (window.confirm('Are you sure you want to delete this order?')) {
      await deleteDoc(doc(db, 'orders', id));
    }
  };

  const handleEditSave = async (e) => {
    e.preventDefault();
    await updateDoc(doc(db, 'orders', editOrder.id), {
      status: editOrder.status,
      'delivery.status': editOrder.deliveryStatus || editOrder.delivery?.status,
      total: parseFloat(editOrder.total) || editOrder.total,
    });
    setEditOrder(null);
  };

  const formatDate = (createdAt) => {
    if (!createdAt) return 'N/A';
    const ms = createdAt.seconds ? createdAt.seconds * 1000 : createdAt;
    const date = new Date(ms);
    return isNaN(date) ? 'N/A' : date.toLocaleDateString();
  };

  const formatDateTime = (createdAt) => {
    if (!createdAt) return 'N/A';
    const ms = createdAt.seconds ? createdAt.seconds * 1000 : createdAt;
    const date = new Date(ms);
    return isNaN(date) ? 'N/A' : date.toLocaleString();
  };

  const filtered = orders
    .filter(o => {
      const customer = users[o.customerId];
      const q = search.toLowerCase();
      const matchSearch = !q ||
        o.id.toLowerCase().includes(q) ||
        (customer?.fullName || '').toLowerCase().includes(q) ||
        (customer?.username || '').toLowerCase().includes(q) ||
        (customer?.phone || '').toLowerCase().includes(q);
      const matchStatus = statusFilter === 'all' || o.status === statusFilter;
      return matchSearch && matchStatus;
    })
    .sort((a, b) => {
      const getTime = (o) => o.createdAt?.seconds ? o.createdAt.seconds * 1000 : (o.createdAt || 0);
      if (sortBy === 'oldest') return getTime(a) - getTime(b);
      if (sortBy === 'total_high') return (b.total || 0) - (a.total || 0);
      if (sortBy === 'total_low') return (a.total || 0) - (b.total || 0);
      return getTime(b) - getTime(a);
    });

  const totalPages = Math.ceil(filtered.length / PAGE_SIZE);
  const paginated  = filtered.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);

  return (
    <div>
      <div className={styles.header}>
        <h2 className={styles.title}>Order Management</h2>
        <span className={styles.count}>{filtered.length} orders</span>
      </div>

      {/* Stats */}
      <div className={styles.statsRow}>
        {[
          { label: 'Total Orders', value: orders.length,                                          color: '#4f46e5', bg: '#e0e7ff' },
          { label: 'Pending',      value: orders.filter(o => o.status === 'pending').length,      color: '#b45309', bg: '#fef3c7' },
          { label: 'Confirmed',    value: orders.filter(o => o.status === 'confirmed').length,    color: '#1d4ed8', bg: '#dbeafe' },
          { label: 'Delivered',    value: orders.filter(o => o.status === 'delivered').length,    color: '#065f46', bg: '#d1fae5' },
          { label: 'Cancelled',    value: orders.filter(o => o.status === 'cancelled').length,    color: '#dc2626', bg: '#fee2e2' },
          { label: 'Revenue',
            value: 'TShs ' + orders
              .filter(o => o.status === 'delivered')
              .reduce((sum, o) => sum + (o.total || 0), 0)
              .toLocaleString(),
            color: '#065f46', bg: '#d1fae5', small: true },
        ].map(s => (
          <div key={s.label} className={styles.statCard} style={{ borderTop: `3px solid ${s.color}` }}>
            <div className={styles.statValue} style={{ color: s.color, fontSize: s.small ? '16px' : undefined }}>{s.value}</div>
            <div className={styles.statLabel}>{s.label}</div>
          </div>
        ))}
      </div>

      <div className={styles.toolbar}>
        <input className={styles.search} placeholder="Search by order ID, customer name, phone..."
          value={search} onChange={e => { setSearch(e.target.value); setPage(1); }} />
        <select className={styles.filter} value={statusFilter} onChange={e => { setStatus(e.target.value); setPage(1); }}>
          <option value="all">All Status</option>
          <option value="pending">Pending</option>
          <option value="confirmed">Confirmed</option>
          <option value="delivered">Delivered</option>
          <option value="cancelled">Cancelled</option>
        </select>
        <select className={styles.filter} value={sortBy} onChange={e => { setSort(e.target.value); setPage(1); }}>
          <option value="newest">Newest</option>
          <option value="oldest">Oldest</option>
          <option value="total_high">Total ↑</option>
          <option value="total_low">Total ↓</option>
        </select>
      </div>

      <div className={styles.tableWrap}>
        <table className={styles.table}>
          <thead>
            <tr>
              <th>Order ID</th><th>Customer</th><th>Items</th>
              <th>Total</th><th>Date</th><th>Status</th><th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {paginated.length === 0 ? (
              <tr><td colSpan={7} className={styles.empty}>No orders found</td></tr>
            ) : paginated.map(o => {
              const customer = users[o.customerId];
              const items = o.items || [];
              const sc = STATUS_COLORS[o.status] || STATUS_COLORS.pending;
              return (
                <tr key={o.id}>
                  <td className={styles.orderId}>#{o.id.substring(0, 6).toUpperCase()}</td>
                  <td>
                    <div className={styles.customerCell}>
                      <div className={styles.avatar}>{(customer?.username || '?').charAt(0).toUpperCase()}</div>
                      <div>
                        <div className={styles.customerName}>{customer?.fullName || customer?.username || 'Unknown'}</div>
                        <div className={styles.customerPhone}>{customer?.phone || 'N/A'}</div>
                      </div>
                    </div>
                  </td>
                  <td>
                    <div className={styles.itemsPreview}>
                      {items.slice(0, 2).map((item, i) => (
                        <span key={i} className={styles.itemChip}>{item.name} x{item.quantity}</span>
                      ))}
                      {items.length > 2 && <span className={styles.moreItems}>+{items.length - 2} more</span>}
                    </div>
                  </td>
                  <td className={styles.total}>TShs {o.total?.toLocaleString()}</td>
                  <td className={styles.date}>{formatDate(o.createdAt)}</td>
                  <td>
                    <select className={styles.statusSelect} style={{ background: sc.bg, color: sc.text }}
                      value={o.status || 'pending'} onChange={e => updateStatus(o.id, e.target.value)}>
                      <option value="pending">Pending</option>
                      <option value="confirmed">Confirmed</option>
                      <option value="delivered">Delivered</option>
                      <option value="cancelled">Cancelled</option>
                    </select>
                  </td>
                  <td>
                    <div className={styles.actions}>
                      <button className={styles.viewBtn} onClick={() => setViewOrder({...o, customer})} title="View">
                        <Eye size={16} />
                      </button>
                      <button className={styles.editBtn} onClick={() => setEditOrder({...o})} title="Edit">
                        <Pencil size={16} />
                      </button>
                      <button className={styles.deleteBtn} onClick={() => handleDelete(o.id)} title="Delete">
                        <Trash2 size={14} />
                      </button>
                    </div>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      {totalPages > 0 && (
        <div className={styles.pagination}>
          <button className={styles.pageBtn} onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page === 1}>← Previous</button>
          <span className={styles.pageInfo}>Page {page} of {totalPages || 1} ({filtered.length} orders)</span>
          <button className={styles.pageBtn} onClick={() => setPage(p => Math.min(totalPages, p + 1))} disabled={page === totalPages || totalPages === 0}>Next →</button>
        </div>
      )}

      {/* View Modal */}
      {viewOrder && (
        <div className={styles.overlay} onClick={() => setViewOrder(null)}>
          <div className={styles.modal} onClick={e => e.stopPropagation()}>
            <div className={styles.modalHeader}>
              <h3>Order #{viewOrder.id.substring(0, 6).toUpperCase()}</h3>
              <button className={styles.closeBtn} onClick={() => setViewOrder(null)}>✕</button>
            </div>
            <div className={styles.modalBody}>
              <div className={styles.sectionTitle}>Customer</div>
              <div className={styles.infoCard}>
                {[['Name', viewOrder.customer?.fullName || viewOrder.customer?.username],
                  ['Phone', viewOrder.customer?.phone],
                  ['Location', viewOrder.customer?.location?.name]].map(([l, v]) => (
                  <div key={l} className={styles.infoRow}>
                    <span className={styles.infoLabel}>{l}</span>
                    <span className={styles.infoValue}>{v || 'N/A'}</span>
                  </div>
                ))}
              </div>
              <div className={styles.sectionTitle}>Items</div>
              <div className={styles.itemsList}>
                {(viewOrder.items || []).map((item, i) => (
                  <div key={i} className={styles.orderItem}>
                    {item.imageUrl ? <img src={item.imageUrl} alt={item.name} className={styles.itemImg} />
                      : <div className={styles.itemImgPlaceholder}>📦</div>}
                    <div className={styles.itemInfo}>
                      <div className={styles.itemName}>{item.name}</div>
                      <div className={styles.itemPrice}>TShs {item.price?.toLocaleString()} / {item.unit}</div>
                    </div>
                    <div className={styles.itemQty}>x{item.quantity}</div>
                    <div className={styles.itemSubtotal}>TShs {((item.price || 0) * (item.quantity || 1)).toLocaleString()}</div>
                  </div>
                ))}
              </div>
              <div className={styles.orderSummary}>
                <div className={styles.summaryRow}><span>Total</span><strong>TShs {viewOrder.total?.toLocaleString()}</strong></div>
                <div className={styles.summaryRow}><span>Date</span><span>{formatDateTime(viewOrder.createdAt)}</span></div>
                <div className={styles.summaryRow}>
                  <span>Status</span>
                  <span className={styles.statusBadge} style={{
                    background: (STATUS_COLORS[viewOrder.status] || STATUS_COLORS.pending).bg,
                    color: (STATUS_COLORS[viewOrder.status] || STATUS_COLORS.pending).text,
                  }}>{viewOrder.status?.toUpperCase()}</span>
                </div>
              </div>
            </div>
            <div className={styles.modalFooter}>
              <button className={styles.cancelBtn} onClick={() => setViewOrder(null)}>Close</button>
            </div>
          </div>
        </div>
      )}

      {/* Edit Modal */}
      {editOrder && (
        <div className={styles.overlay} onClick={() => setEditOrder(null)}>
          <div className={styles.modal} onClick={e => e.stopPropagation()}>
            <div className={styles.modalHeader}>
              <h3>Edit Order #{editOrder.id?.substring(0, 6).toUpperCase()}</h3>
              <button className={styles.closeBtn} onClick={() => setEditOrder(null)}>✕</button>
            </div>
            <form onSubmit={handleEditSave}>
              <div style={{padding: '20px 24px'}}>
                <div className={styles.editField}>
                  <label>Order Status</label>
                  <select value={editOrder.status || 'pending'}
                    onChange={e => setEditOrder({...editOrder, status: e.target.value})}>
                    <option value="pending">Pending</option>
                    <option value="confirmed">Confirmed</option>
                    <option value="delivered">Delivered</option>
                    <option value="cancelled">Cancelled</option>
                  </select>
                </div>
                <div className={styles.editField}>
                  <label>Delivery Status</label>
                  <select value={editOrder.delivery?.status || 'searching'}
                    onChange={e => setEditOrder({...editOrder, deliveryStatus: e.target.value})}>
                    <option value="searching">Searching Driver</option>
                    <option value="assigned">Driver Assigned</option>
                    <option value="on_the_way">On the Way</option>
                    <option value="delivered">Delivered</option>
                  </select>
                </div>
                <div className={styles.editField}>
                  <label>Total (TShs)</label>
                  <input type="number" value={editOrder.total || 0}
                    onChange={e => setEditOrder({...editOrder, total: e.target.value})} />
                </div>
              </div>
              <div className={styles.modalFooter}>
                <button type="button" className={styles.cancelBtn} onClick={() => setEditOrder(null)}>Cancel</button>
                <button type="submit" className={styles.submitBtn}>Save Changes</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
