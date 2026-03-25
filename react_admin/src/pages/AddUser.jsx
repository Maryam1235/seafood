import { useState } from 'react';
import { setDoc, doc } from 'firebase/firestore';
import { db } from '../firebase';
import { createUserWithEmailAndPassword } from 'firebase/auth';
import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import styles from './UserForm.module.css';

const secondaryApp = initializeApp({
  apiKey: 'AIzaSyDYYGj-PNS-P4jcMp00BN3EXzYKqZ-WGws',
  authDomain: 'testing-bc269.firebaseapp.com',
  projectId: 'testing-bc269',
  storageBucket: 'testing-bc269.firebasestorage.app',
  messagingSenderId: '471821678431',
  appId: '1:471821678431:web:426ca40330b7c219c3e8ea',
}, 'secondary');
const secondaryAuth = getAuth(secondaryApp);

export default function AddUser({ onBack }) {
  const [form, setForm] = useState({
    fullName: '', username: '', email: '',
    phone: '', password: '', role: 'customer',
  });
  const [loading, setLoading] = useState(false);
  const [error, setError]     = useState('');
  const [success, setSuccess] = useState(false);

  const handleSubmit = async (e) => {
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
        active: true,
        createdAt: new Date(),
      });
      await secondaryAuth.signOut();
      setSuccess(true);
      setTimeout(() => onBack(), 1500);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className={styles.page}>
      <div className={styles.pageHeader}>
        <h2>Add New User</h2>
        <button className={styles.backBtn} onClick={onBack}>← Back</button>
      </div>

      <div className={styles.card}>
        {success && <div className={styles.success}>User created successfully! Redirecting...</div>}
        {error && <div className={styles.error}>{error}</div>}

        <form onSubmit={handleSubmit}>
          <div className={styles.section}>
            <h3 className={styles.sectionTitle}>Personal Information</h3>
            <div className={styles.grid}>
              <div className={styles.field}>
                <label>Full Name</label>
                <input required placeholder="Enter full name"
                  value={form.fullName} onChange={e => setForm({...form, fullName: e.target.value})} />
              </div>
              <div className={styles.field}>
                <label>Username</label>
                <input required placeholder="Enter username"
                  value={form.username} onChange={e => setForm({...form, username: e.target.value})} />
              </div>
              <div className={styles.field}>
                <label>Phone Number</label>
                <input required placeholder="Enter phone number"
                  value={form.phone} onChange={e => setForm({...form, phone: e.target.value})} />
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
          </div>

          <div className={styles.section}>
            <h3 className={styles.sectionTitle}>Account Credentials</h3>
            <div className={styles.grid}>
              <div className={styles.field}>
                <label>Email Address</label>
                <input required type="email" placeholder="Enter email"
                  value={form.email} onChange={e => setForm({...form, email: e.target.value})} />
              </div>
              <div className={styles.field}>
                <label>Password</label>
                <input required type="password" placeholder="Min 6 characters"
                  value={form.password} onChange={e => setForm({...form, password: e.target.value})} />
              </div>
            </div>
          </div>

          <div className={styles.formFooter}>
            <button type="button" className={styles.cancelBtn} onClick={onBack}>Cancel</button>
            <button type="submit" className={styles.submitBtn} disabled={loading}>
              {loading ? 'Creating...' : 'Create User'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
