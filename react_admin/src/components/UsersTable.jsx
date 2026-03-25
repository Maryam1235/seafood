import { useEffect, useState } from 'react';
import { collection, onSnapshot, doc, deleteDoc, updateDoc } from 'firebase/firestore';
import { db } from '../firebase';
import styles from './UsersTable.module.css';

const roleBadge = { customer: '#dbeafe', seller: '#fef3c7', driver: '#d1fae5' };
const roleColor  = { customer: '#1d4ed8', seller: '#b45309', driver: '#065f46' };

export default function UsersTable({ onAddUser, onEditUser }) {
  const [users, setUsers]           = useState([]);
  const [search, setSearch]         = useState('');
  const [roleFilter, setRoleFilter] = useState('all');
  const [viewUser, setViewUser]     = useState(null);

  useEffect(() => {
    const unsub = onSnapshot(collection(db, 'users'), (snap) => {
      setUsers(snap.docs.map(d => ({ id: d.id, ...d.data() })));
    });
    return unsub;
  }, []);

  const toggleStatus = async (id, currentStatus) => {
    await updateDoc(doc(db, 'users', id), {
      active: currentStatus === false ? true : false,
    });
  };

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
      <div className={styles.header}>
        <h2 className={styles.title}>User Management</h2>
        <button className={styles.addBtn} onClick={onAddUser}>+ Add User</button>
      </div>

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
              <th>Role</th>
              <th>Status</th>
              <th>Created</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {filtered.length === 0 ? (
              <tr><td colSpan={5} className={styles.empty}>No users found</td></tr>
            ) : filtered.map(u => (
              <tr key={u.id}>
                <td>{u.fullName || 'N/A'}</td>
                <td>
                  <span className={styles.badge} style={{
                    background: roleBadge[u.role] || '#f3f4f6',
                    color: roleColor[u.role] || '#374151',
                  }}>
                    {(u.role || 'N/A').toUpperCase()}
                  </span>
                </td>
                <td>
                  <button
                    className={`${styles.statusBtn} ${u.active === false ? styles.inactive : styles.active}`}
                    onClick={() => toggleStatus(u.id, u.active)}
                  >
                    {u.active === false ? 'Inactive' : 'Active'}
                  </button>
                </td>
                <td>{u.createdAt?.seconds
                  ? new Date(u.createdAt.seconds * 1000).toLocaleDateString()
                  : u.createdAt ? new Date(u.createdAt).toLocaleDateString() : 'N/A'}
                </td>
                <td>
                  <div className={styles.actions}>
                    <button className={styles.viewBtn} onClick={() => setViewUser(u)} title="View">
                      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                        <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/>
                        <circle cx="12" cy="12" r="3"/>
                      </svg>
                    </button>
                    <button className={styles.editBtn} onClick={() => onEditUser(u)} title="Edit">✏️</button>
                    <button className={styles.deleteBtn} onClick={() => handleDelete(u.id)} title="Delete">🗑</button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* View User Modal - kept as modal since it's read-only */}
      {viewUser && (
        <div className={styles.overlay} onClick={() => setViewUser(null)}>
          <div className={styles.modal} onClick={e => e.stopPropagation()}>
            <div className={styles.modalHeader}>
              <h3>User Details</h3>
              <button className={styles.closeBtn} onClick={() => setViewUser(null)}>✕</button>
            </div>
            <div className={styles.viewGrid}>
              {[
                ['Full Name', viewUser.fullName],
                ['Username', viewUser.username],
                ['Email', viewUser.email],
                ['Phone', viewUser.phone],
                ['Role', viewUser.role?.toUpperCase()],
                ['Status', viewUser.active === false ? 'Inactive' : 'Active'],
                ['Created', viewUser.createdAt?.seconds
                  ? new Date(viewUser.createdAt.seconds * 1000).toLocaleDateString()
                  : 'N/A'],
              ].map(([label, value]) => (
                <div key={label} className={styles.viewRow}>
                  <span className={styles.viewLabel}>{label}</span>
                  <span className={styles.viewValue}>{value || 'N/A'}</span>
                </div>
              ))}
            </div>
            <div className={styles.modalFooter}>
              <button className={styles.cancelBtn} onClick={() => setViewUser(null)}>Close</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
