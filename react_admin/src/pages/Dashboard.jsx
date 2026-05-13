import { useState } from 'react';
import Sidebar from '../components/Sidebar';
import TopHeader from '../components/TopHeader';
import Overview from '../components/Overview';
import UsersTable from '../components/UsersTable';
import ProductsTable from '../components/ProductsTable';
import OrdersTable from '../components/OrdersTable';
import DeliveryManagement from '../components/DeliveryManagement';
import Reports from '../components/Reports';
import Settings from '../components/Settings';
import AddUser from './AddUser';
import EditUser from './EditUser';
import AddProduct from './AddProduct';
import EditProduct from './EditProduct';
import styles from './Dashboard.module.css';

export default function Dashboard() {
  const [activePage, setActivePage] = useState('overview');
  const [subPage, setSubPage]       = useState(null);
  const [collapsed, setCollapsed]   = useState(false);

  const handleNav = (page) => {
    setActivePage(page);
    setSubPage(null);
  };

  const renderContent = () => {
    if (subPage?.type === 'add') return <AddUser onBack={() => setSubPage(null)} />;
    if (subPage?.type === 'edit') return <EditUser user={subPage.user} onBack={() => setSubPage(null)} />;
    if (subPage?.type === 'addProduct') return <AddProduct onBack={() => setSubPage(null)} />;
    if (subPage?.type === 'editProduct') return <EditProduct product={subPage.product} onBack={() => setSubPage(null)} />;

    switch (activePage) {
      case 'overview': return <Overview />;
      case 'users':
        return <UsersTable
          onAddUser={() => setSubPage({ type: 'add' })}
          onEditUser={(user) => setSubPage({ type: 'edit', user })}
        />;
      case 'products': return <ProductsTable
        onAddProduct={() => setSubPage({ type: 'addProduct' })}
        onEditProduct={(product) => setSubPage({ type: 'editProduct', product })}
      />;
      case 'orders': return <OrdersTable />;
      case 'delivery': return <DeliveryManagement />;
      case 'reports': return <Reports />;
      case 'settings': return <Settings />;
      default: return <Overview />;
    }
  };

  return (
    <div className={styles.layout}>
      <Sidebar
        activePage={activePage}
        setActivePage={handleNav}
        collapsed={collapsed}
      />
      <div className={styles.content}>
        <TopHeader
          collapsed={collapsed}
          setCollapsed={setCollapsed}
          activePage={activePage}
        />
        <main className={styles.main}>
          {renderContent()}
        </main>
      </div>
    </div>
  );
}
