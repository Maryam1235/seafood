import { useEffect, useState } from 'react';
import { collection, onSnapshot, doc, deleteDoc, setDoc } from 'firebase/firestore';
import { db } from '../firebase';
import { createUserWithEmailAndPassword } from 'firebase/auth';
import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import styles from './UsersTable.module.css';

// Secondary app to create users without logging out admin
const secondaryApp = initializeApp({
  apiKey: 'AIzaSyDYYGj-PNS-P4jcMp00BN3EXzYKqZ-WGws',
  authDomain: 'testing-bc269.firebaseapp.com',
  projectId: 'testing-bc269',
  storageBucket: 'testing-bc269.firebasestorage.app',
  messagingSenderId: '471821678431',
  appId: '1:471821678431:web:426ca40330b7c219c3e8ea',
}, 'secondary');
const secondaryAuth = getAuth(secondaryApp);

const roleBadge = { customer: '#dbeafe', seller: '#fef3c7', driver: '#d1fae5' };
const roleColor  = { customer: '#1d4ed8', seller: '#b45309', driver: '#065f46' };

const emptyForm = { fullName: '', username: '', email: '', phone: '', password: '', role: 'customer' };

export default function UsersTable() {
  const [users, setUsers]         = useState([]);
  const [search, setSearch]       = useState('');
  const [roleFilter, setRoleFilter] = useState('all');
  const [showModal, setShowModal] = useState(false);
  const [form, setForm]           = useState(emptyForm);
  const [loading, setLoading]     = useState(false);
  const [error, setError]         = useState('');

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

  const handleAddUser = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      const cred = await createUserWithEmailAndPassword(secondaryAuth, form.email, form.password);
      await setDoc(doc(db, 'users', cred.user.uid), {
        fullName: form.fullName,
        username: form.username,
        email: form.email,
        phone: form.phone,
        role: form.role,
        createdAt: new Date(),
      });
      await secondaryAuth.signOut();
      setShowModal(false);
      setForm(emptyForm);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
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
        <button className={styles.addBtn} onClick={() => setShowModal(true)}>+ Add User</button>
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
              <th>Full Name</th><th>Username</th><th>Email</th>
              <th>Phone</th><th>Role</th><th>Created</th><th>Actions</th>
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
                <td>{u.createdAt?.seconds
                  ? new Date(u.createdAt.seconds * 1000).toLocaleDateString()
                  : u.createdAt ? new Date(u.createdAt).toLocaleDateString() : 'N/A'}
                </td>
                <td>
                  <button className={styles.deleteBtn} onClick={() => handleDelete(u.id)}>🗑 Delete</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Add User Modal */}
      {showModal && (
        <div className={styles.overlay} onClick={() => setShowModal(false)}>
          <div className={styles.modal} onClick={e => e.stopPropagation()}>
            <div className={styles.modalHeader}>
              <h3>Add New User</h3>
              <button className={styles.closeBtn} onClick={() => setShowModal(false)}>✕</button>
            </div>
            <form onSubmit={handleAddUser}>
              {error && <div className={styles.error}>{error}</div>}
              <div className={styles.formGrid}>
                <div className={styles.field}>
                  <label>Full Name</label>
                  <input required value={form.fullName} onChange={e => setForm({...form, fullName: e.target.value})} placeholder="Full Name" />
                </div>
                <div className={styles.field}>
                  <label>Username</label>
                  <input required value={form.username} onChange={e => setForm({...form, username: e.target.value})} placeholder="Username" />
                </div>
                <div className={styles.field}>
                  <label>Email</label>
                  <input required type="email" value={form.email} onChange={e => setForm({...form, email: e.target.value})} placeholder="Email" />
                </div>
                <div className={styles.field}>
                  <label>Phone</label>
                  <input required value={form.phone} onChange={e => setForm({...form, phone: e.target.value})} placeholder="Phone" />
                </div>
                <div className={styles.field}>
                  <label>Password</label>
                  <input required type="password" value={form.password} onChange={e => setForm({...form, password: e.target.value})} placeholder="Password" />
                </div>
                <div className={styles.field}>
                  <label>Role</label>
                  <select value={form.role} onChange={e => setForm({...form, role: e.target.value})}>
                    <option value="customer">Customer</option>
                    <option value="seller">Seller</option>
                    <option value="driver">Driver</option>
                  </select>
                </div>
              </div>
              <div className={styles.modalFooter}>
                <button type="button" className={styles.cancelBtn} onClick={() => setShowModal(false)}>Cancel</button>
                <button type="submit" className={styles.submitBtn} disabled={loading}>
                  {loading ? 'Creating...' : 'Create User'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
