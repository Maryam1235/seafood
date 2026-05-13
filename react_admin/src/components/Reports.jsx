import { useEffect, useState } from 'react';
import { collection, onSnapshot } from 'firebase/firestore';
import { db } from '../firebase';
import {
  AreaChart, Area, BarChart, Bar, PieChart, Pie, Cell,
  XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer,
} from 'recharts';
import { TrendingUp, ShoppingBag, Users, Truck, DollarSign, Package } from 'lucide-react';
import styles from './Reports.module.css';

const MONTHS = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
const ROLE_COLORS  = { customer: '#4f46e5', seller: '#059669', driver: '#d97706' };
const STATUS_COLORS = { pending: '#f59e0b', confirmed: '#3b82f6', delivered: '#10b981', cancelled: '#ef4444' };

// ── helpers ──────────────────────────────────────────────────────────────────
function monthKey(ts) {
  if (!ts) return null;
  const d = ts.seconds ? new Date(ts.seconds * 1000) : new Date(ts);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
}

function last6Months() {
  const result = [];
  const now = new Date();
  for (let i = 5; i >= 0; i--) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
    result.push({ key: `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}`, label: MONTHS[d.getMonth()] });
  }
  return result;
}

// ── StatCard ─────────────────────────────────────────────────────────────────
function StatCard({ icon: Icon, label, value, sub, color }) {
  return (
    <div className={styles.statCard} style={{ borderLeft: `4px solid ${color}` }}>
      <div className={styles.statIcon} style={{ background: color + '18', color }}><Icon size={22} /></div>
      <div>
        <div className={styles.statValue}>{value}</div>
        <div className={styles.statLabel}>{label}</div>
        {sub && <div className={styles.statSub}>{sub}</div>}
      </div>
    </div>
  );
}

