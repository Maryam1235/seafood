import { signOut } from 'firebase/auth';
import { auth } from '../firebase';
import { useEffect, useState } from 'react';
import { doc, getDoc, collection, onSnapshot, query, where } from 'firebase/firestore';
import { db } from '../firebase';
import { LayoutDashboard, Users, Fish, ShoppingBag, Truck, Settings, LogOut, BarChart2, MessageSquareDot } from 'lucide-react';
import styles from './Sidebar.module.css';

const navItems = [
  { id: 'overview',    label: 'Dashboard',            icon: LayoutDashboard   },
  { id: 'users',       label: 'User Management',       icon: Users             },
  { id: 'products',    label: 'Products Management',   icon: Fish              },
  { id: 'orders',      label: 'Orders Management',     icon: ShoppingBag       },
  { id: 'delivery',    label: 'Delivery Management',   icon: Truck             },
  { id: 'complaints',  label: 'Complaints Management', icon: MessageSquareDot  },
  { id: 'reports',     label: 'Reports & Analytics',   icon: BarChart2         },
  { id: 'settings',    label: 'Settings',              icon: Settings          },
];

export default function Sidebar({ activePage, setActivePage, collapsed }) {
  const [username, setUsername]         = useState('');
  const [search, setSearch]             = useState('');
  const [openComplaints, setOpenComplaints] = useState(0);

  useEffect(() => {
    const fetchUser = async () => {
      const user = auth.currentUser;
      if (user) {
        const snap = await getDoc(doc(db, 'users', user.uid));
        setUsername(snap.exists() ? (snap.data().username || user.email) : user.email);
      }
    };
    fetchUser();

    // Live badge: count open complaints
    const unsub = onSnapshot(
      query(collection(db, 'complaints'), where('status', '==', 'open')),
      snap => setOpenComplaints(snap.size),
    );
    return unsub;
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

          <div className={styles.searchBox}>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/>
            </svg>
            <input
              type="text"
              placeholder="Search..."
              className={styles.searchInput}
              onChange={e => setSearch(e.target.value)}
            />
          </div>
        </>
      )}

      <nav className={styles.nav}>
        {navItems
          .filter(item => item.label.toLowerCase().includes(search.toLowerCase()))
          .map((item) => {
            const Icon = item.icon;
            return (
              <button
                key={item.id}
                className={`${styles.navItem} ${activePage === item.id ? styles.active : ''}`}
                onClick={() => setActivePage(item.id)}
                title={collapsed ? item.label : ''}
              >
                <Icon size={18} />
                {!collapsed && <span>{item.label}</span>}
                {/* Live badge for open complaints */}
                {item.id === 'complaints' && openComplaints > 0 && (
                  <span style={{
                    marginLeft: 'auto',
                    background: '#ef4444',
                    color: 'white',
                    fontSize: 10,
                    fontWeight: 700,
                    padding: '2px 6px',
                    borderRadius: 10,
                    lineHeight: 1,
                  }}>
                    {openComplaints > 99 ? '99+' : openComplaints}
                  </span>
                )}
              </button>
            );
          })}
      </nav>

      <button className={styles.logout} onClick={() => signOut(auth)} title={collapsed ? 'Logout' : ''}>
        <LogOut size={18} />
        {!collapsed && <span>Logout</span>}
      </button>
    </aside>
  );
}

