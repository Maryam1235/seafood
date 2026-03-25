import { signOut } from 'firebase/auth';
import { auth } from '../firebase';
import styles from './Sidebar.module.css';

const navItems = [
  { id: 'overview', label: 'Dashboard', icon: '📊' },
  { id: 'users', label: 'User Management', icon: '👥' },
  { id: 'settings', label: 'Settings', icon: '⚙️' },
];

export default function Sidebar({ activePage, setActivePage }) {
  return (
    <aside className={styles.sidebar}>
      <div className={styles.brand}>
        <img src="/zanseafoodlogo.png" alt="ZanSeaFood" className={styles.brandLogo} />
        <div>
          <div className={styles.brandName}>ZanSeaFood</div>
          <div className={styles.brandSub}>Admin Panel</div>
        </div>
      </div>

      <nav className={styles.nav}>
        {navItems.map((item) => (
          <button
            key={item.id}
            className={`${styles.navItem} ${activePage === item.id ? styles.active : ''}`}
            onClick={() => setActivePage(item.id)}
          >
            <span className={styles.icon}>{item.icon}</span>
            <span>{item.label}</span>
          </button>
        ))}
      </nav>

      <button className={styles.logout} onClick={() => signOut(auth)}>
        <span>🚪</span>
        <span>Logout</span>
      </button>
    </aside>
  );
}
