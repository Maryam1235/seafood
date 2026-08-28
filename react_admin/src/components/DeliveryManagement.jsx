import { useEffect, useState } from 'react';
import {
  collection, onSnapshot, doc, updateDoc, getDoc, addDoc
} from 'firebase/firestore';
import { db } from '../firebase';
import {
  Truck, Eye, UserCheck, Clock, CheckCircle2,
  XCircle, MapPin, Phone, User, Package
} from 'lucide-react';
import styles from './DeliveryManagement.module.css';

const STATUS_META = {
  pending:   { label: 'Pending',    bg: '#fef3c7', text: '#b45309', icon: Clock },
  confirmed: { label: 'Confirmed',  bg: '#dbeafe', text: '#1d4ed8', icon: UserCheck },
  on_the_way:{ label: 'On the Way', bg: '#ede9fe', text: '#7c3aed', icon: Truck },
  delivered: { label: 'Delivered',  bg: '#d1fae5', text: '#065f46', icon: CheckCircle2 },
  cancelled: { label: 'Cancelled',  bg: '#fee2e2', text: '#dc2626', icon: XCircle },
};

const DELIVERY_STATUS_META = {
  searching:  { label: 'Searching Driver', bg: '#fef9c3', text: '#854d0e' },
  assigned:   { label: 'Driver Assigned',  bg: '#dbeafe', text: '#1d4ed8' },
  on_the_way: { label: 'On the Way',       bg: '#ede9fe', text: '#7c3aed' },
  delivered:  { label: 'Delivered',        bg: '#d1fae5', text: '#065f46' },
};

function Badge({ status, map }) {
  const meta = map[status] || { label: status, bg: '#f3f4f6', text: '#374151' };
  return (
    <span className={styles.badge} style={{ background: meta.bg, color: meta.text }}>
      {meta.label}
    </span>
  );
}

