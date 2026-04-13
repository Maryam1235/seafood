import { useEffect, useState } from 'react';
import { collection, onSnapshot } from 'firebase/firestore';
import { db } from '../firebase';
import { Users, ShoppingCart, Store, Truck, Fish, CheckCircle, ShoppingBag } from 'lucide-react';
import styles from './Overview.module.css';

export default function Overview() {
  const [stats, setStats] = useState({ total: 0, customers: 0, sellers: 0, drivers: 0 });
  const [productStats, setProductStats] = useState({ total: 0, active: 0 });
  const [orderStats, setOrderStats] = useState({ total: 0, pending: 0 });

  useEffect(() => {
    const unsub1 = onSnapshot(collection(db, 'users'), (snap) => {
      const users = snap.docs.map(d => d.data());
      setStats({
        total: users.length,
        customers: users.filter(u => u.role === 'customer').length,
        sellers: users.filter(u => u.role === 'seller').length,
        drivers: users.filter(u => u.role === 'driver').length,
      });
    });
    const unsub2 = onSnapshot(collection(db, 'products'), (snap) => {
      const products = snap.docs.map(d => d.data());
      setProductStats({ total: products.length, active: products.filter(p => p.isAvailable).length });
    });
    const unsub3 = onSnapshot(collection(db, 'orders'), (snap) => {
      const orders = snap.docs.map(d => d.data());
      setOrderStats({ total: orders.length, pending: orders.filter(o => o.status === 'pending').length });
    });
    return () => { unsub1(); unsub2(); unsub3(); };
  }, []);

  const cards = [
    { label: 'Total Users',      value: stats.total,          Icon: Users,        color: '#4f46e5' },
    { label: 'Customers',        value: stats.customers,      Icon: ShoppingCart, color: '#059669' },
    { label: 'Sellers',          value: stats.sellers,        Icon: Store,        color: '#d97706' },
    { label: 'Drivers',          value: stats.drivers,        Icon: Truck,        color: '#0891b2' },
    { label: 'Total Products',   value: productStats.total,   Icon: Fish,         color: '#7c3aed' },
    { label: 'Active Products',  value: productStats.active,  Icon: CheckCircle,  color: '#16a34a' },
    { label: 'Total Orders',     value: orderStats.total,     Icon: ShoppingBag,  color: '#dc2626' },
    { label: 'Pending Orders',   value: orderStats.pending,   Icon: ShoppingBag,  color: '#ea580c' },
  ];

  return (
    <div>
      <h2 className={styles.title}>Dashboard Overview</h2>
      <p className={styles.sub}>Welcome to ZanSeaFood Admin</p>
      <div className={styles.grid}>
        {cards.map((card) => (
          <div key={card.label} className={styles.card} style={{ borderTop: `4px solid ${card.color}` }}>
            <div className={styles.cardIcon} style={{ color: card.color }}><card.Icon size={36} /></div>
            <div className={styles.cardValue}>{card.value}</div>
            <div className={styles.cardLabel}>{card.label}</div>
          </div>
        ))}
      </div>
    </div>
  );
}
