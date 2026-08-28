import { useEffect, useState } from 'react';
import { collection, onSnapshot, query, orderBy, limit } from 'firebase/firestore';
import { db } from '../firebase';
import {
  Users, ShoppingCart, Store, Truck, Fish,
  ShoppingBag, TrendingUp, Clock, CheckCircle2,
  XCircle, AlertCircle, Package,
} from 'lucide-react';
import styles from './Overview.module.css';

// ── helpers ───────────────────────────────────────────────────────────────────
const fmt = n =>
  n >= 1_000_000 ? `${(n / 1_000_000).toFixed(1)}M`
  : n >= 1_000   ? `${(n / 1_000).toFixed(1)}K`
  : String(n);

const fmtMoney = n =>
  n >= 1_000_000 ? `TShs ${(n/1_000_000).toFixed(1)}M`
  : n >= 1_000   ? `TShs ${(n/1_000).toFixed(1)}K`
  : `TShs ${n.toFixed(0)}`;

function timeAgo(ts) {
  if (!ts) return '';
  const d = ts.seconds ? new Date(ts.seconds * 1000) : new Date(ts);
  const diff = Math.floor((Date.now() - d) / 1000);
  if (diff < 60)  return `${diff}s ago`;
  if (diff < 3600) return `${Math.floor(diff/60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff/3600)}h ago`;
  return `${Math.floor(diff/86400)}d ago`;
}

const STATUS_META = {
  pending:   { label: 'Pending',   color: '#f59e0b', bg: '#fffbeb', Icon: AlertCircle },
  confirmed: { label: 'Confirmed', color: '#3b82f6', bg: '#eff6ff', Icon: CheckCircle2 },
  delivered: { label: 'Delivered', color: '#10b981', bg: '#ecfdf5', Icon: CheckCircle2 },
  cancelled: { label: 'Cancelled', color: '#ef4444', bg: '#fef2f2', Icon: XCircle },
};

// ── StatCard ──────────────────────────────────────────────────────────────────
function StatCard({ Icon, label, value, sub, color, bg }) {
  return (
    <div className={styles.statCard}>
      <div className={styles.statLeft}>
        <div className={styles.statIconWrap} style={{ background: bg, color }}>
          <Icon size={22} />
        </div>
        <div>
          <div className={styles.statLabel}>{label}</div>
          <div className={styles.statValue}>{value}</div>
          {sub && <div className={styles.statSub}>{sub}</div>}
        </div>
      </div>
      <div className={styles.statBar}>
        <div className={styles.statBarFill} style={{ background: color }} />
      </div>
    </div>
  );
}

