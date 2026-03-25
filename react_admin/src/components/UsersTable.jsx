import { useEffect, useState } from 'react';
import { collection, onSnapshot, doc, deleteDoc } from 'firebase/firestore';
import { db } from '../firebase';
import styles from './UsersTable.module.css';

const roleBadge = { customer: '#dbeafe', seller: '#fef3c7', driver: '#d1fae5' };
const roleColor = { customer: '#1d4ed8', seller: '#b45309', driver: '#065f46' };

export default function UsersTable() {
  const [users, setUsers] = useState([]);
  const [search, setSearch] = useState('');
  const [roleFilter, setRoleFilter] = useState('all');

  useEffect(() => {
    const unsub = onSnapshot(collection(db, 'users'), (snap) => {
      setUsers(snap.docs.map(d => ({ id: d.id, ...d.data() })));
    });
    return unsub;
  }, []);

  const handleDelete = async (id) => {
    if (window.confirm('Are you sure you want to delete this user?')) {
      await deleteDoc(doc(db, 'users', id));
    }
  };

  const filtered = users.filter(u => {
    const matchRole = roleFilter === 'all' || u.role === roleFilter;
    const q = search.toLowerCase();
    const matchSearch = !q ||
      (u.fullName || '').toLowerCase().includes(q) ||
      (u.email || '').toLowerCase().includes(q) ||
      (u.phone || '').toLowerCase().includes(q) ||
      (u.username || '').toLowerCase().includes(q);
    return matchRole && matchSearch;
  });

  return (
    <div>
      <h2 className={styles.title}>User Management</h2>
      <div className={styles.toolbar}>
        <input
          className={styles.search}
          placeholder="Search by name, email, phone..."
          value={search}
          onChange={e => setSearch(e.target.value)}
        />
        <select className={styles.filter} value={roleFilter} onChange={e => setRoleFilter(e.target.value)}>
          <option value="all">All Roles</option>
          <option value="customer">Customers</option>
          <option value="seller">Sellers</option>
          <option value="driver">Drivers</option>
        </select>
      </div>

      <div className={styles.tableWrap}>
        <table className={styles.table}>
          <thead>
            <tr>
              <th>Full Name</th>
              <th>Username</th>
              <th>Email</th>
              <th>Phone</th>
              <th>Role</th>
              <th>Created</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {filtered.length === 0 ? (
              <tr><td colSpan={7} className={styles.empty}>No users found</td></tr>
            ) : filtered.map(u => (
              <tr key={u.id}>
                <td>{u.fullName || 'N/A'}</td>
                <td>{u.username || 'N/A'}</td>
                <td>{u.email || 'N/A'}</td>
                <td>{u.phone || 'N/A'}</td>
                <td>
                  <span className={styles.badge} style={{
                    background: roleBadge[u.role] || '#f3f4f6',
                    color: roleColor[u.role] || '#374151',
                  }}>
                    {(u.role || 'N/A').toUpperCase()}
                  </span>
                </td>
                <td>{u.createdAt ? new Date(u.createdAt.seconds * 1000).toLocaleDateString() : 'N/A'}</td>
                <td>
                  <button className={styles.deleteBtn} onClick={() => handleDelete(u.id)}>🗑 Delete</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
