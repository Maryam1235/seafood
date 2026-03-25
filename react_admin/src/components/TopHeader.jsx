import styles from './TopHeader.module.css';

const pageTitles = {
  overview: 'Dashboard',
  users: 'User Management',
  settings: 'Settings',
};

export default function TopHeader({ collapsed, setCollapsed, activePage }) {
  return (
    <header className={styles.header}>
      <div className={styles.left}>
        <button className={styles.toggleBtn} onClick={() => setCollapsed(!collapsed)}>
          <span></span>
          <span></span>
          <span></span>
        </button>
        <h1 className={styles.pageTitle}>{pageTitles[activePage] || 'Dashboard'}</h1>
      </div>
      <div className={styles.right}>
        <span className={styles.appName}>ZanSeaFood Admin</span>
      </div>
    </header>
  );
}
