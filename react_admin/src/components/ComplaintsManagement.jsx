import { useEffect, useState } from 'react';
import {
  collection, onSnapshot, doc, updateDoc, deleteDoc, getDoc,
} from 'firebase/firestore';
import { db } from '../firebase';
import { Eye, Trash2, MessageSquare, CheckCircle, Clock, AlertCircle } from 'lucide-react';
import styles from './ComplaintsManagement.module.css';

// ── Status config ─────────────────────────────────────────────────────────────
const STATUS_CONFIG = {
  open:       { bg: '#fef3c7', text: '#b45309', label: 'Open'      },
  responded:  { bg: '#dbeafe', text: '#1d4ed8', label: 'Responded' },
  resolved:   { bg: '#d1fae5', text: '#065f46', label: 'Resolved'  },
};

const CATEGORY_ICONS = {
  'Wrong item':        '📦',
  'Damaged / spoiled': '🐟',
  'Late delivery':     '⏰',
  'Payment issue':     '💳',
  'Missing item':      '❓',
  'Poor quality':      '⭐',
  'Other':             '📝',
};

function formatDate(ts) {
  if (!ts) return 'N/A';
  const ms = ts.seconds ? ts.seconds * 1000 : ts;
  const d  = new Date(ms);
  return isNaN(d) ? 'N/A' : d.toLocaleString();
}

function formatDateShort(ts) {
  if (!ts) return 'N/A';
  const ms = ts.seconds ? ts.seconds * 1000 : ts;
  const d  = new Date(ms);
  return isNaN(d) ? 'N/A' : d.toLocaleDateString();
}