export default function DeliveryManagement() {
  const [orders, setOrders]     = useState([]);
  const [users, setUsers]       = useState({});
  const [drivers, setDrivers]   = useState([]);
  const [search, setSearch]     = useState('');
  const [statusFilter, setStatus] = useState('all');
  const [sortBy, setSort]       = useState('newest');
  const [viewOrder, setViewOrder] = useState(null);
  const [assignModal, setAssignModal] = useState(null); // order to assign driver
  const [page, setPage]         = useState(1);
  const PAGE_SIZE = 10;

  // Live data
  useEffect(() => {
    const u1 = onSnapshot(collection(db, 'orders'), snap =>
      setOrders(snap.docs.map(d => ({ id: d.id, ...d.data() }))));
    const u2 = onSnapshot(collection(db, 'users'), snap => {
      const map = {};
      const driverList = [];
      snap.docs.forEach(d => {
        const data = d.data();
        map[d.id] = data;
        if (data.role === 'driver') driverList.push({ id: d.id, ...data });
      });
      setUsers(map);
      setDrivers(driverList);
    });
    return () => { u1(); u2(); };
  }, []);

  const formatDate = (ts) => {
    if (!ts) return 'N/A';
    const ms = ts.seconds ? ts.seconds * 1000 : ts;
    const d = new Date(ms);
    return isNaN(d) ? 'N/A' : d.toLocaleDateString();
  };

  const formatDateTime = (ts) => {
    if (!ts) return 'N/A';
    const ms = ts.seconds ? ts.seconds * 1000 : ts;
    const d = new Date(ms);
    return isNaN(d) ? 'N/A' : d.toLocaleString();
  };

  // Assign driver to order
  const assignDriver = async (orderId, driverId) => {
    const driver = users[driverId];
    await updateDoc(doc(db, 'orders', orderId), {
      'delivery.driverId': driverId,
      'delivery.driverName': driver?.fullName || driver?.username || 'Driver',
      'delivery.driverPhone': driver?.phone || '',
      'delivery.status': 'assigned',
      status: 'confirmed',
    });
    // Notify driver via Firestore notification
    const orderSnap = await getDoc(doc(db, 'orders', orderId));
    const order = orderSnap.data();
    const customer = users[order?.customerId];
    await addDoc(collection(db, 'notifications'), {
        userId: driverId,
        type: 'new_delivery',
        title: 'New Delivery Request 🚀',
        body: `You have a new delivery from ${customer?.fullName || customer?.username || 'a customer'}. Total: TShs ${order?.total?.toLocaleString() || '0'}`,
        orderId,
        read: false,
        createdAt: new Date(),
      });
    setAssignModal(null);
  };

  // Update delivery status
  const updateDeliveryStatus = async (orderId, deliveryStatus) => {
    const updates = { 'delivery.status': deliveryStatus };
    if (deliveryStatus === 'delivered') {
      updates.status = 'delivered';
      updates['delivery.deliveredAt'] = new Date();
    }
    await updateDoc(doc(db, 'orders', orderId), updates);
  };

  // Stats
  const stats = {
    total:     orders.length,
    pending:   orders.filter(o => o.status === 'pending').length,
    active:    orders.filter(o => ['confirmed', 'on_the_way'].includes(o.status)).length,
    delivered: orders.filter(o => o.status === 'delivered').length,
    cancelled: orders.filter(o => o.status === 'cancelled').length,
    onlineDrivers: drivers.filter(d => d.isOnline).length,
  };

  // Filter + sort
  const filtered = orders
    .filter(o => {
      const customer = users[o.customerId];
      const driver = users[o.delivery?.driverId];
      const q = search.toLowerCase();
      const matchSearch = !q ||
        o.id.toLowerCase().includes(q) ||
        (customer?.fullName || '').toLowerCase().includes(q) ||
        (customer?.username || '').toLowerCase().includes(q) ||
        (driver?.fullName || '').toLowerCase().includes(q) ||
        (driver?.username || '').toLowerCase().includes(q);
      const matchStatus = statusFilter === 'all' || o.status === statusFilter;
      return matchSearch && matchStatus;
    })
    .sort((a, b) => {
      const t = o => o.createdAt?.seconds ? o.createdAt.seconds * 1000 : (o.createdAt || 0);
      return sortBy === 'oldest' ? t(a) - t(b) : t(b) - t(a);
    });

  const totalPages = Math.ceil(filtered.length / PAGE_SIZE);
  const paginated  = filtered.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);

  return (
    <div>
      {/* Header */}
      <div className={styles.header}>
        <div>
          <h2 className={styles.title}>Delivery Management</h2>
          <p className={styles.subtitle}>Track and manage all deliveries in real time</p>
        </div>
        <span className={styles.count}>{filtered.length} deliveries</span>
      </div>

      {/* Stats row */}
      <div className={styles.statsRow}>
        {[
          { label: 'Total Orders',    value: stats.total,        color: '#4f46e5', bg: '#e0e7ff' },
          { label: 'Pending',         value: stats.pending,      color: '#b45309', bg: '#fef3c7' },
          { label: 'Active',          value: stats.active,       color: '#7c3aed', bg: '#ede9fe' },
          { label: 'Delivered',       value: stats.delivered,    color: '#065f46', bg: '#d1fae5' },
          { label: 'Cancelled',       value: stats.cancelled,    color: '#dc2626', bg: '#fee2e2' },
        ].map(s => (
          <div key={s.label} className={styles.statCard} style={{ borderTop: `3px solid ${s.color}` }}>
            <div className={styles.statValue} style={{ color: s.color }}>{s.value}</div>
            <div className={styles.statLabel}>{s.label}</div>
          </div>
        ))}
      </div>

      {/* Toolbar */}
      <div className={styles.toolbar}>
        <input
          className={styles.search}
          placeholder="Search by order ID, customer or driver name..."
          value={search}
          onChange={e => { setSearch(e.target.value); setPage(1); }}
        />
        <select className={styles.filter} value={statusFilter}
          onChange={e => { setStatus(e.target.value); setPage(1); }}>
          <option value="all">All Status</option>
          <option value="pending">Pending</option>
          <option value="confirmed">Confirmed</option>
          <option value="on_the_way">On the Way</option>
          <option value="delivered">Delivered</option>
          <option value="cancelled">Cancelled</option>
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
              <th>Order ID</th>
              <th>Customer</th>
              <th>Driver</th>
              <th>Items</th>
              <th>Total</th>
              <th>Date</th>
              <th>Order Status</th>
              <th>Delivery Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {paginated.length === 0 ? (
              <tr><td colSpan={9} className={styles.empty}>No deliveries found</td></tr>
            ) : paginated.map(o => {
              const customer = users[o.customerId];
              const driver   = users[o.delivery?.driverId];
              const items    = o.items || [];
              const deliveryStatus = o.delivery?.status || 'searching';

              return (
                <tr key={o.id}>
                  <td className={styles.orderId}>#{o.id.substring(0, 6).toUpperCase()}</td>

                  {/* Customer */}
                  <td>
                    <div className={styles.personCell}>
                      <div className={styles.avatar} style={{ background: '#e0e7ff', color: '#4f46e5' }}>
                        {(customer?.username || '?').charAt(0).toUpperCase()}
                      </div>
                      <div>
                        <div className={styles.personName}>{customer?.fullName || customer?.username || 'Unknown'}</div>
                        <div className={styles.personSub}>{customer?.phone || 'N/A'}</div>
                      </div>
                    </div>
                  </td>

                  {/* Driver */}
                  <td>
                    {driver ? (
                      <div className={styles.personCell}>
                        <div className={styles.avatar} style={{ background: '#d1fae5', color: '#065f46' }}>
                          {(driver?.username || '?').charAt(0).toUpperCase()}
                        </div>
                        <div>
                          <div className={styles.personName}>{driver?.fullName || driver?.username}</div>
                          <div className={styles.personSub}>{driver?.phone || 'N/A'}</div>
                        </div>
                      </div>
                    ) : (
                      <span className={styles.noDriver}>Not assigned</span>
                    )}
                  </td>

                  {/* Items */}
                  <td>
                    <div className={styles.itemsPreview}>
                      {items.slice(0, 2).map((item, i) => (
                        <span key={i} className={styles.itemChip}>{item.name} x{item.quantity}</span>
                      ))}
                      {items.length > 2 && <span className={styles.moreItems}>+{items.length - 2}</span>}
                    </div>
                  </td>

                  <td className={styles.total}>TShs {o.total?.toLocaleString()}</td>
                  <td className={styles.date}>{formatDate(o.createdAt)}</td>

                  {/* Order status */}
                  <td><Badge status={o.status || 'pending'} map={STATUS_META} /></td>

                  {/* Delivery status — editable */}
                  <td>
                    <select
                      className={styles.statusSelect}
                      style={{
                        background: (DELIVERY_STATUS_META[deliveryStatus] || DELIVERY_STATUS_META.searching).bg,
                        color: (DELIVERY_STATUS_META[deliveryStatus] || DELIVERY_STATUS_META.searching).text,
                      }}
                      value={deliveryStatus}
                      onChange={e => updateDeliveryStatus(o.id, e.target.value)}
                    >
                      <option value="searching">Searching Driver</option>
                      <option value="assigned">Driver Assigned</option>
                      <option value="on_the_way">On the Way</option>
                      <option value="delivered">Delivered</option>
                    </select>
                  </td>

                  {/* Actions */}
                  <td>
                    <div className={styles.actions}>
                      <button className={styles.viewBtn} title="View details"
                        onClick={() => setViewOrder({ ...o, customer, driver })}>
                        <Eye size={15} />
                      </button>
                      {!o.delivery?.driverId && o.status !== 'cancelled' && (
                        <button className={styles.assignBtn} title="Assign driver"
                          onClick={() => setAssignModal(o)}>
                          <UserCheck size={15} /> Assign
                        </button>
                      )}
                    </div>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      {/* Pagination */}
      {totalPages > 1 && (
        <div className={styles.pagination}>
          <button className={styles.pageBtn} disabled={page === 1}
            onClick={() => setPage(p => p - 1)}>← Previous</button>
          <span className={styles.pageInfo}>Page {page} of {totalPages} ({filtered.length} orders)</span>
          <button className={styles.pageBtn} disabled={page === totalPages}
            onClick={() => setPage(p => p + 1)}>Next →</button>
        </div>
      )}

      {/* ── View Modal ── */}
      {viewOrder && (
        <div className={styles.overlay} onClick={() => setViewOrder(null)}>
          <div className={styles.modal} onClick={e => e.stopPropagation()}>
            <div className={styles.modalHeader}>
              <h3>Delivery #{viewOrder.id.substring(0, 6).toUpperCase()}</h3>
              <button className={styles.closeBtn} onClick={() => setViewOrder(null)}>✕</button>
            </div>
            <div className={styles.modalBody}>

              {/* Status row */}
              <div className={styles.statusRow}>
                <div>
                  <div className={styles.sectionLabel}>Order Status</div>
                  <Badge status={viewOrder.status || 'pending'} map={STATUS_META} />
                </div>
                <div>
                  <div className={styles.sectionLabel}>Delivery Status</div>
                  <Badge status={viewOrder.delivery?.status || 'searching'} map={DELIVERY_STATUS_META} />
                </div>
                <div>
                  <div className={styles.sectionLabel}>Date</div>
                  <span className={styles.dateText}>{formatDateTime(viewOrder.createdAt)}</span>
                </div>
              </div>

              {/* Customer */}
              <div className={styles.sectionTitle}><User size={13} /> Customer</div>
              <div className={styles.infoCard}>
                {[
                  ['Name',     viewOrder.customer?.fullName || viewOrder.customer?.username],
                  ['Phone',    viewOrder.customer?.phone],
                  ['Location', viewOrder.customer?.location?.name],
                  ['Email',    viewOrder.customer?.email],
                ].map(([l, v]) => (
                  <div key={l} className={styles.infoRow}>
                    <span className={styles.infoLabel}>{l}</span>
                    <span className={styles.infoValue}>{v || 'N/A'}</span>
                  </div>
                ))}
              </div>

              {/* Driver */}
              <div className={styles.sectionTitle}><Truck size={13} /> Driver</div>
              {viewOrder.driver ? (
                <div className={styles.infoCard}>
                  {[
                    ['Name',    viewOrder.driver?.fullName || viewOrder.driver?.username],
                    ['Phone',   viewOrder.driver?.phone],
                    ['Status',  viewOrder.driver?.isOnline ? '🟢 Online' : '⚫ Offline'],
                  ].map(([l, v]) => (
                    <div key={l} className={styles.infoRow}>
                      <span className={styles.infoLabel}>{l}</span>
                      <span className={styles.infoValue}>{v || 'N/A'}</span>
                    </div>
                  ))}
                </div>
              ) : (
                <div className={styles.noDriverCard}>No driver assigned yet</div>
              )}

              {/* ── Delivery Route Map ── */}
              {viewOrder.driver && (() => {
                const driverLat  = viewOrder.driver?.location?.latitude;
                const driverLng  = viewOrder.driver?.location?.longitude;
                const custLat    = viewOrder.customer?.location?.latitude;
                const custLng    = viewOrder.customer?.location?.longitude;

                // Get seller coords from first item's sellerId
                const sellerId   = (viewOrder.items || [])[0]?.sellerId;
                const sellerUser = sellerId ? users[sellerId] : null;
                const sellerLat  = sellerUser?.location?.latitude;
                const sellerLng  = sellerUser?.location?.longitude;

                const hasDriver   = driverLat && driverLng;
                const hasCustomer = custLat && custLng;
                const hasSeller   = sellerLat && sellerLng;

                if (!hasDriver && !hasCustomer) return null;

                // ── Build Google Maps directions URL (opens in browser tab) ──
                // Route: Driver → Seller (pickup) → Customer (dropoff)
                let mapsUrl;
                if (hasDriver && hasSeller && hasCustomer) {
                  mapsUrl = `https://www.google.com/maps/dir/?api=1`
                    + `&origin=${driverLat},${driverLng}`
                    + `&waypoints=${sellerLat},${sellerLng}`
                    + `&destination=${custLat},${custLng}`
                    + `&travelmode=driving`;
                } else if (hasDriver && hasCustomer) {
                  mapsUrl = `https://www.google.com/maps/dir/?api=1`
                    + `&origin=${driverLat},${driverLng}`
                    + `&destination=${custLat},${custLng}`
                    + `&travelmode=driving`;
                } else {
                  mapsUrl = `https://www.google.com/maps/search/?api=1&query=${custLat},${custLng}`;
                }

                // ── Build OpenStreetMap embed URL ──────────────────────────
                // OpenStreetMap with markers — free, no API key, no billing.
                // We center the map on the midpoint of all known points and
                // add individual marker overlays.
                const points = [];
                if (hasDriver)   points.push([driverLat,  driverLng]);
                if (hasSeller)   points.push([sellerLat,  sellerLng]);
                if (hasCustomer) points.push([custLat,    custLng]);

                // Calculate bounding box center + zoom
                const lats = points.map(p => p[0]);
                const lngs = points.map(p => p[1]);
                const centerLat = (Math.min(...lats) + Math.max(...lats)) / 2;
                const centerLng = (Math.min(...lngs) + Math.max(...lngs)) / 2;

                // Build marker params for OSM embed
                // OSM embed supports: marker=lat,lng
                const markerParams = points
                  .map(p => `marker=${p[0]},${p[1]}`)
                  .join('&');

                const osmEmbedUrl = `https://www.openstreetmap.org/export/embed.html`
                  + `?bbox=${Math.min(...lngs) - 0.01},${Math.min(...lats) - 0.01},${Math.max(...lngs) + 0.01},${Math.max(...lats) + 0.01}`
                  + `&layer=mapnik`
                  + `&${markerParams}`;

                return (
                  <div>
                    <div className={styles.sectionTitle} style={{ marginTop: 16 }}>
                      <MapPin size={13} /> Delivery Route
                    </div>

                    {/* Map iframe — OpenStreetMap, free, no API key */}
                    <div className={styles.mapWrap}>
                      <iframe
                        title="Delivery Route Map"
                        src={osmEmbedUrl}
                        className={styles.mapIframe}
                        loading="lazy"
                        referrerPolicy="no-referrer-when-downgrade"
                        sandbox="allow-scripts allow-same-origin"
                      />

                      {/* Legend */}
                      <div className={styles.mapLegend}>
                        {hasDriver   && <span className={styles.legendItem}><span className={styles.dot} style={{background:'#3b82f6'}}/>Driver</span>}
                        {hasSeller   && <span className={styles.legendItem}><span className={styles.dot} style={{background:'#f97316'}}/>Seller (Pickup)</span>}
                        {hasCustomer && <span className={styles.legendItem}><span className={styles.dot} style={{background:'#ef4444'}}/>Customer (Delivery)</span>}
                      </div>

                      {/* Open full route in Google Maps (real driving directions) */}
                      <a
                        href={mapsUrl}
                        target="_blank"
                        rel="noreferrer"
                        className={styles.openMapBtn}
                      >
                        <MapPin size={14} /> Open Full Route in Google Maps
                      </a>
                    </div>

                    {/* Coordinates summary cards */}
                    <div className={styles.coordsGrid}>
                      {hasDriver && (
                        <div className={styles.coordCard} style={{ borderLeft: '3px solid #3b82f6' }}>
                          <div className={styles.coordLabel}>🚗 Driver (Current location)</div>
                          <div className={styles.coordName}>{viewOrder.driver?.fullName || viewOrder.driver?.username}</div>
                          <div className={styles.coordLoc}>{viewOrder.driver?.location?.name || `${driverLat?.toFixed(4)}, ${driverLng?.toFixed(4)}`}</div>
                        </div>
                      )}
                      {hasSeller && sellerUser && (
                        <div className={styles.coordCard} style={{ borderLeft: '3px solid #f97316' }}>
                          <div className={styles.coordLabel}>🏪 Seller (Pickup point)</div>
                          <div className={styles.coordName}>{sellerUser?.fullName || sellerUser?.username}</div>
                          <div className={styles.coordLoc}>{sellerUser?.location?.name || `${sellerLat?.toFixed(4)}, ${sellerLng?.toFixed(4)}`}</div>
                        </div>
                      )}
                      {hasCustomer && (
                        <div className={styles.coordCard} style={{ borderLeft: '3px solid #ef4444' }}>
                          <div className={styles.coordLabel}>📍 Customer (Delivery point)</div>
                          <div className={styles.coordName}>{viewOrder.customer?.fullName || viewOrder.customer?.username}</div>
                          <div className={styles.coordLoc}>{viewOrder.customer?.location?.name || `${custLat?.toFixed(4)}, ${custLng?.toFixed(4)}`}</div>
                        </div>
                      )}
                    </div>
                  </div>
                );
              })()}

              {/* Items */}
              <div className={styles.sectionTitle}><Package size={13} /> Items</div>
              <div className={styles.itemsList}>
                {(viewOrder.items || []).map((item, i) => (
                  <div key={i} className={styles.orderItem}>
                    {item.imageUrl
                      ? <img src={item.imageUrl} alt={item.name} className={styles.itemImg} />
                      : <div className={styles.itemImgPlaceholder}>🐟</div>}
                    <div className={styles.itemInfo}>
                      <div className={styles.itemName}>{item.name}</div>
                      <div className={styles.itemPrice}>TShs {item.price?.toLocaleString()} / {item.unit}</div>
                    </div>
                    <div className={styles.itemQty}>x{item.quantity}</div>
                    <div className={styles.itemSubtotal}>
                      TShs {((item.price || 0) * (item.quantity || 1)).toLocaleString()}
                    </div>
                  </div>
                ))}
              </div>

              {/* Summary */}
              <div className={styles.orderSummary}>
                <div className={styles.summaryRow}>
                  <span>Subtotal</span>
                  <span>TShs {viewOrder.total?.toLocaleString()}</span>
                </div>
                {viewOrder.delivery?.cost && (
                  <div className={styles.summaryRow}>
                    <span>Delivery Fee</span>
                    <span>TShs {viewOrder.delivery.cost?.toLocaleString()}</span>
                  </div>
                )}
                <div className={styles.summaryRow}>
                  <strong>Grand Total</strong>
                  <strong>TShs {(viewOrder.grandTotal || viewOrder.total)?.toLocaleString()}</strong>
                </div>
              </div>
            </div>
            <div className={styles.modalFooter}>
              <button className={styles.cancelBtn} onClick={() => setViewOrder(null)}>Close</button>
              {!viewOrder.delivery?.driverId && viewOrder.status !== 'cancelled' && (
                <button className={styles.submitBtn}
                  onClick={() => { setViewOrder(null); setAssignModal(viewOrder); }}>
                  Assign Driver
                </button>
              )}
            </div>
          </div>
        </div>
      )}

      {/* ── Assign Driver Modal ── */}
      {assignModal && (
        <div className={styles.overlay} onClick={() => setAssignModal(null)}>
          <div className={styles.modal} onClick={e => e.stopPropagation()}>
            <div className={styles.modalHeader}>
              <h3>Assign Driver — #{assignModal.id.substring(0, 6).toUpperCase()}</h3>
              <button className={styles.closeBtn} onClick={() => setAssignModal(null)}>✕</button>
            </div>
            <div className={styles.modalBody}>
              {drivers.length === 0 ? (
                <p className={styles.noDriverCard}>No drivers registered yet.</p>
              ) : (
                <div className={styles.driverList}>
                  {drivers.map(driver => (
                    <div key={driver.id} className={styles.driverCard}>
                      <div className={styles.driverInfo}>
                        <div className={styles.driverAvatar}>
                          {(driver.username || 'D').charAt(0).toUpperCase()}
                        </div>
                        <div>
                          <div className={styles.driverName}>
                            {driver.fullName || driver.username}
                            <span className={`${styles.onlineDot} ${driver.isOnline ? styles.online : styles.offline}`} />
                          </div>
                          <div className={styles.driverPhone}>
                            <Phone size={11} /> {driver.phone || 'N/A'}
                          </div>
                          <div className={styles.driverPhone}>
                            <MapPin size={11} /> {driver.location?.name || 'N/A'}
                          </div>
                        </div>
                      </div>
                      <button
                        className={styles.assignConfirmBtn}
                        onClick={() => assignDriver(assignModal.id, driver.id)}
                      >
                        Assign
                      </button>
                    </div>
                  ))}
                </div>
              )}
            </div>
            <div className={styles.modalFooter}>
              <button className={styles.cancelBtn} onClick={() => setAssignModal(null)}>Cancel</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
