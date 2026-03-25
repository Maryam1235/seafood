import { signOut } from 'firebase/auth';
import { auth } from '../firebase';
import { useEffect, useState } from 'react';
import { doc, getDoc } from 'firebase/firestore';
import { db } from '../firebase';
import styles from './Sidebar.module.css';

const navItems = [
  { id: 'overview', label: 'Dashboard', icon: '📊' },
  { id: 'users', label: 'Users', icon: '👥' },
  { id: 'settings', label: 'Settings', icon: '⚙️' },
];

export default function Sidebar({ activePage, setActivePage, collapsed }) {
  const [username, setUsername] = useState('');

  useEffect(() => {
    const fetchUser = async () => {
      const user = auth.currentUser;
      if (user) {
        const snap = await getDoc(doc(db, 'users', user.uid));
        if (snap.exists()) {
          setUsername(snap.data().username || user.email);
        } else {
          setUsername(user.email);
        }
      }
    };
    fetchUser();
  }, []);

  return (
    <aside className={`${styles.sidebar} ${collapsed ? styles.collapsed : ''}`}>
      {!collapsed && (
        <>
          <div className={styles.brand}>
            <img src="/zanseafoodlogo.png" alt="ZanSeaFood" className={styles.brandLogo} />
            <div>
              <div className={styles.brandName}>ZanSeaFood</div>
              <div className={styles.brandSub}>Admin Panel</div>
            </div>
          </div>

          <div className={styles.adminInfo}>
            <div className={styles.adminAvatar}>
              {username ? username.charAt(0).toUpperCase() : 'A'}
            </div>
            <div>
              <div className={styles.adminName}>{username || 'Admin'}</div>
              <div className={styles.adminRole}>Administrator</div>
            </div>
          </div>
        </>
      )}

      <nav className={styles.nav}>
        {navItems.map((item) => (
          <button
            key={item.id}
            className={`${styles.navItem} ${activePage === item.id ? styles.active : ''}`}
            onClick={() => setActivePage(item.id)}
            title={collapsed ? item.label : ''}
          >
            <span className={styles.icon}>{item.icon}</span>
            {!collapsed && <span>{item.label}</span>}
          </button>
        ))}
      </nav>

      <button className={styles.logout} onClick={() => signOut(auth)} title={collapsed ? 'Logout' : ''}>
        <span>🚪</span>
        {!collapsed && <span>Logout</span>}
      </button>
    </aside>
  );
}
