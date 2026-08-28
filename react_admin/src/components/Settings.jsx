import { useEffect, useState } from 'react';
import {
  updatePassword, updateEmail, EmailAuthProvider,
  reauthenticateWithCredential,
} from 'firebase/auth';
import {
  doc, getDoc, updateDoc, collection, onSnapshot,
  query, where, getDocs, writeBatch, setDoc,
} from 'firebase/firestore';
import { auth, db } from '../firebase';
import {
  User, Lock, Bell, Shield, Sliders, Info,
  Save, Eye, EyeOff, Check, AlertCircle, RefreshCw,
} from 'lucide-react';
import styles from './Settings.module.css';

// ── Small helpers ─────────────────────────────────────────────────────────────
function Section({ title, subtitle, icon: Icon, children }) {
  return (
    <div className={styles.section}>
      <div className={styles.sectionHeader}>
        <div className={styles.sectionIcon}><Icon size={18} /></div>
        <div>
          <div className={styles.sectionTitle}>{title}</div>
          {subtitle && <div className={styles.sectionSub}>{subtitle}</div>}
        </div>
      </div>
      <div className={styles.card}>{children}</div>
    </div>
  );
}

function Field({ label, sub, children }) {
  return (
    <div className={styles.field}>
      <div className={styles.fieldMeta}>
        <div className={styles.fieldLabel}>{label}</div>
        {sub && <div className={styles.fieldSub}>{sub}</div>}
      </div>
      <div className={styles.fieldControl}>{children}</div>
    </div>
  );
}

function Toast({ msg, type }) {
  if (!msg) return null;
  return (
    <div className={`${styles.toast} ${styles[type]}`}>
      {type === 'success' ? <Check size={14} /> : <AlertCircle size={14} />}
      {msg}
    </div>
  );
}