// ── Main ──────────────────────────────────────────────────────────────────────
export default function Overview() {
  const [users,    setUsers]    = useState([]);
  const [products, setProducts] = useState([]);
  const [orders,   setOrders]   = useState([]);
  const [recent,   setRecent]   = useState([]);

  useEffect(() => {
    const u1 = onSnapshot(collection(db, 'users'), s =>
      setUsers(s.docs.map(d => d.data()).filter(u => u.deleted !== true)));
    const u2 = onSnapshot(collection(db, 'products'), s =>
      setProducts(s.docs.map(d => d.data())));
    const u3 = onSnapshot(collection(db, 'orders'), s =>
      setOrders(s.docs.map(d => ({ id: d.id, ...d.data() }))));
    const u4 = onSnapshot(
      query(collection(db, 'orders'), orderBy('createdAt', 'desc'), limit(6)),
      s => setRecent(s.docs.map(d => ({ id: d.id, ...d.data() })))
    );
    return () => { u1(); u2(); u3(); u4(); };
  }, []);

  // Derived
  const customers    = users.filter(u => u.role === 'customer').length;
  const sellers      = users.filter(u => u.role === 'seller').length;
  const drivers      = users.filter(u => u.role === 'driver').length;
  const activeProds  = products.filter(p => p.isAvailable).length;
  const pending      = orders.filter(o => o.status === 'pending').length;
  const delivered    = orders.filter(o => o.status === 'delivered').length;
  const totalRev     = orders
    .filter(o => o.status === 'confirmed' || o.status === 'delivered')
    .reduce((s, o) => s + (o.grandTotal || o.total || 0), 0);
  const completionPct = orders.length
    ? Math.round((delivered / orders.length) * 100) : 0;

  // Greeting
  const hour = new Date().getHours();
  const greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';

  return (
    <div className={styles.wrap}>

      {/* ── Header ── */}
      <div className={styles.header}>
        <div>
          <div className={styles.greeting}>{greeting}, Admin 👋</div>
          <h2 className={styles.title}>Dashboard Overview</h2>
          <p className={styles.sub}>Here's what's happening with ZanSeaFood today</p>
        </div>
        <div className={styles.dateBadge}>
          <Clock size={14} />
          {new Date().toLocaleDateString('en-GB', { weekday:'long', day:'numeric', month:'long', year:'numeric' })}
        </div>
      </div>

      {/* ── Stat cards row 1: Users ── */}
      <div className={styles.sectionLabel}>Users</div>
      <div className={styles.grid4}>
        <StatCard Icon={Users}        label="Total Users"  value={fmt(users.length)}  color="#4f46e5" bg="#eef2ff" />
        <StatCard Icon={ShoppingCart} label="Customers"    value={fmt(customers)}     color="#059669" bg="#ecfdf5" />
        <StatCard Icon={Store}        label="Sellers"      value={fmt(sellers)}       color="#d97706" bg="#fffbeb" />
        <StatCard Icon={Truck}        label="Drivers"      value={fmt(drivers)}       color="#0891b2" bg="#ecfeff" />
      </div>

      {/* ── Stat cards row 2: Business ── */}
      <div className={styles.sectionLabel} style={{ marginTop: 24 }}>Business</div>
      <div className={styles.grid4}>
        <StatCard Icon={Fish}         label="Total Products"  value={fmt(products.length)} color="#7c3aed" bg="#f5f3ff" />
        <StatCard Icon={Package}      label="Active Products" value={fmt(activeProds)}     color="#16a34a" bg="#f0fdf4"
          sub={`${products.length ? Math.round((activeProds/products.length)*100) : 0}% available`} />
        <StatCard Icon={ShoppingBag}  label="Total Orders"    value={fmt(orders.length)}   color="#dc2626" bg="#fef2f2" />
        <StatCard Icon={TrendingUp}   label="Total Revenue"   value={fmtMoney(totalRev)}   color="#0f766e" bg="#f0fdfa" />
      </div>

      {/* ── Middle row: Order summary + completion ring ── */}
      <div className={styles.midRow}>

        {/* Order status breakdown */}
        <div className={styles.card}>
          <div className={styles.cardHeader}>
            <ShoppingBag size={16} />
            <span>Order Status</span>
          </div>
          <div className={styles.statusList}>
            {[
              { key:'pending',   label:'Pending',   val: pending,   color:'#f59e0b' },
              { key:'confirmed', label:'Confirmed', val: orders.filter(o=>o.status==='confirmed').length, color:'#3b82f6' },
              { key:'delivered', label:'Delivered', val: delivered, color:'#10b981' },
              { key:'cancelled', label:'Cancelled', val: orders.filter(o=>o.status==='cancelled').length, color:'#ef4444' },
            ].map(s => {
              const pct = orders.length ? Math.round((s.val / orders.length) * 100) : 0;
              return (
                <div key={s.key} className={styles.statusRow}>
                  <div className={styles.statusDot} style={{ background: s.color }} />
                  <span className={styles.statusLabel}>{s.label}</span>
                  <div className={styles.statusTrack}>
                    <div className={styles.statusFill}
                      style={{ width: `${pct}%`, background: s.color }} />
                  </div>
                  <span className={styles.statusCount}>{s.val}</span>
                  <span className={styles.statusPct}>{pct}%</span>
                </div>
              );
            })}
          </div>
        </div>

        {/* Completion ring */}
        <div className={styles.card} style={{ display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center', gap: 16 }}>
          <div className={styles.cardHeader} style={{ alignSelf:'flex-start' }}>
            <TrendingUp size={16} />
            <span>Delivery Rate</span>
          </div>
          <div
            className={styles.ring}
            style={{
              background: `conic-gradient(#10b981 0% ${completionPct}%, #f3f4f6 ${completionPct}% 100%)`,
            }}
          >
            <div className={styles.ringInner}>
              <div className={styles.ringPct}>{completionPct}%</div>
              <div className={styles.ringLabel}>completed</div>
            </div>
          </div>
          <div className={styles.ringStats}>
            <div className={styles.ringStat}>
              <div style={{ color:'#10b981', fontWeight:700, fontSize:20 }}>{delivered}</div>
              <div style={{ fontSize:11, color:'#6b7280' }}>Delivered</div>
            </div>
            <div className={styles.ringDivider} />
            <div className={styles.ringStat}>
              <div style={{ color:'#f59e0b', fontWeight:700, fontSize:20 }}>{pending}</div>
              <div style={{ fontSize:11, color:'#6b7280' }}>Pending</div>
            </div>
          </div>
        </div>

        {/* Revenue highlight */}
        <div className={styles.card} style={{ background:'linear-gradient(135deg,#1e1b4b,#3730a3)', color:'white' }}>
          <div className={styles.cardHeader} style={{ color:'rgba(255,255,255,0.7)' }}>
            <TrendingUp size={16} />
            <span>Revenue Summary</span>
          </div>
          <div style={{ marginTop:16 }}>
            <div style={{ fontSize:13, color:'rgba(255,255,255,0.6)', marginBottom:4 }}>Total Revenue</div>
            <div style={{ fontSize:28, fontWeight:800, letterSpacing:'-0.5px' }}>{fmtMoney(totalRev)}</div>
          </div>
          <div style={{ marginTop:20, display:'flex', gap:16 }}>
            <div>
              <div style={{ fontSize:11, color:'rgba(255,255,255,0.5)' }}>Orders</div>
              <div style={{ fontSize:18, fontWeight:700 }}>{orders.length}</div>
            </div>
            <div>
              <div style={{ fontSize:11, color:'rgba(255,255,255,0.5)' }}>Avg. Order</div>
              <div style={{ fontSize:18, fontWeight:700 }}>
                {orders.length
                  ? `TShs ${fmt(Math.round(totalRev / Math.max(delivered,1)))}`
                  : 'TShs 0'}
              </div>
            </div>
            <div>
              <div style={{ fontSize:11, color:'rgba(255,255,255,0.5)' }}>Products</div>
              <div style={{ fontSize:18, fontWeight:700 }}>{products.length}</div>
            </div>
          </div>
        </div>
      </div>

      {/* ── Recent orders table ── */}
      <div className={styles.card} style={{ marginTop: 0 }}>
        <div className={styles.cardHeader}>
          <ShoppingBag size={16} />
          <span>Recent Orders</span>
          <span className={styles.badge}>{recent.length} latest</span>
        </div>
        <div className={styles.tableWrap}>
          <table className={styles.table}>
            <thead>
              <tr>
                <th>Order ID</th>
                <th>Items</th>
                <th>Total</th>
                <th>Status</th>
                <th>Time</th>
              </tr>
            </thead>
            <tbody>
              {recent.length === 0 ? (
                <tr><td colSpan={5} className={styles.emptyCell}>No orders yet</td></tr>
              ) : recent.map(o => {
                const meta = STATUS_META[o.status] || STATUS_META.pending;
                const StatusIcon = meta.Icon;
                return (
                  <tr key={o.id}>
                    <td className={styles.orderId}>#{o.id.substring(0,6).toUpperCase()}</td>
                    <td>{(o.items || []).length} item{(o.items||[]).length !== 1 ? 's':''}</td>
                    <td className={styles.orderTotal}>TShs {((o.grandTotal || o.total || 0)).toFixed(0)}</td>
                    <td>
                      <span className={styles.statusBadge}
                        style={{ color: meta.color, background: meta.bg }}>
                        <StatusIcon size={11} />
                        {meta.label}
                      </span>
                    </td>
                    <td className={styles.timeAgo}>{timeAgo(o.createdAt)}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>

    </div>
  );
}
