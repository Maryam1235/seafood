import { auth } from '../firebase';
import styles from './Settings.module.css';

export default function Settings() {
  const user = auth.currentUser;

  return (
    <div>
      <h2 className={styles.title}>Settings</h2>
      <div className={styles.section}>
        <h3>Account Info</h3>
        <div className={styles.card}>
          <div className={styles.row}><span>Email</span><strong>{user?.email}</strong></div>
          <div className={styles.row}><span>User ID</span><strong>{user?.uid}</strong></div>
        </div>
      </div>
      <div className={styles.section}>
        <h3>Application</h3>
        <div className={styles.card}>
          <div className={styles.row}><span>App Name</span><strong>ZanSeaFood</strong></div>
          <div className={styles.row}><span>Version</span><strong>1.0.0</strong></div>
          <div className={styles.row}><span>Platform</span><strong>React + Firebase</strong></div>
        </div>
      </div>
    </div>
  );
}
