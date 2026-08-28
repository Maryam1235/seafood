import { useEffect, useState } from 'react';
import { collection, onSnapshot } from 'firebase/firestore';
import { db } from '../firebase';
import { TrendingUp, ShoppingBag, Users, Truck, DollarSign, Package, BarChart2 } from 'lucide-react';
import styles from './Reports.module.css';

const MONTHS = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
const STATUS_COLORS = { pending: '#f59e0b', confirmed: '#3b82f6', delivered: '#10b981', cancelled: '#ef4444' };
const ROLE_COLORS   = { customer: '#4f46e5', seller: '#059669', driver: '#d97706' };

function monthKey(ts) {
  if (!ts) return null;
  const d = ts.seconds ? new Date(ts.seconds * 1000) : new Date(ts);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
}

function last6Months() {
  const now = new Date();
  return Array.from({ length: 6 }, (_, i) => {
    const d = new Date(now.getFullYear(), now.getMonth() - (5 - i), 1);
    return { key: `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}`, label: MONTHS[d.getMonth()] };
  });
}

const fmt = n =>
  n >= 1_000_000 ? `${(n/1_000_000).toFixed(1)}M`
  : n >= 1_000   ? `${(n/1_000).toFixed(1)}K`
  : Number(n).toFixed(0);

// ── Stat card ────────────────────────────────────────────────────────────────
function StatCard({ icon: Icon, label, value, sub, color }) {
  return (
    <div className={styles.statCard} style={{ borderLeft: `4px solid ${color}` }}>
      <div className={styles.statIcon} style={{ background: color + '18', color }}>
        <Icon size={22} />
      </div>
      <div>
        <div className={styles.statValue}>{value}</div>
        <div className={styles.statLabel}>{label}</div>
        {sub && <div className={styles.statSub}>{sub}</div>}
      </div>
    </div>
  );
}

// ── Bar chart (pure CSS) ─────────────────────────────────────────────────────
function BarChartCSS({ data, dataKey, color = '#4f46e5', labelKey = 'month', formatValue }) {
  if (!data || data.length === 0) return <p className={styles.empty}>No data yet</p>;
  const max = Math.max(...data.map(d => d[dataKey] || 0), 1);
  return (
    <div className={styles.barChart}>
      {data.map((d, i) => {
        const val = d[dataKey] || 0;
        const pct = (val / max) * 100;
        return (
          <div key={i} className={styles.barGroup}>
            <div className={styles.barValueLabel}>{val > 0 ? (formatValue ? formatValue(val) : val) : ''}</div>
            <div className={styles.barTrack}>
              <div className={styles.barFill} style={{ height: `${pct}%`, background: color }} />
            </div>
            <div className={styles.barLabel}>{d[labelKey]}</div>
          </div>
        );
      })}
    </div>
  );
}

// ── Grouped bar chart (pure CSS) ─────────────────────────────────────────────
function GroupedBarCSS({ data, groups, labelKey = 'month' }) {
  if (!data || data.length === 0) return <p className={styles.empty}>No data yet</p>;
  const max = Math.max(...data.flatMap(d => groups.map(g => d[g.key] || 0)), 1);
  return (
    <div className={styles.barChart}>
      {data.map((d, i) => (
        <div key={i} className={styles.barGroup}>
          <div className={styles.groupedBars}>
            {groups.map(g => {
              const val = d[g.key] || 0;
              const pct = (val / max) * 100;
              return (
                <div key={g.key} className={styles.groupedBarWrap} title={`${g.label}: ${val}`}>
                  <div className={styles.barFill} style={{ height: `${pct}%`, background: g.color }} />
                </div>
              );
            })}
          </div>
          <div className={styles.barLabel}>{d[labelKey]}</div>
        </div>
      ))}
    </div>
  );
}

// ── Horizontal bar chart (pure CSS) ──────────────────────────────────────────
function HorizontalBarCSS({ data, dataKey = 'qty', labelKey = 'name', color = '#7c3aed' }) {
  if (!data || data.length === 0) return <p className={styles.empty}>No order data yet</p>;
  const max = Math.max(...data.map(d => d[dataKey] || 0), 1);
  return (
    <div className={styles.hBarList}>
      {data.map((d, i) => {
        const val = d[dataKey] || 0;
        const pct = (val / max) * 100;
        return (
          <div key={i} className={styles.hBarRow}>
            <div className={styles.hBarLabel}>{d[labelKey]}</div>
            <div className={styles.hBarTrack}>
              <div className={styles.hBarFill} style={{ width: `${pct}%`, background: color }} />
            </div>
            <div className={styles.hBarValue}>{val}</div>
          </div>
        );
      })}
    </div>
  );
}

