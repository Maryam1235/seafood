import { Menu, X } from 'lucide-react';
import styles from './TopHeader.module.css';

const pageTitles = {
  overview: 'Dashboard',
  users: 'User Management',
  products: 'Product Management',
  orders: 'Order Management',
  settings: 'Settings',
};

export default function TopHeader({ collapsed, setCollapsed, activePage }) {
  return (
    <header className={styles.header}>
      <div className={styles.left}>
        <button className={styles.toggleBtn} onClick={() => setCollapsed(!collapsed)}>
          {collapsed ? <Menu size={20} /> : <X size={20} />}
        </button>
        <h1 className={styles.pageTitle}>{pageTitles[activePage] || 'Dashboard'}</h1>
      </div>
      <div className={styles.right}>
        <span className={styles.appName}>ZanSeaFood Admin</span>
      </div>
    </header>
  );
}
