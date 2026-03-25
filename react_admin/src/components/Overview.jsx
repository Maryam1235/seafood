import { useEffect, useState } from 'react';
import { collection, onSnapshot } from 'firebase/firestore';
import { db } from '../firebase';
import styles from './Overview.module.css';

export default function Overview() {
  const [stats, setStats] = useState({ total: 0, customers: 0, sellers: 0, drivers: 0 });

  useEffect(() => {
    const unsub = onSnapshot(collection(db, 'users'), (snap) => {
      const users = snap.docs.map(d => d.data());
      setStats({
        total: users.length,
        customers: users.filter(u => u.role === 'customer').length,
        sellers: users.filter(u => u.role === 'seller').length,
        drivers: users.filter(u => u.role === 'driver').length,
      });
    });
    return unsub;
  }, []);

  const cards = [
    { label: 'Total Users', value: stats.total, icon: '👥', color: '#4f46e5' },
    { label: 'Customers', value: stats.customers, icon: '🛒', color: '#059669' },
    { label: 'Sellers', value: stats.sellers, icon: '🏪', color: '#d97706' },
    { label: 'Drivers', value: stats.drivers, icon: '🚗', color: '#0891b2' },
  ];

  return (
    <div>
      <h2 className={styles.title}>Dashboard Overview</h2>
      <p className={styles.sub}>Welcome to ZanSeaFood Admin</p>
      <div className={styles.grid}>
        {cards.map((card) => (
          <div key={card.label} className={styles.card} style={{ borderTop: `4px solid ${card.color}` }}>
            <div className={styles.cardIcon}>{card.icon}</div>
            <div className={styles.cardValue}>{card.value}</div>
            <div className={styles.cardLabel}>{card.label}</div>
          </div>
        ))}
      </div>
    </div>
  );
}