// ── Pie / donut chart (pure CSS — segmented ring) ────────────────────────────
function DonutCSS({ data, colors, inner = false }) {
  if (!data || data.length === 0) return <p className={styles.empty}>No data yet</p>;
  const total = data.reduce((s, d) => s + (d.value || 0), 0);
  if (total === 0) return <p className={styles.empty}>No data yet</p>;

  // Build conic-gradient segments
  let cumulative = 0;
  const segments = data.map((d, i) => {
    const pct = (d.value / total) * 100;
    const start = cumulative;
    cumulative += pct;
    return { ...d, pct, start, color: colors[i % colors.length] };
  });

  const gradient = segments
    .map(s => `${s.color} ${s.start.toFixed(1)}% ${(s.start + s.pct).toFixed(1)}%`)
    .join(', ');

  return (
    <div className={styles.donutWrap}>
      <div
        className={styles.donut}
        style={{
          background: `conic-gradient(${gradient})`,
          borderRadius: '50%',
        }}
      >
        {inner && (
          <div className={styles.donutHole}>
            <div className={styles.donutTotal}>{total}</div>
            <div className={styles.donutTotalLabel}>total</div>
          </div>
        )}
      </div>
      <div className={styles.donutLegend}>
        {segments.map((s, i) => (
          <div key={i} className={styles.legendItem}>
            <span className={styles.legendDot} style={{ background: s.color }} />
            <span className={styles.legendName}>{s.name}</span>
            <span className={styles.legendVal}>{s.value} ({s.pct.toFixed(0)}%)</span>
          </div>
        ))}
      </div>
    </div>
  );
}