// ── Main component ─────────────────────────────────────────────────────────────
export default function ComplaintsManagement() {
  const [complaints, setComplaints] = useState([]);
  const [users, setUsers]           = useState({});
  const [search, setSearch]         = useState('');
  const [statusFilter, setStatus]   = useState('all');
  const [categoryFilter, setCat]    = useState('all');
  const [sortBy, setSort]           = useState('newest');
  const [viewItem, setViewItem]     = useState(null);
  const [respondItem, setRespondItem] = useState(null);
  const [responseText, setResponseText] = useState('');
  const [page, setPage]             = useState(1);
  const [saving, setSaving]         = useState(false);
  const PAGE_SIZE = 10;

  // ── Firestore subscriptions ──────────────────────────────────────────────
  useEffect(() => {
    const unsubComplaints = onSnapshot(collection(db, 'complaints'), snap =>
      setComplaints(snap.docs.map(d => ({ id: d.id, ...d.data() }))),
    );
    const unsubUsers = onSnapshot(collection(db, 'users'), snap => {
      const map = {};
      snap.docs.forEach(d => { map[d.id] = d.data(); });
      setUsers(map);
    });
    return () => { unsubComplaints(); unsubUsers(); };
  }, []);

  // ── Actions ──────────────────────────────────────────────────────────────
  const updateStatus = async (id, status) => {
    await updateDoc(doc(db, 'complaints', id), { status });
  };

  const handleDelete = async (id) => {
    if (!window.confirm('Delete this complaint? This cannot be undone.')) return;
    await deleteDoc(doc(db, 'complaints', id));
  };

  const handleRespond = async () => {
    if (!responseText.trim()) return;
    setSaving(true);
    try {
      await updateDoc(doc(db, 'complaints', respondItem.id), {
        response:    responseText.trim(),
        status:      'responded',
        respondedAt: new Date(),
      });

      // Write in-app notification to customer
      const customerId = respondItem.customerId;
      if (customerId) {
        const sellerSnap = respondItem.sellerId
          ? await getDoc(doc(db, 'users', respondItem.sellerId))
          : null;
        const sellerName = sellerSnap?.data()?.fullName
          || sellerSnap?.data()?.username
          || 'Admin';

        const { addDoc } = await import('firebase/firestore');
        await addDoc(collection(db, 'notifications'), {
          userId:      customerId,
          type:        'complaint_response',
          title:       'Complaint Response 💬',
          body:        `${sellerName} has responded to your complaint.`,
          complaintId: respondItem.id,
          read:        false,
          createdAt:   new Date(),
        });
      }

      setRespondItem(null);
      setResponseText('');
    } finally {
      setSaving(false);
    }
  };

  const handleMarkResolved = async (id) => {
    await updateDoc(doc(db, 'complaints', id), {
      status:     'resolved',
      resolvedAt: new Date(),
    });
  };

  // ── Filter + sort ────────────────────────────────────────────────────────
  const allCategories = [...new Set(complaints.map(c => c.category).filter(Boolean))];

  const filtered = complaints
    .filter(c => {
      const customer = users[c.customerId];
      const seller   = users[c.sellerId];
      const q        = search.toLowerCase();
      const matchSearch = !q ||
        c.id.toLowerCase().includes(q) ||
        (customer?.fullName || '').toLowerCase().includes(q) ||
        (customer?.username || '').toLowerCase().includes(q) ||
        (seller?.fullName   || '').toLowerCase().includes(q) ||
        (c.category         || '').toLowerCase().includes(q) ||
        (c.description      || '').toLowerCase().includes(q);
      const matchStatus = statusFilter === 'all' || c.status === statusFilter;
      const matchCat    = categoryFilter === 'all' || c.category === categoryFilter;
      return matchSearch && matchStatus && matchCat;
    })
    .sort((a, b) => {
      const getT = o => o.createdAt?.seconds ? o.createdAt.seconds * 1000 : (o.createdAt || 0);
      if (sortBy === 'oldest') return getT(a) - getT(b);
      return getT(b) - getT(a);
    });

  const totalPages = Math.ceil(filtered.length / PAGE_SIZE);
  const paginated  = filtered.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);

  // ── Stats ────────────────────────────────────────────────────────────────
  const stats = [
    { label: 'Total',     value: complaints.length,                                        color: '#4f46e5', bg: '#e0e7ff', Icon: AlertCircle },
    { label: 'Open',      value: complaints.filter(c => c.status === 'open').length,       color: '#b45309', bg: '#fef3c7', Icon: Clock       },
    { label: 'Responded', value: complaints.filter(c => c.status === 'responded').length,  color: '#1d4ed8', bg: '#dbeafe', Icon: MessageSquare},
    { label: 'Resolved',  value: complaints.filter(c => c.status === 'resolved').length,   color: '#065f46', bg: '#d1fae5', Icon: CheckCircle  },
  ];

  // ── Render ───────────────────────────────────────────────────────────────
  return (
    <div>
      {/* Header */}
      <div className={styles.header}>
        <div className={styles.headerLeft}>
          <h2 className={styles.title}>Complaints Management</h2>
          <span className={styles.count}>{filtered.length} complaints</span>
        </div>
      </div>

      {/* Stats */}
      <div className={styles.statsRow}>
        {stats.map(s => (
          <div key={s.label} className={styles.statCard} style={{ borderTop: `3px solid ${s.color}` }}>
            <div className={styles.statTop}>
              <div className={styles.statValue} style={{ color: s.color }}>{s.value}</div>
              <div className={styles.statIcon} style={{ background: s.bg, color: s.color }}>
                <s.Icon size={16} />
              </div>
            </div>
            <div className={styles.statLabel}>{s.label}</div>
          </div>
        ))}
      </div>

      {/* Toolbar */}
      <div className={styles.toolbar}>
        <input
          className={styles.search}
          placeholder="Search by ID, customer, seller, category, description..."
          value={search}
          onChange={e => { setSearch(e.target.value); setPage(1); }}
        />
        <select className={styles.filter} value={statusFilter}
          onChange={e => { setStatus(e.target.value); setPage(1); }}>
          <option value="all">All Status</option>
          <option value="open">Open</option>
          <option value="responded">Responded</option>
          <option value="resolved">Resolved</option>
        </select>
        <select className={styles.filter} value={categoryFilter}
          onChange={e => { setCat(e.target.value); setPage(1); }}>
          <option value="all">All Categories</option>
          {allCategories.map(c => (
            <option key={c} value={c}>{c}</option>
          ))}
        </select>
        <select className={styles.filter} value={sortBy}
          onChange={e => { setSort(e.target.value); setPage(1); }}>
          <option value="newest">Newest First</option>
          <option value="oldest">Oldest First</option>
        </select>
      </div>

      {/* Table */}
      <div className={styles.tableWrap}>
        <table className={styles.table}>
          <thead>
            <tr>
              <th>ID</th>
              <th>Customer</th>
              <th>Seller</th>
              <th>Category</th>
              <th>Description</th>
              <th>Date</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {paginated.length === 0 ? (
              <tr>
                <td colSpan={8} className={styles.empty}>
                  <div className={styles.emptyState}>
                    <MessageSquare size={40} style={{ opacity: 0.3 }} />
                    <p>No complaints found</p>
                  </div>
                </td>
              </tr>
            ) : paginated.map(c => {
              const customer = users[c.customerId];
              const seller   = users[c.sellerId];
              const sc       = STATUS_CONFIG[c.status] || STATUS_CONFIG.open;
              const icon     = CATEGORY_ICONS[c.category] || '📝';

              return (
                <tr key={c.id}>
                  {/* ID */}
                  <td className={styles.idCell}>
                    #{c.id.substring(0, 6).toUpperCase()}
                  </td>

                  {/* Customer */}
                  <td>
                    <div className={styles.userCell}>
                      <div className={styles.avatar} style={{ background: '#e0e7ff', color: '#4f46e5' }}>
                        {(customer?.username || '?').charAt(0).toUpperCase()}
                      </div>
                      <div>
                        <div className={styles.userName}>
                          {customer?.fullName || customer?.username || 'Unknown'}
                        </div>
                        <div className={styles.userSub}>{customer?.phone || 'N/A'}</div>
                      </div>
                    </div>
                  </td>

                  {/* Seller */}
                  <td>
                    <div className={styles.userCell}>
                      <div className={styles.avatar} style={{ background: '#d1fae5', color: '#065f46' }}>
                        {(seller?.username || '?').charAt(0).toUpperCase()}
                      </div>
                      <div>
                        <div className={styles.userName}>
                          {seller?.fullName || seller?.username || 'Unknown'}
                        </div>
                        <div className={styles.userSub}>{seller?.phone || 'N/A'}</div>
                      </div>
                    </div>
                  </td>

                  {/* Category */}
                  <td>
                    <span className={styles.categoryChip}>
                      {icon} {c.category || 'Other'}
                    </span>
                  </td>

                  {/* Description */}
                  <td className={styles.descCell}>
                    {(c.description || '').length > 60
                      ? c.description.substring(0, 60) + '…'
                      : c.description || '—'}
                  </td>

                  {/* Date */}
                  <td className={styles.dateCell}>{formatDateShort(c.createdAt)}</td>

                  {/* Status */}
                  <td>
                    <select
                      className={styles.statusSelect}
                      style={{ background: sc.bg, color: sc.text }}
                      value={c.status || 'open'}
                      onChange={e => updateStatus(c.id, e.target.value)}
                    >
                      <option value="open">Open</option>
                      <option value="responded">Responded</option>
                      <option value="resolved">Resolved</option>
                    </select>
                  </td>

                  {/* Actions */}
                  <td>
                    <div className={styles.actions}>
                      <button
                        className={styles.viewBtn}
                        title="View details"
                        onClick={() => setViewItem({ ...c, customer, seller })}
                      >
                        <Eye size={15} />
                      </button>
                      <button
                        className={styles.respondBtn}
                        title="Respond"
                        onClick={() => { setRespondItem(c); setResponseText(c.response || ''); }}
                      >
                        <MessageSquare size={15} />
                      </button>
                      {c.status === 'responded' && (
                        <button
                          className={styles.resolveBtn}
                          title="Mark resolved"
                          onClick={() => handleMarkResolved(c.id)}
                        >
                          <CheckCircle size={15} />
                        </button>
                      )}
                      <button
                        className={styles.deleteBtn}
                        title="Delete"
                        onClick={() => handleDelete(c.id)}
                      >
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

      {/* Pagination */}
      {totalPages > 0 && (
        <div className={styles.pagination}>
          <button className={styles.pageBtn}
            onClick={() => setPage(p => Math.max(1, p - 1))}
            disabled={page === 1}>
            ← Previous
          </button>
          <span className={styles.pageInfo}>
            Page {page} of {totalPages || 1} ({filtered.length} complaints)
          </span>
          <button className={styles.pageBtn}
            onClick={() => setPage(p => Math.min(totalPages, p + 1))}
            disabled={page === totalPages || totalPages === 0}>
            Next →
          </button>
        </div>
      )}

      {/* ── View Modal ─────────────────────────────────────────────────────── */}
      {viewItem && (
        <div className={styles.overlay} onClick={() => setViewItem(null)}>
          <div className={styles.modal} onClick={e => e.stopPropagation()}>
            <div className={styles.modalHeader}>
              <div>
                <h3>Complaint #{viewItem.id.substring(0, 6).toUpperCase()}</h3>
                <p style={{ color: 'rgba(255,255,255,0.7)', fontSize: 13, marginTop: 2 }}>
                  {CATEGORY_ICONS[viewItem.category] || '📝'} {viewItem.category || 'Other'}
                </p>
              </div>
              <button className={styles.closeBtn} onClick={() => setViewItem(null)}>✕</button>
            </div>

            <div className={styles.modalBody}>
              {/* Status badge */}
              <div className={styles.statusRow}>
                {(() => {
                  const sc = STATUS_CONFIG[viewItem.status] || STATUS_CONFIG.open;
                  return (
                    <span className={styles.statusBadge}
                      style={{ background: sc.bg, color: sc.text }}>
                      {sc.label}
                    </span>
                  );
                })()}
                <span className={styles.dateLabel}>
                  Filed {formatDate(viewItem.createdAt)}
                </span>
              </div>

              {/* Parties */}
              <div className={styles.partiesGrid}>
                <div className={styles.partyCard}>
                  <div className={styles.partyLabel}>Customer</div>
                  <div className={styles.partyName}>
                    {viewItem.customer?.fullName || viewItem.customer?.username || 'Unknown'}
                  </div>
                  <div className={styles.partySub}>{viewItem.customer?.phone || 'N/A'}</div>
                </div>
                <div className={styles.partyCard}>
                  <div className={styles.partyLabel}>Seller</div>
                  <div className={styles.partyName}>
                    {viewItem.seller?.fullName || viewItem.seller?.username || 'Unknown'}
                  </div>
                  <div className={styles.partySub}>{viewItem.seller?.phone || 'N/A'}</div>
                </div>
              </div>

              {/* Order reference */}
              {viewItem.orderId && (
                <>
                  <div className={styles.sectionTitle}>Order Reference</div>
                  <div className={styles.infoCard}>
                    <div className={styles.infoRow}>
                      <span className={styles.infoLabel}>Order ID</span>
                      <span className={styles.infoValue} style={{ fontFamily: 'monospace', color: '#4f46e5' }}>
                        #{viewItem.orderId.substring(0, 6).toUpperCase()}
                      </span>
                    </div>
                  </div>
                </>
              )}

              {/* Description */}
              <div className={styles.sectionTitle}>Customer's Complaint</div>
              <div className={styles.descBox}>{viewItem.description || '—'}</div>

              {/* Photo evidence */}
              {viewItem.photoUrl && (
                <>
                  <div className={styles.sectionTitle}>Photo Evidence</div>
                  <img
                    src={viewItem.photoUrl}
                    alt="Evidence"
                    className={styles.evidenceImg}
                  />
                </>
              )}

              {/* Seller response */}
              {viewItem.response && (
                <>
                  <div className={styles.sectionTitle}>Seller's Response</div>
                  <div className={styles.responseBox}>
                    <MessageSquare size={14} style={{ flexShrink: 0, marginTop: 2 }} />
                    <span>{viewItem.response}</span>
                  </div>
                  {viewItem.respondedAt && (
                    <p className={styles.respondedAt}>
                      Responded on {formatDate(viewItem.respondedAt)}
                    </p>
                  )}
                </>
              )}
            </div>

            <div className={styles.modalFooter}>
              <button className={styles.cancelBtn} onClick={() => setViewItem(null)}>
                Close
              </button>
              <button className={styles.respondBtnLarge}
                onClick={() => {
                  setRespondItem(viewItem);
                  setResponseText(viewItem.response || '');
                  setViewItem(null);
                }}>
                <MessageSquare size={15} /> Respond
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ── Respond Modal ──────────────────────────────────────────────────── */}
      {respondItem && (
        <div className={styles.overlay} onClick={() => setRespondItem(null)}>
          <div className={styles.modal} onClick={e => e.stopPropagation()}>
            <div className={styles.modalHeader} style={{ background: 'linear-gradient(135deg, #1d4ed8, #4f46e5)' }}>
              <div>
                <h3>Respond to Complaint</h3>
                <p style={{ color: 'rgba(255,255,255,0.7)', fontSize: 13, marginTop: 2 }}>
                  #{respondItem.id.substring(0, 6).toUpperCase()} — {respondItem.category}
                </p>
              </div>
              <button className={styles.closeBtn} onClick={() => setRespondItem(null)}>✕</button>
            </div>

            <div className={styles.modalBody}>
              {/* Original complaint */}
              <div className={styles.sectionTitle}>Original Complaint</div>
              <div className={styles.descBox} style={{ marginBottom: 20 }}>
                {respondItem.description || '—'}
              </div>

              {/* Response textarea */}
              <div className={styles.sectionTitle}>Admin / Seller Response</div>
              <textarea
                className={styles.responseTextarea}
                placeholder="Type the response to the customer here..."
                rows={5}
                value={responseText}
                onChange={e => setResponseText(e.target.value)}
              />
              <p style={{ fontSize: 12, color: '#9ca3af', marginTop: 6 }}>
                This response will be visible to the customer in their app and they will receive a push notification.
              </p>

              {/* Quick templates */}
              <div className={styles.sectionTitle} style={{ marginTop: 16 }}>Quick Templates</div>
              <div className={styles.templates}>
                {[
                  'We apologise for the inconvenience. We have investigated the issue and will take corrective action immediately.',
                  'Thank you for your report. We have verified the issue and a replacement/refund has been processed.',
                  'We are sorry to hear about this. Our team is looking into it and will resolve it within 24 hours.',
                  'We have contacted the seller and this issue has been escalated for immediate resolution.',
                ].map((t, i) => (
                  <button key={i} className={styles.templateBtn}
                    onClick={() => setResponseText(t)}>
                    {t.substring(0, 55)}…
                  </button>
                ))}
              </div>
            </div>

            <div className={styles.modalFooter}>
              <button className={styles.cancelBtn} onClick={() => setRespondItem(null)}>
                Cancel
              </button>
              <button
                className={styles.submitBtn}
                onClick={handleRespond}
                disabled={saving || !responseText.trim()}
              >
                {saving ? 'Sending…' : '📨 Send Response'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