// ── Main component ─────────────────────────────────────────────────────────────
export default function Settings() {
  const user = auth.currentUser;

  // ── 1. Profile ───────────────────────────────────────────────────────────
  const [profile,     setProfile]     = useState({ fullName: '', username: '', phone: '' });
  const [profileSave, setProfileSave] = useState({ loading: false, msg: '', type: '' });

  // ── 2. Email ─────────────────────────────────────────────────────────────
  const [emailForm,   setEmailForm]   = useState({ newEmail: '', currentPw: '' });
  const [emailSave,   setEmailSave]   = useState({ loading: false, msg: '', type: '' });

  // ── 3. Password ──────────────────────────────────────────────────────────
  const [pwForm,      setPwForm]      = useState({ currentPw: '', newPw: '', confirmPw: '' });
  const [pwSave,      setPwSave]      = useState({ loading: false, msg: '', type: '' });
  const [showPw,      setShowPw]      = useState({ cur: false, new: false, con: false });

  // ── 4. Notifications ─────────────────────────────────────────────────────
  const [notifPrefs,  setNotifPrefs]  = useState({
    newOrders: true, complaints: true, lowStock: true,
    deliveries: true, payments: true,
  });
  const [notifSave,   setNotifSave]   = useState({ loading: false, msg: '', type: '' });

  // ── 5. Platform settings ─────────────────────────────────────────────────
  const [platform,    setPlatform]    = useState({
    lowStockThreshold: 5,
    maxOrderCancelMinutes: 30,
    deliveryBaseRate: 30,
    minDeliveryCost: 150,
    maintenanceMode: false,
  });
  const [platformSave, setPlatformSave] = useState({ loading: false, msg: '', type: '' });

  // ── 6. Danger zone ───────────────────────────────────────────────────────
  const [dangerLoading, setDangerLoading] = useState(false);
  const [dangerMsg,     setDangerMsg]     = useState('');

  // ── Stats for info section ───────────────────────────────────────────────
  const [stats, setStats] = useState({ users: 0, orders: 0, products: 0, complaints: 0 });

  // ── Load data on mount ───────────────────────────────────────────────────
  useEffect(() => {
    if (!user) return;

    // Admin profile
    getDoc(doc(db, 'users', user.uid)).then(snap => {
      if (snap.exists()) {
        const d = snap.data();
        setProfile({
          fullName: d.fullName || '',
          username: d.username || '',
          phone:    d.phone    || '',
        });
      }
    });

    // Notification preferences
    getDoc(doc(db, 'admin_settings', 'notifications')).then(snap => {
      if (snap.exists()) setNotifPrefs(p => ({ ...p, ...snap.data() }));
    });

    // Platform settings
    getDoc(doc(db, 'admin_settings', 'platform')).then(snap => {
      if (snap.exists()) setPlatform(p => ({ ...p, ...snap.data() }));
    });

    // Live stats
    const u1 = onSnapshot(collection(db, 'users'),      s => setStats(p => ({ ...p, users:      s.size })));
    const u2 = onSnapshot(collection(db, 'orders'),     s => setStats(p => ({ ...p, orders:     s.size })));
    const u3 = onSnapshot(collection(db, 'products'),   s => setStats(p => ({ ...p, products:   s.size })));
    const u4 = onSnapshot(collection(db, 'complaints'), s => setStats(p => ({ ...p, complaints: s.size })));
    return () => { u1(); u2(); u3(); u4(); };
  }, [user]);

  // ── Save handlers ────────────────────────────────────────────────────────

  const saveProfile = async () => {
    setProfileSave({ loading: true, msg: '', type: '' });
    try {
      await updateDoc(doc(db, 'users', user.uid), {
        fullName: profile.fullName.trim(),
        username: profile.username.trim(),
        phone:    profile.phone.trim(),
      });
      setProfileSave({ loading: false, msg: 'Profile updated successfully.', type: 'success' });
    } catch (e) {
      setProfileSave({ loading: false, msg: `Error: ${e.message}`, type: 'error' });
    }
  };

  const saveEmail = async () => {
    if (!emailForm.newEmail.trim() || !emailForm.currentPw) {
      setEmailSave({ loading: false, msg: 'Please fill in both fields.', type: 'error' }); return;
    }
    setEmailSave({ loading: true, msg: '', type: '' });
    try {
      const cred = EmailAuthProvider.credential(user.email, emailForm.currentPw);
      await reauthenticateWithCredential(user, cred);
      await updateEmail(user, emailForm.newEmail.trim());
      setEmailSave({ loading: false, msg: 'Email updated. Please verify your new email.', type: 'success' });
      setEmailForm({ newEmail: '', currentPw: '' });
    } catch (e) {
      const msg = e.code === 'auth/wrong-password' ? 'Current password is incorrect.'
        : e.code === 'auth/invalid-email' ? 'Invalid email address.'
        : `Error: ${e.message}`;
      setEmailSave({ loading: false, msg, type: 'error' });
    }
  };

  const savePassword = async () => {
    if (!pwForm.currentPw || !pwForm.newPw || !pwForm.confirmPw) {
      setPwSave({ loading: false, msg: 'Please fill in all fields.', type: 'error' }); return;
    }
    if (pwForm.newPw !== pwForm.confirmPw) {
      setPwSave({ loading: false, msg: 'New passwords do not match.', type: 'error' }); return;
    }
    if (pwForm.newPw.length < 6) {
      setPwSave({ loading: false, msg: 'Password must be at least 6 characters.', type: 'error' }); return;
    }
    setPwSave({ loading: true, msg: '', type: '' });
    try {
      const cred = EmailAuthProvider.credential(user.email, pwForm.currentPw);
      await reauthenticateWithCredential(user, cred);
      await updatePassword(user, pwForm.newPw);
      setPwSave({ loading: false, msg: 'Password changed successfully.', type: 'success' });
      setPwForm({ currentPw: '', newPw: '', confirmPw: '' });
    } catch (e) {
      const msg = e.code === 'auth/wrong-password' ? 'Current password is incorrect.' : `Error: ${e.message}`;
      setPwSave({ loading: false, msg, type: 'error' });
    }
  };

  const saveNotifPrefs = async () => {
    setNotifSave({ loading: true, msg: '', type: '' });
    try {
      await setDoc(doc(db, 'admin_settings', 'notifications'), notifPrefs);
      setNotifSave({ loading: false, msg: 'Notification preferences saved.', type: 'success' });
    } catch (e) {
      setNotifSave({ loading: false, msg: `Error: ${e.message}`, type: 'error' });
    }
  };

  const savePlatform = async () => {
    setPlatformSave({ loading: true, msg: '', type: '' });
    try {
      await setDoc(doc(db, 'admin_settings', 'platform'), platform);
      setPlatformSave({ loading: false, msg: 'Platform settings saved.', type: 'success' });
    } catch (e) {
      setPlatformSave({ loading: false, msg: `Error: ${e.message}`, type: 'error' });
    }
  };

  const clearReadNotifications = async () => {
    setDangerLoading(true);
    setDangerMsg('');
    try {
      const snap = await getDocs(
        query(collection(db, 'notifications'), where('read', '==', true))
      );
      const batch = writeBatch(db);
      snap.docs.forEach(d => batch.delete(d.ref));
      await batch.commit();
      setDangerMsg(`✅ Deleted ${snap.size} read notification(s).`);
    } catch (e) {
      setDangerMsg(`❌ Error: ${e.message}`);
    } finally {
      setDangerLoading(false);
    }
  };

  const resolveAllComplaints = async () => {
    if (!window.confirm('Mark ALL open complaints as resolved? This cannot be undone.')) return;
    setDangerLoading(true);
    setDangerMsg('');
    try {
      const snap = await getDocs(
        query(collection(db, 'complaints'), where('status', '==', 'open'))
      );
      const batch = writeBatch(db);
      snap.docs.forEach(d => batch.update(d.ref, { status: 'resolved', resolvedAt: new Date() }));
      await batch.commit();
      setDangerMsg(`✅ Resolved ${snap.size} complaint(s).`);
    } catch (e) {
      setDangerMsg(`❌ Error: ${e.message}`);
    } finally {
      setDangerLoading(false);
    }
  };

  // ── Toggle helper for notifications ─────────────────────────────────────
  const Toggle = ({ value, onChange }) => (
    <button
      onClick={() => onChange(!value)}
      className={`${styles.toggle} ${value ? styles.toggleOn : styles.toggleOff}`}
    >
      <span className={styles.toggleThumb} />
    </button>
  );

  // ── Password field helper ────────────────────────────────────────────────
  const PwField = ({ label, field, showKey }) => (
    <div className={styles.pwWrap}>
      <input
        type={showPw[showKey] ? 'text' : 'password'}
        className={styles.input}
        placeholder={label}
        value={pwForm[field]}
        onChange={e => setPwForm(p => ({ ...p, [field]: e.target.value }))}
      />
      <button
        type="button"
        className={styles.eyeBtn}
        onClick={() => setShowPw(p => ({ ...p, [showKey]: !p[showKey] }))}
      >
        {showPw[showKey] ? <EyeOff size={15} /> : <Eye size={15} />}
      </button>
    </div>
  );

  // ── Render ───────────────────────────────────────────────────────────────
  return (
    <div className={styles.wrap}>
      <div className={styles.pageHeader}>
        <h2 className={styles.pageTitle}>Settings</h2>
        <p className={styles.pageSub}>Manage your admin account and platform configuration</p>
      </div>

      <div className={styles.layout}>
        {/* ── LEFT column ─────────────────────────────────────────────── */}
        <div className={styles.col}>

          {/* 1. Profile */}
          <Section title="Admin Profile" subtitle="Update your name and contact details" icon={User}>
            <Field label="Full Name" sub="Displayed in the admin panel header">
              <input className={styles.input} value={profile.fullName}
                onChange={e => setProfile(p => ({ ...p, fullName: e.target.value }))}
                placeholder="Full name" />
            </Field>
            <Field label="Username">
              <input className={styles.input} value={profile.username}
                onChange={e => setProfile(p => ({ ...p, username: e.target.value }))}
                placeholder="Username" />
            </Field>
            <Field label="Phone">
              <input className={styles.input} value={profile.phone}
                onChange={e => setProfile(p => ({ ...p, phone: e.target.value }))}
                placeholder="+255..." />
            </Field>
            <Field label="Email (read-only)" sub="Change email in the section below">
              <input className={styles.input} value={user?.email || ''} disabled
                style={{ background: '#f9fafb', color: '#9ca3af' }} />
            </Field>
            <div className={styles.fieldActions}>
              <Toast msg={profileSave.msg} type={profileSave.type} />
              <button className={styles.saveBtn} onClick={saveProfile} disabled={profileSave.loading}>
                {profileSave.loading ? <RefreshCw size={14} className={styles.spin} /> : <Save size={14} />}
                {profileSave.loading ? 'Saving…' : 'Save Profile'}
              </button>
            </div>
          </Section>

          {/* 2. Change Email */}
          <Section title="Change Email" subtitle="Re-authentication required" icon={Shield}>
            <Field label="New Email Address">
              <input className={styles.input} type="email"
                value={emailForm.newEmail}
                onChange={e => setEmailForm(p => ({ ...p, newEmail: e.target.value }))}
                placeholder="new@email.com" />
            </Field>
            <Field label="Current Password" sub="Required to confirm identity">
              <input className={styles.input} type="password"
                value={emailForm.currentPw}
                onChange={e => setEmailForm(p => ({ ...p, currentPw: e.target.value }))}
                placeholder="Enter current password" />
            </Field>
            <div className={styles.fieldActions}>
              <Toast msg={emailSave.msg} type={emailSave.type} />
              <button className={styles.saveBtn} onClick={saveEmail} disabled={emailSave.loading}>
                {emailSave.loading ? <RefreshCw size={14} className={styles.spin} /> : <Save size={14} />}
                {emailSave.loading ? 'Updating…' : 'Update Email'}
              </button>
            </div>
          </Section>

          {/* 3. Password */}
          <Section title="Change Password" subtitle="Use a strong password of at least 6 characters" icon={Lock}>
            <Field label="Current Password">
              <PwField label="Current password" field="currentPw" showKey="cur" />
            </Field>
            <Field label="New Password">
              <PwField label="New password" field="newPw" showKey="new" />
            </Field>
            <Field label="Confirm New Password">
              <PwField label="Confirm password" field="confirmPw" showKey="con" />
            </Field>
            <div className={styles.fieldActions}>
              <Toast msg={pwSave.msg} type={pwSave.type} />
              <button className={styles.saveBtn} onClick={savePassword} disabled={pwSave.loading}>
                {pwSave.loading ? <RefreshCw size={14} className={styles.spin} /> : <Save size={14} />}
                {pwSave.loading ? 'Changing…' : 'Change Password'}
              </button>
            </div>
          </Section>
        </div>

        {/* ── RIGHT column ────────────────────────────────────────────── */}
        <div className={styles.col}>

          {/* 4. Notification preferences */}
          <Section title="Notification Preferences"
            subtitle="Choose which alerts appear on the admin dashboard"
            icon={Bell}>
            {[
              { key: 'newOrders',   label: 'New Orders',         sub: 'Alert when a new order is placed'              },
              { key: 'complaints',  label: 'New Complaints',      sub: 'Alert when a complaint is filed'               },
              { key: 'lowStock',    label: 'Low Stock Alerts',    sub: 'Alert when a product stock drops below threshold' },
              { key: 'deliveries',  label: 'Delivery Updates',    sub: 'Alert on driver assignment and delivery status' },
              { key: 'payments',    label: 'Payment Events',      sub: 'Alert on payment completions and failures'     },
            ].map(item => (
              <Field key={item.key} label={item.label} sub={item.sub}>
                <Toggle
                  value={notifPrefs[item.key]}
                  onChange={v => setNotifPrefs(p => ({ ...p, [item.key]: v }))}
                />
              </Field>
            ))}
            <div className={styles.fieldActions}>
              <Toast msg={notifSave.msg} type={notifSave.type} />
              <button className={styles.saveBtn} onClick={saveNotifPrefs} disabled={notifSave.loading}>
                {notifSave.loading ? <RefreshCw size={14} className={styles.spin} /> : <Save size={14} />}
                {notifSave.loading ? 'Saving…' : 'Save Preferences'}
              </button>
            </div>
          </Section>

          {/* 5. Platform configuration */}
          <Section title="Platform Configuration"
            subtitle="These values affect the Flutter app and Cloud Functions"
            icon={Sliders}>
            <Field label="Low Stock Threshold"
              sub="Sellers are alerted when stock drops to this value">
              <div className={styles.numWrap}>
                <input className={styles.inputNum} type="number" min={1} max={50}
                  value={platform.lowStockThreshold}
                  onChange={e => setPlatform(p => ({ ...p, lowStockThreshold: +e.target.value }))} />
                <span className={styles.numUnit}>units</span>
              </div>
            </Field>
            <Field label="Order Cancellation Window"
              sub="Customers can cancel up to this many minutes after placing">
              <div className={styles.numWrap}>
                <input className={styles.inputNum} type="number" min={0} max={120}
                  value={platform.maxOrderCancelMinutes}
                  onChange={e => setPlatform(p => ({ ...p, maxOrderCancelMinutes: +e.target.value }))} />
                <span className={styles.numUnit}>min</span>
              </div>
            </Field>
            <Field label="Delivery Base Rate"
              sub="TShs charged per km for delivery">
              <div className={styles.numWrap}>
                <input className={styles.inputNum} type="number" min={1}
                  value={platform.deliveryBaseRate}
                  onChange={e => setPlatform(p => ({ ...p, deliveryBaseRate: +e.target.value }))} />
                <span className={styles.numUnit}>TShs/km</span>
              </div>
            </Field>
            <Field label="Minimum Delivery Cost"
              sub="Lowest possible delivery charge regardless of distance">
              <div className={styles.numWrap}>
                <input className={styles.inputNum} type="number" min={0}
                  value={platform.minDeliveryCost}
                  onChange={e => setPlatform(p => ({ ...p, minDeliveryCost: +e.target.value }))} />
                <span className={styles.numUnit}>TShs</span>
              </div>
            </Field>
            <Field label="Maintenance Mode"
              sub="Shows a maintenance banner to all app users when on">
              <Toggle
                value={platform.maintenanceMode}
                onChange={v => setPlatform(p => ({ ...p, maintenanceMode: v }))}
              />
            </Field>
            <div className={styles.fieldActions}>
              <Toast msg={platformSave.msg} type={platformSave.type} />
              <button className={styles.saveBtn} onClick={savePlatform} disabled={platformSave.loading}>
                {platformSave.loading ? <RefreshCw size={14} className={styles.spin} /> : <Save size={14} />}
                {platformSave.loading ? 'Saving…' : 'Save Configuration'}
              </button>
            </div>
          </Section>

          {/* 6. System info */}
          <Section title="System Information" subtitle="Live platform statistics" icon={Info}>
            <div className={styles.statsGrid}>
              {[
                { label: 'Total Users',   value: stats.users,      color: '#4f46e5', bg: '#e0e7ff' },
                { label: 'Total Orders',  value: stats.orders,     color: '#0891b2', bg: '#e0f2fe' },
                { label: 'Products',      value: stats.products,   color: '#16a34a', bg: '#dcfce7' },
                { label: 'Complaints',    value: stats.complaints, color: '#dc2626', bg: '#fee2e2' },
              ].map(s => (
                <div key={s.label} className={styles.statChip} style={{ borderLeft: `3px solid ${s.color}`, background: s.bg }}>
                  <div className={styles.statChipVal} style={{ color: s.color }}>{s.value}</div>
                  <div className={styles.statChipLabel}>{s.label}</div>
                </div>
              ))}
            </div>
            <div className={styles.sysRows}>
              {[
                ['App Name',    'ZanSeaFood'],
                ['Version',     '1.0.0'],
                ['Platform',    'React + Firebase'],
                ['Admin Email', user?.email || 'N/A'],
                ['Admin UID',   user?.uid   || 'N/A'],
              ].map(([l, v]) => (
                <div key={l} className={styles.sysRow}>
                  <span className={styles.sysLabel}>{l}</span>
                  <span className={styles.sysVal}>{v}</span>
                </div>
              ))}
            </div>
          </Section>

          {/* 7. Danger zone */}
          <Section title="Maintenance Actions"
            subtitle="Irreversible bulk operations — use with caution"
            icon={AlertCircle}>
            <div className={styles.dangerZone}>
              <div className={styles.dangerItem}>
                <div>
                  <div className={styles.dangerLabel}>Clear Read Notifications</div>
                  <div className={styles.dangerSub}>
                    Permanently deletes all notifications that have been read.
                    Unread notifications are preserved.
                  </div>
                </div>
                <button
                  className={styles.dangerBtn}
                  onClick={clearReadNotifications}
                  disabled={dangerLoading}
                >
                  {dangerLoading ? <RefreshCw size={13} className={styles.spin} /> : null}
                  Clear Read
                </button>
              </div>
              <div className={styles.dangerItem}>
                <div>
                  <div className={styles.dangerLabel}>Resolve All Open Complaints</div>
                  <div className={styles.dangerSub}>
                    Marks every open complaint as resolved. Use only when
                    all complaints have been handled outside the system.
                  </div>
                </div>
                <button
                  className={`${styles.dangerBtn} ${styles.dangerBtnRed}`}
                  onClick={resolveAllComplaints}
                  disabled={dangerLoading}
                >
                  {dangerLoading ? <RefreshCw size={13} className={styles.spin} /> : null}
                  Resolve All
                </button>
              </div>
              {dangerMsg && (
                <div className={styles.dangerMsg}>{dangerMsg}</div>
              )}
            </div>
          </Section>

        </div>
      </div>
    </div>
  );
}