// ── Main component ────────────────────────────────────────────────────────────
export default function Reports() {
  const [orders,   setOrders]   = useState([]);
  const [users,    setUsers]    = useState([]);
  const [products, setProducts] = useState([]);

  useEffect(() => {
    const u1 = onSnapshot(collection(db, 'orders'),
      s => setOrders(s.docs.map(d => ({ id: d.id, ...d.data() }))));
    const u2 = onSnapshot(collection(db, 'users'),
      s => setUsers(s.docs.map(d => ({ id: d.id, ...d.data() })).filter(u => u.deleted !== true)));
    const u3 = onSnapshot(collection(db, 'products'),
      s => setProducts(s.docs.map(d => ({ id: d.id, ...d.data() }))));
    return () => { u1(); u2(); u3(); };
  }, []);

  const delivered   = orders.filter(o => o.status === 'delivered');
  const paidOrders  = orders.filter(o => o.status === 'confirmed' || o.status === 'delivered');
  const totalRev    = paidOrders.reduce((s, o) => s + (o.grandTotal || o.total || 0), 0);
  const deliveryRev = paidOrders.reduce((s, o) => s + (o.delivery?.cost || 0), 0);
  const avgOrder    = delivered.length ? totalRev / delivered.length : 0;

  const months = last6Months();

  const monthlyRevenue = months.map(({ key, label }) => {
    const mo = delivered.filter(o => monthKey(o.createdAt) === key);
    return {
      month:   label,
      revenue: mo.reduce((s, o) => s + (o.grandTotal || o.total || 0), 0),
      orders:  orders.filter(o => monthKey(o.createdAt) === key).length,
    };
  });

  const monthlyUsers = months.map(({ key, label }) => {
    const mu = users.filter(u => monthKey(u.createdAt) === key);
    return {
      month:     label,
      customers: mu.filter(u => u.role === 'customer').length,
      sellers:   mu.filter(u => u.role === 'seller').length,
      drivers:   mu.filter(u => u.role === 'driver').length,
    };
  });

  const statusData = Object.entries(
    orders.reduce((acc, o) => { const s = o.status || 'unknown'; acc[s] = (acc[s]||0)+1; return acc; }, {})
  ).map(([name, value]) => ({ name, value }));

  const roleData = ['customer','seller','driver'].map(r => ({
    name:  r.charAt(0).toUpperCase() + r.slice(1) + 's',
    value: users.filter(u => u.role === r).length,
  }));

  const productFreq = {};
  orders.forEach(o => {
    (o.items || []).forEach(item => {
      const name = item.name || item.productName || 'Unknown';
      if (name === 'Unknown') return;
      productFreq[name] = (productFreq[name] || 0) + (Number(item.quantity) || 1);
    });
  });
  const topProducts = Object.entries(productFreq)
    .sort((a, b) => b[1] - a[1]).slice(0, 6)
    .map(([name, qty]) => ({ name, qty }));

  const driverPerf = {};
  delivered.forEach(o => {
    const name = o.delivery?.driverName || 'Unknown';
    if (!driverPerf[name]) driverPerf[name] = { deliveries: 0, earned: 0 };
    driverPerf[name].deliveries++;
    driverPerf[name].earned += o.delivery?.cost || 0;
  });
  const topDrivers = Object.entries(driverPerf)
    .sort((a, b) => b[1].deliveries - a[1].deliveries).slice(0, 5);

  return (
    <div className={styles.wrap}>
      <h2 className={styles.title}>Reports & Analytics</h2>
      <p className={styles.sub}>Real-time insights across users, orders, products and deliveries</p>

      {/* KPI cards */}
      <div className={styles.kpiRow}>
        <StatCard icon={DollarSign}  label="Total Revenue"    value={`TShs ${fmt(totalRev)}`}   color="#4f46e5" />
        <StatCard icon={ShoppingBag} label="Total Orders"     value={orders.length}              color="#059669" />
        <StatCard icon={TrendingUp}  label="Delivered"        value={delivered.length}           color="#10b981"
          sub={`${orders.length ? ((delivered.length/orders.length)*100).toFixed(0) : 0}% completion`} />
        <StatCard icon={DollarSign}  label="Avg Order Value"  value={`TShs ${fmt(avgOrder)}`}    color="#d97706" />
        <StatCard icon={Truck}       label="Delivery Revenue" value={`TShs ${fmt(deliveryRev)}`} color="#0891b2" />
        <StatCard icon={Users}       label="Total Users"      value={users.length}               color="#7c3aed" />
      </div>

      {/* Revenue + Orders per month */}
      <div className={styles.row}>
        <div className={styles.chartCard}>
          <div className={styles.chartTitle}>
            <BarChart2 size={15} style={{ marginRight: 6 }} /> Revenue Trend (Last 6 Months)
          </div>
          <BarChartCSS
            data={monthlyRevenue} dataKey="revenue" color="#4f46e5"
            formatValue={v => `TShs ${fmt(v)}`}
          />
        </div>
        <div className={styles.chartCard}>
          <div className={styles.chartTitle}>
            <BarChart2 size={15} style={{ marginRight: 6 }} /> Orders per Month
          </div>
          <BarChartCSS data={monthlyRevenue} dataKey="orders" color="#10b981" />
        </div>
      </div>

      {/* Order status + User role */}
      <div className={styles.row}>
        <div className={styles.chartCard}>
          <div className={styles.chartTitle}>Order Status Breakdown</div>
          <DonutCSS
            data={statusData}
            colors={statusData.map(d => STATUS_COLORS[d.name] || '#94a3b8')}
          />
        </div>
        <div className={styles.chartCard}>
          <div className={styles.chartTitle}>User Role Distribution</div>
          <DonutCSS
            data={roleData}
            colors={['#4f46e5','#059669','#d97706']}
            inner
          />
        </div>
      </div>

      {/* New user registrations */}
      <div className={styles.row}>
        <div className={`${styles.chartCard} ${styles.wide}`}>
          <div className={styles.chartTitle}>New User Registrations (Last 6 Months)</div>
          <div className={styles.groupedLegend}>
            {[{key:'customers',label:'Customers',color:'#4f46e5'},{key:'sellers',label:'Sellers',color:'#059669'},{key:'drivers',label:'Drivers',color:'#d97706'}]
              .map(g => (
                <span key={g.key} className={styles.legendItem}>
                  <span className={styles.legendDot} style={{ background: g.color }} />
                  {g.label}
                </span>
              ))}
          </div>
          <GroupedBarCSS
            data={monthlyUsers}
            groups={[
              { key: 'customers', label: 'Customers', color: '#4f46e5' },
              { key: 'sellers',   label: 'Sellers',   color: '#059669' },
              { key: 'drivers',   label: 'Drivers',   color: '#d97706' },
            ]}
          />
        </div>
      </div>

      {/* Top products + Top drivers */}
      <div className={styles.row}>
        <div className={styles.chartCard}>
          <div className={styles.chartTitle}>Top Products by Quantity Ordered</div>
          <HorizontalBarCSS data={topProducts} dataKey="qty" labelKey="name" color="#7c3aed" />
        </div>
        <div className={styles.chartCard}>
          <div className={styles.chartTitle}>Top Drivers by Deliveries</div>
          {topDrivers.length === 0 ? (
            <div className={styles.emptyChart}>
              <Truck size={40} color="#e5e7eb" />
              <p className={styles.empty}>No delivery data yet</p>
            </div>
          ) : (
            <div className={styles.driverTable}>
              <div className={styles.driverHeader}>
                <span>Driver</span><span>Deliveries</span><span>Earned</span>
              </div>
              {topDrivers.map(([name, d], i) => (
                <div key={name} className={styles.driverRow}>
                  <span className={styles.driverRank}>
                    <span className={styles.rankBadge} style={{
                      background: i===0?'#f59e0b':i===1?'#94a3b8':i===2?'#b45309':'#e5e7eb',
                      color: i < 3 ? 'white' : '#374151',
                    }}>{i+1}</span>
                    {name}
                  </span>
                  <span className={styles.driverDeliveries}>{d.deliveries}</span>
                  <span className={styles.driverEarned}>TShs {fmt(d.earned)}</span>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Products stock */}
      <div className={styles.row}>
        <div className={`${styles.chartCard} ${styles.wide}`}>
          <div className={styles.chartTitle}>
            <Package size={15} style={{ marginRight: 6 }} /> Products Stock Summary
          </div>
          {products.length === 0 ? (
            <div className={styles.emptyChart}>
              <Package size={40} color="#e5e7eb" />
              <p className={styles.empty}>No products yet</p>
            </div>
          ) : (
            <div className={styles.stockGrid}>
              {products.slice(0, 12).map(p => {
                const pct   = Math.min(100, ((p.stock||0) / Math.max(p.stock||1, 50)) * 100);
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
          )}
        </div>
      </div>
    </div>
  );
}
