import { useState } from 'react';
import Sidebar from '../components/Sidebar';
import Overview from '../components/Overview';
import UsersTable from '../components/UsersTable';
import Settings from '../components/Settings';
import AddUser from './AddUser';
import EditUser from './EditUser';
import styles from './Dashboard.module.css';

export default function Dashboard() {
  const [activePage, setActivePage] = useState('overview');
  const [subPage, setSubPage]       = useState(null); // { type: 'add' } | { type: 'edit', user }

  const handleNav = (page) => {
    setActivePage(page);
    setSubPage(null);
  };

  const renderContent = () => {
    if (subPage?.type === 'add') {
      return <AddUser onBack={() => setSubPage(null)} />;
    }
    if (subPage?.type === 'edit') {
      return <EditUser user={subPage.user} onBack={() => setSubPage(null)} />;
    }

    switch (activePage) {
      case 'overview': return <Overview />;
      case 'users':
        return <UsersTable
          onAddUser={() => setSubPage({ type: 'add' })}
          onEditUser={(user) => setSubPage({ type: 'edit', user })}
        />;
      case 'settings': return <Settings />;
      default: return <Overview />;
    }
  };

  return (
    <div className={styles.layout}>
      <Sidebar activePage={activePage} setActivePage={handleNav} />
      <main className={styles.main}>
        {renderContent()}
      </main>
    </div>
  );
}
