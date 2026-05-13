import { useEffect, useState } from 'react';
import { collection, onSnapshot, doc, updateDoc, deleteDoc } from 'firebase/firestore';
import { db } from '../firebase';
import { Eye, Pencil, Trash2 } from 'lucide-react';
import styles from './UsersTable.module.css';

const roleBadge = { customer: '#dbeafe', seller: '#fef3c7', driver: '#d1fae5' };
const roleColor  = { customer: '#1d4ed8', seller: '#b45309', driver: '#065f46' };

export default function UsersTable({ onAddUser, onEditUser }) {
  const [users, setUsers]           = useState([]);
  const [search, setSearch]         = useState('');
  const [roleFilter, setRoleFilter] = useState('all');
  const [sortBy, setSortBy]         = useState('createdAt');
  const [showDeleted, setShowDeleted] = useState(false);
  const [viewUser, setViewUser]     = useState(null);
  const [page, setPage]             = useState(1);
  const PAGE_SIZE = 10;

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
    if (showDeleted) {
      // Permanent delete — user is already soft-deleted, now remove the doc entirely
      if (window.confirm('Permanently delete this user? This cannot be undone.')) {
        await deleteDoc(doc(db, 'users', id));
      }
    } else {
      // Soft delete — mark as deleted so the Flutter app blocks them
      if (window.confirm('Delete this user? They will be immediately signed out and blocked from logging in.')) {
        await updateDoc(doc(db, 'users', id), {
          active: false,
          deleted: true,
          deletedAt: new Date().toISOString(),
        });
      }
    }
  };

  const filtered = users.filter(u => {
    const matchRole = roleFilter === 'all' || u.role === roleFilter;
    const matchDeleted = showDeleted ? u.deleted === true : u.deleted !== true;
    const q = search.toLowerCase();
    const matchSearch = !q ||
      (u.fullName || '').toLowerCase().includes(q) ||
      (u.email || '').toLowerCase().includes(q) ||
      (u.phone || '').toLowerCase().includes(q) ||
      (u.username || '').toLowerCase().includes(q);
    return matchRole && matchDeleted && matchSearch;
  }).sort((a, b) => {
    if (sortBy === 'fullName') return (a.fullName || '').localeCompare(b.fullName || '');
    if (sortBy === 'role') return (a.role || '').localeCompare(b.role || '');
    if (sortBy === 'active') return (b.active === false ? -1 : 1) - (a.active === false ? -1 : 1);
    const aTime = a.createdAt?.seconds || 0;
    const bTime = b.createdAt?.seconds || 0;
    return bTime - aTime;
  });

  const totalPages = Math.ceil(filtered.length / PAGE_SIZE);
  const paginated = filtered.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);

  // Reset to page 1 when filters change
  const handleSearch = (val) => { setSearch(val); setPage(1); };
  const handleRole = (val) => { setRoleFilter(val); setPage(1); };
  const handleSort = (val) => { setSortBy(val); setPage(1); };

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
          onChange={e => handleSearch(e.target.value)}
        />
        <select className={styles.filter} value={roleFilter} onChange={e => handleRole(e.target.value)}>
          <option value="all">All Roles</option>
          <option value="customer">Customers</option>
          <option value="seller">Sellers</option>
          <option value="driver">Drivers</option>
        </select>
        <select className={styles.filter} value={sortBy} onChange={e => handleSort(e.target.value)}>
          <option value="createdAt">Sort by Date</option>
          <option value="fullName">Sort by Name</option>
          <option value="role">Sort by Role</option>
          <option value="active">Sort by Status</option>
        </select>
        <button
          className={styles.filter}
          onClick={() => { setShowDeleted(v => !v); setPage(1); }}
          style={{ background: showDeleted ? '#fee2e2' : 'white', color: showDeleted ? '#dc2626' : '#374151', cursor: 'pointer', whiteSpace: 'nowrap', flexShrink: 0, flexGrow: 0 }}
        >
          {showDeleted ? '🗑 Deleted' : 'Active'}
        </button>
      </div>

      <div className={styles.tableWrap}>
        <table className={styles.table}>
          <thead>
            <tr>
              <th>Full Name</th>
              <th>Role</th>
              <th>Status</th>
              <th>Location</th>
              <th>Created</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {paginated.length === 0 ? (
              <tr><td colSpan={6} className={styles.empty}>No users found</td></tr>
            ) : paginated.map(u => (
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
                <td>
                  {u.location
                    ? <span className={styles.location}>
                        📍 {u.location.name || `${u.location.latitude?.toFixed(4)}, ${u.location.longitude?.toFixed(4)}`}
                      </span>
                    : <span className={styles.noLocation}>No location</span>
                  }
                </td>
                <td>{u.createdAt?.seconds
                  ? new Date(u.createdAt.seconds * 1000).toLocaleDateString()
                  : u.createdAt ? new Date(u.createdAt).toLocaleDateString() : 'N/A'}
                </td>
                <td>
                  <div className={styles.actions}>
                    <button className={styles.viewBtn} onClick={() => setViewUser(u)} title="View">
                      <Eye size={16} />
                    </button>
                    <button className={styles.editBtn} onClick={() => onEditUser(u)} title="Edit">
                      <Pencil size={16} />
                    </button>
                    <button className={styles.deleteBtn} onClick={() => handleDelete(u.id)} title={showDeleted ? 'Permanently Delete' : 'Delete'}
                      style={showDeleted ? { background: '#dc2626', color: 'white', borderRadius: '6px', padding: '4px 8px' } : {}}>
                      <Trash2 size={14} />
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {totalPages > 1 && (
        <div className={styles.pagination}>
          <button
            className={styles.pageBtn}
            onClick={() => setPage(p => Math.max(1, p - 1))}
            disabled={page === 1}
          >
            ← Previous
          </button>
          <span className={styles.pageInfo}>
            Page {page} of {totalPages} ({filtered.length} users)
          </span>
          <button
            className={styles.pageBtn}
            onClick={() => setPage(p => Math.min(totalPages, p + 1))}
            disabled={page === totalPages}
          >
            Next →
          </button>
        </div>
      )}

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
                ['Location', viewUser.location?.name ||
                  (viewUser.location ? `${viewUser.location.latitude?.toFixed(5)}, ${viewUser.location.longitude?.toFixed(5)}` : 'Not available')],
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

            {/* Driver Profile Section */}
            {viewUser.role === 'driver' && (
              <div className={styles.driverSection}>
                <div className={styles.driverSectionTitle}>
                  🚗 Driver Profile
                  {viewUser.driverProfile && (
                    <span className={`${styles.driverStatus} ${
                      viewUser.driverProfile.status === 'approved' ? styles.approved :
                      viewUser.driverProfile.status === 'rejected' ? styles.rejected : styles.pending
                    }`}>
                      {viewUser.driverProfile.status?.toUpperCase() || 'PENDING'}
                    </span>
                  )}
                </div>

                {!viewUser.driverProfile ? (
                  <p className={styles.noProfile}>Driver has not submitted profile yet.</p>
                ) : (
                  <>
                    {[
                      ['Date of Birth', viewUser.driverProfile.dateOfBirth],
                      ['National ID', viewUser.driverProfile.nationalId],
                      ['License Number', viewUser.driverProfile.licenseNumber],
                      ['Vehicle Type', viewUser.driverProfile.vehicleType],
                      ['License Plate', viewUser.driverProfile.licensePlate],
                      ['Emergency Contact', viewUser.driverProfile.emergencyContact],
                    ].map(([label, value]) => (
                      <div key={label} className={styles.viewRow}>
                        <span className={styles.viewLabel}>{label}</span>
                        <span className={styles.viewValue}>{value || 'N/A'}</span>
                      </div>
                    ))}

                    {/* Document images */}
                    <div className={styles.docsTitle}>Documents</div>
                    <div className={styles.docsGrid}>
                      {[
                        ['National ID', viewUser.driverProfile.idCardUrl],
                        ['Driver License', viewUser.driverProfile.licenseUrl],
                        ['DC Letter', viewUser.driverProfile.dcLetterUrl],
                      ].map(([label, url]) => (
                        <div key={label} className={styles.docItem}>
                          <div className={styles.docLabel}>{label}</div>
                          {url
                            ? <a href={url} target="_blank" rel="noreferrer">
                                <img src={url} alt={label} className={styles.docImg} />
                              </a>
                            : <div className={styles.noDoc}>Not uploaded</div>
                          }
                        </div>
                      ))}
                    </div>

                    {/* Approve / Reject buttons */}
                    {viewUser.driverProfile.status !== 'approved' && (
                      <div className={styles.driverActions}>
                        <button
                          className={styles.rejectBtn}
                          onClick={async () => {
                            const { doc, updateDoc } = await import('firebase/firestore');
                            const { db } = await import('../firebase');
                            await updateDoc(doc(db, 'users', viewUser.id), {
                              'driverProfile.status': 'rejected'
                            });
                            setViewUser({...viewUser, driverProfile: {...viewUser.driverProfile, status: 'rejected'}});
                          }}
                        >
                          ✕ Reject
                        </button>
                        <button
                          className={styles.approveBtn}
                          onClick={async () => {
                            const { doc, updateDoc } = await import('firebase/firestore');
                            const { db } = await import('../firebase');
                            await updateDoc(doc(db, 'users', viewUser.id), {
                              'driverProfile.status': 'approved'
                            });
                            setViewUser({...viewUser, driverProfile: {...viewUser.driverProfile, status: 'approved'}});
                          }}
                        >
                          ✓ Approve
                        </button>
                      </div>
                    )}
                  </>
                )}
              </div>
            )}

            <div className={styles.modalFooter}>
              <button className={styles.cancelBtn} onClick={() => setViewUser(null)}>Close</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