// ── Main ─────────────────────────────────────────────────────────────────────
export default function Reports() {
  const [orders,   setOrders]   = useState([]);
  const [users,    setUsers]    = useState([]);
  const [products, setProducts] = useState([]);

  useEffect(() => {
    const u1 = onSnapshot(collection(db, 'orders'),   s => setOrders(s.docs.map(d => ({ id: d.id, ...d.data() }))));
    const u2 = onSnapshot(collection(db, 'users'),    s => setUsers(s.docs.map(d => ({ id: d.id, ...d.data() })).filter(u => u.deleted !== true)));
    const u3 = onSnapshot(collection(db, 'products'), s => setProducts(s.docs.map(d => ({ id: d.id, ...d.data() }))));
    return () => { u1(); u2(); u3(); };
  }, []);

  // ── derived stats ──────────────────────────────────────────────────────────
  const delivered   = orders.filter(o => o.status === 'delivered');
  const totalRev    = delivered.reduce((s, o) => s + (o.grandTotal || o.total || 0), 0);
  const deliveryRev = delivered.reduce((s, o) => s + (o.delivery?.cost || 0), 0);
  const avgOrder    = delivered.length ? totalRev / delivered.length : 0;

  // ── monthly revenue (last 6 months) ───────────────────────────────────────
  const months = last6Months();
  const monthlyRevenue = months.map(({ key, label }) => {
    const mo = delivered.filter(o => monthKey(o.createdAt) === key);
    return {
      month: label,
      revenue: mo.reduce((s, o) => s + (o.grandTotal || o.total || 0), 0),
      orders:  mo.length,
    };
  });

  // ── monthly new users ──────────────────────────────────────────────────────
  const monthlyUsers = months.map(({ key, label }) => {
    const mu = users.filter(u => monthKey(u.createdAt) === key);
    return {
      month: label,
      customers: mu.filter(u => u.role === 'customer').length,
      sellers:   mu.filter(u => u.role === 'seller').length,
      drivers:   mu.filter(u => u.role === 'driver').length,
    };
  });

  // ── order status breakdown ─────────────────────────────────────────────────
  const statusData = Object.entries(
    orders.reduce((acc, o) => {
      const s = o.status || 'unknown';
      acc[s] = (acc[s] || 0) + 1;
      return acc;
    }, {})
  ).map(([name, value]) => ({ name, value }));

  // ── user role breakdown ────────────────────────────────────────────────────
  const roleData = ['customer', 'seller', 'driver'].map(r => ({
    name: r.charAt(0).toUpperCase() + r.slice(1) + 's',
    value: users.filter(u => u.role === r).length,
  }));

  // ── top products by order frequency ───────────────────────────────────────
  const productFreq = {};
  orders.forEach(o => {
    (o.items || []).forEach(item => {
      const name = item.name || 'Unknown';
      productFreq[name] = (productFreq[name] || 0) + (item.quantity || 1);
    });
  });
  const topProducts = Object.entries(productFreq)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 6)
    .map(([name, qty]) => ({ name, qty }));

  // ── delivery performance ───────────────────────────────────────────────────
  const driverPerf = {};
  delivered.forEach(o => {
    const name = o.delivery?.driverName || 'Unknown';
    if (!driverPerf[name]) driverPerf[name] = { deliveries: 0, earned: 0 };
    driverPerf[name].deliveries++;
    driverPerf[name].earned += o.delivery?.cost || 0;
  });
  const topDrivers = Object.entries(driverPerf)
    .sort((a, b) => b[1].deliveries - a[1].deliveries)
    .slice(0, 5);

  const fmt = (n) => n >= 1_000_000 ? `${(n/1_000_000).toFixed(1)}M`
                   : n >= 1_000     ? `${(n/1_000).toFixed(1)}K`
                   : n.toFixed(0);

  return (
    <div className={styles.wrap}>
      <h2 className={styles.title}>Reports & Analytics</h2>
      <p className={styles.sub}>Real-time insights across users, orders, products and deliveries</p>

      {/* ── KPI row ── */}
      <div className={styles.kpiRow}>
        <StatCard icon={DollarSign} label="Total Revenue"    value={`TShs ${fmt(totalRev)}`}    color="#4f46e5" />
        <StatCard icon={ShoppingBag} label="Total Orders"    value={orders.length}               color="#059669" />
        <StatCard icon={TrendingUp}  label="Delivered"       value={delivered.length}            color="#10b981"
          sub={`${orders.length ? ((delivered.length/orders.length)*100).toFixed(0) : 0}% completion`} />
        <StatCard icon={DollarSign}  label="Avg Order Value" value={`TShs ${fmt(avgOrder)}`}     color="#d97706" />
        <StatCard icon={Truck}       label="Delivery Revenue" value={`TShs ${fmt(deliveryRev)}`} color="#0891b2" />
        <StatCard icon={Users}       label="Total Users"     value={users.length}                color="#7c3aed" />
      </div>

      {/* ── Revenue + Orders trend ── */}
      <div className={styles.row}>
        <div className={styles.chartCard}>
          <div className={styles.chartTitle}>Revenue Trend (Last 6 Months)</div>
          <ResponsiveContainer width="100%" height={240}>
            <AreaChart data={monthlyRevenue} margin={{ top: 10, right: 20, left: 0, bottom: 0 }}>
              <defs>
                <linearGradient id="revGrad" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%"  stopColor="#4f46e5" stopOpacity={0.25} />
                  <stop offset="95%" stopColor="#4f46e5" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
              <XAxis dataKey="month" tick={{ fontSize: 12 }} />
              <YAxis tick={{ fontSize: 11 }} tickFormatter={v => `${fmt(v)}`} />
              <Tooltip formatter={(v) => [`TShs ${fmt(v)}`, 'Revenue']} />
              <Area type="monotone" dataKey="revenue" stroke="#4f46e5" strokeWidth={2} fill="url(#revGrad)" />
            </AreaChart>
          </ResponsiveContainer>
        </div>

        <div className={styles.chartCard}>
          <div className={styles.chartTitle}>Orders per Month</div>
          <ResponsiveContainer width="100%" height={240}>
            <BarChart data={monthlyRevenue} margin={{ top: 10, right: 20, left: 0, bottom: 0 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
              <XAxis dataKey="month" tick={{ fontSize: 12 }} />
              <YAxis tick={{ fontSize: 11 }} allowDecimals={false} />
              <Tooltip />
              <Bar dataKey="orders" fill="#10b981" radius={[6, 6, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* ── Pie charts row ── */}
      <div className={styles.row}>
        <div className={styles.chartCard}>
          <div className={styles.chartTitle}>Order Status Breakdown</div>
          <ResponsiveContainer width="100%" height={240}>
            <PieChart>
              <Pie data={statusData} cx="50%" cy="50%" outerRadius={90} dataKey="value" label={({ name, percent }) => `${name} ${(percent*100).toFixed(0)}%`} labelLine={false}>
                {statusData.map((entry) => (
                  <Cell key={entry.name} fill={STATUS_COLORS[entry.name] || '#94a3b8'} />
                ))}
              </Pie>
              <Tooltip />
            </PieChart>
          </ResponsiveContainer>
        </div>

        <div className={styles.chartCard}>
          <div className={styles.chartTitle}>User Role Distribution</div>
          <ResponsiveContainer width="100%" height={240}>
            <PieChart>
              <Pie data={roleData} cx="50%" cy="50%" innerRadius={55} outerRadius={90} dataKey="value" label={({ name, value }) => `${name}: ${value}`} labelLine={false}>
                {roleData.map((entry) => (
                  <Cell key={entry.name} fill={ROLE_COLORS[entry.name.toLowerCase().replace('s','')] || '#94a3b8'} />
                ))}
              </Pie>
              <Tooltip />
            </PieChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* ── New users trend ── */}
      <div className={styles.row}>
        <div className={`${styles.chartCard} ${styles.wide}`}>
          <div className={styles.chartTitle}>New User Registrations (Last 6 Months)</div>
          <ResponsiveContainer width="100%" height={240}>
            <BarChart data={monthlyUsers} margin={{ top: 10, right: 20, left: 0, bottom: 0 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
              <XAxis dataKey="month" tick={{ fontSize: 12 }} />
              <YAxis tick={{ fontSize: 11 }} allowDecimals={false} />
              <Tooltip />
              <Legend />
              <Bar dataKey="customers" fill="#4f46e5" radius={[4,4,0,0]} name="Customers" />
              <Bar dataKey="sellers"   fill="#059669" radius={[4,4,0,0]} name="Sellers" />
              <Bar dataKey="drivers"   fill="#d97706" radius={[4,4,0,0]} name="Drivers" />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* ── Top products + Top drivers ── */}
      <div className={styles.row}>
        <div className={styles.chartCard}>
          <div className={styles.chartTitle}>Top Products by Quantity Ordered</div>
          {topProducts.length === 0
            ? <p className={styles.empty}>No order data yet</p>
            : <ResponsiveContainer width="100%" height={220}>
                <BarChart data={topProducts} layout="vertical" margin={{ top: 0, right: 20, left: 10, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                  <XAxis type="number" tick={{ fontSize: 11 }} allowDecimals={false} />
                  <YAxis type="category" dataKey="name" tick={{ fontSize: 11 }} width={90} />
                  <Tooltip />
                  <Bar dataKey="qty" fill="#7c3aed" radius={[0,6,6,0]} name="Qty Ordered" />
                </BarChart>
              </ResponsiveContainer>
          }
        </div>

        <div className={styles.chartCard}>
          <div className={styles.chartTitle}>Top Drivers by Deliveries</div>
          {topDrivers.length === 0
            ? <p className={styles.empty}>No delivery data yet</p>
            : <div className={styles.driverTable}>
                <div className={styles.driverHeader}>
                  <span>Driver</span><span>Deliveries</span><span>Earned</span>
                </div>
                {topDrivers.map(([name, d], i) => (
                  <div key={name} className={styles.driverRow}>
                    <span className={styles.driverRank}>
                      <span className={styles.rankBadge} style={{ background: i === 0 ? '#f59e0b' : i === 1 ? '#94a3b8' : i === 2 ? '#b45309' : '#e5e7eb', color: i < 3 ? 'white' : '#374151' }}>
                        {i + 1}
                      </span>
                      {name}
                    </span>
                    <span className={styles.driverDeliveries}>{d.deliveries}</span>
                    <span className={styles.driverEarned}>TShs {fmt(d.earned)}</span>
                  </div>
                ))}
              </div>
          }
        </div>
      </div>

      {/* ── Products stock summary ── */}
      <div className={styles.row}>
        <div className={`${styles.chartCard} ${styles.wide}`}>
          <div className={styles.chartTitle}>
            <Package size={16} style={{ marginRight: 6, verticalAlign: 'middle' }} />
            Products Stock Summary
          </div>
          <div className={styles.stockGrid}>
            {products.slice(0, 12).map(p => {
              const pct = Math.min(100, ((p.stock || 0) / Math.max(p.stock || 1, 50)) * 100);
              const color = pct > 50 ? '#10b981' : pct > 20 ? '#f59e0b' : '#ef4444';
              return (
                <div key={p.id} className={styles.stockItem}>
                  <div className={styles.stockName}>{p.name || 'Unknown'}</div>
                  <div className={styles.stockBar}>
                    <div className={styles.stockFill} style={{ width: `${pct}%`, background: color }} />
                  </div>
                  <div className={styles.stockQty} style={{ color }}>{p.stock ?? 0} {p.unit || ''}</div>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
}
