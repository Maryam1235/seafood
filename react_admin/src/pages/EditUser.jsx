import { useState } from 'react';
import { doc, updateDoc } from 'firebase/firestore';
import { db } from '../firebase';
import styles from './UserForm.module.css';

export default function EditUser({ user, onBack }) {
  const [form, setForm] = useState({
    fullName: user.fullName || '',
    username: user.username || '',
    phone: user.phone || '',
    role: user.role || 'customer',
  });
  const [loading, setLoading] = useState(false);
  const [error, setError]     = useState('');
  const [success, setSuccess] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      await updateDoc(doc(db, 'users', user.id), form);
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
        <h2>Edit User</h2>
        <button className={styles.backBtn} onClick={onBack}>← Back</button>
      </div>

      <div className={styles.card}>
        {success && <div className={styles.success}>User updated successfully! Redirecting...</div>}
        {error && <div className={styles.error}>{error}</div>}

        <div className={styles.readonlyInfo}>
          <div className={styles.infoItem}>
            <span className={styles.infoLabel}>Email</span>
            <span className={styles.infoValue}>{user.email}</span>
          </div>
          <div className={styles.infoItem}>
            <span className={styles.infoLabel}>User ID</span>
            <span className={styles.infoValue}>{user.id}</span>
          </div>
        </div>

        <form onSubmit={handleSubmit}>
          <div className={styles.section}>
            <h3 className={styles.sectionTitle}>Personal Information</h3>
            <div className={styles.grid}>
              <div className={styles.field}>
                <label>Full Name</label>
                <input required placeholder="Full name"
                  value={form.fullName} onChange={e => setForm({...form, fullName: e.target.value})} />
              </div>
              <div className={styles.field}>
                <label>Username</label>
                <input required placeholder="Username"
                  value={form.username} onChange={e => setForm({...form, username: e.target.value})} />
              </div>
              <div className={styles.field}>
                <label>Phone Number</label>
                <input required placeholder="Phone number"
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

          <div className={styles.formFooter}>
            <button type="button" className={styles.cancelBtn} onClick={onBack}>Cancel</button>
            <button type="submit" className={styles.submitBtn} disabled={loading}>
              {loading ? 'Saving...' : 'Save Changes'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
