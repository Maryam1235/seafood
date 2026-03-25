import { useState } from 'react';
import Sidebar from '../components/Sidebar';
import Overview from '../components/Overview';
import UsersTable from '../components/UsersTable';
import Settings from '../components/Settings';
import styles from './Dashboard.module.css';

export default function Dashboard() {
  const [activePage, setActivePage] = useState('overview');

  const renderPage = () => {
    switch (activePage) {
      case 'overview': return <Overview />;
      case 'users': return <UsersTable />;
      case 'settings': return <Settings />;
      default: return <Overview />;
    }
  };

  return (
    <div className={styles.layout}>
      <Sidebar activePage={activePage} setActivePage={setActivePage} />
      <main className={styles.main}>
        {renderPage()}
      </main>
    </div>
  );
}
