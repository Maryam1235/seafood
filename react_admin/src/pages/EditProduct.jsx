import { useState, useEffect } from 'react';
import { collection, onSnapshot, doc, updateDoc } from 'firebase/firestore';
import { db } from '../firebase';
import styles from './AddProduct.module.css';

const CATEGORIES = ['cat_fish', 'cat_shrimp', 'cat_crab', 'cat_lobster', 'cat_squid', 'cat_octopus', 'cat_other'];
const CAT_LABELS  = { cat_fish: 'Fish', cat_shrimp: 'Shrimp', cat_crab: 'Crab', cat_lobster: 'Lobster', cat_squid: 'Squid', cat_octopus: 'Octopus', cat_other: 'Other' };
const UNITS = ['kg', 'g', 'piece', 'dozen'];

const CLOUD_NAME    = 'dx7jrfytj';
const UPLOAD_PRESET = 'seafoods';

export default function EditProduct({ product, onBack }) {
  const [sellers, setSellers] = useState([]);
  const [form, setForm] = useState({
    name:        product.name        || '',
    description: product.description || '',
    price:       product.price       || '',
    stock:       product.stock       || '',
    unit:        product.unit        || 'kg',
    category:    CATEGORIES.includes(product.category) ? product.category : 'cat_fish',
    location:    product.location    || '',
    sellerId:    product.sellerId    || '',
    isAvailable: product.isAvailable ?? true,
  });
  const [imageFile, setImageFile]       = useState(null);
  const [imagePreview, setImagePreview] = useState(product.imageUrl || null);
  const [loading, setLoading]           = useState(false);
  const [error, setError]               = useState('');
  const [success, setSuccess]           = useState(false);

  useEffect(() => {
    const unsub = onSnapshot(collection(db, 'users'), (snap) => {
      setSellers(snap.docs.map(d => ({ id: d.id, ...d.data() })).filter(u => u.role === 'seller'));
    });
    return unsub;
  }, []);

  const handleImage = (e) => {
    const file = e.target.files[0];
    if (!file) return;
    setImageFile(file);
    setImagePreview(URL.createObjectURL(file));
  };

  const uploadImage = async (file) => {
    const data = new FormData();
    data.append('file', file);
    data.append('upload_preset', UPLOAD_PRESET);
    const res  = await fetch(`https://api.cloudinary.com/v1_1/${CLOUD_NAME}/image/upload`, { method: 'POST', body: data });
    const json = await res.json();
    if (!json.secure_url) throw new Error('Image upload failed: ' + (json.error?.message || 'Unknown error'));
    return json.secure_url;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!form.sellerId) { setError('Please select a seller'); return; }
    setLoading(true);
    setError('');
    try {
      let imageUrl = product.imageUrl;
      if (imageFile) imageUrl = await uploadImage(imageFile);

      await updateDoc(doc(db, 'products', product.id), {
        name:        form.name,
        description: form.description,
        price:       parseFloat(form.price),
        stock:       parseFloat(form.stock),
        unit:        form.unit,
        category:    form.category,
        location:    form.location,
        sellerId:    form.sellerId,
        isAvailable: form.isAvailable,
        imageUrl,
      });
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
        <h2>Edit Product</h2>
        <button className={styles.backBtn} onClick={onBack}>← Back</button>
      </div>

      <div className={styles.card}>
        {success && <div className={styles.success}>Product updated successfully! Redirecting...</div>}
        {error   && <div className={styles.error}>{error}</div>}

        <form onSubmit={handleSubmit}>
          {/* Image */}
          <div className={styles.imageSection}>
            <label className={styles.imageLabel} htmlFor="editImgInput">
              {imagePreview
                ? <img src={imagePreview} alt="preview" className={styles.preview} />
                : <div className={styles.imagePlaceholder}><span>📷</span><p>Click to change image</p></div>
              }
            </label>
            <input id="editImgInput" type="file" accept="image/*" onChange={handleImage} className={styles.fileInput} />
            {imagePreview && <p style={{fontSize:'12px', color:'#9ca3af', marginTop:'6px', textAlign:'center'}}>Click image to change</p>}
          </div>

          <div className={styles.grid}>
            {/* Seller */}
            <div className={`${styles.field} ${styles.fullWidth}`}>
              <label>Seller *</label>
              <select required value={form.sellerId} onChange={e => setForm({...form, sellerId: e.target.value})}>
                <option value="">-- Select a Seller --</option>
                {sellers.map(s => (
                  <option key={s.id} value={s.id}>{s.username} ({s.email})</option>
                ))}
              </select>
            </div>

            <div className={styles.field}>
              <label>Product Name *</label>
              <input required value={form.name} onChange={e => setForm({...form, name: e.target.value})} />
            </div>

            <div className={styles.field}>
              <label>Category *</label>
              <select value={form.category} onChange={e => setForm({...form, category: e.target.value})}>
                {CATEGORIES.map(c => <option key={c} value={c}>{CAT_LABELS[c]}</option>)}
              </select>
            </div>

            <div className={styles.field}>
              <label>Price (TShs) *</label>
              <input required inputMode="numeric" pattern="[0-9]*(\.[0-9]+)?" value={form.price}
                onChange={e => setForm({...form, price: e.target.value})}
                placeholder="e.g. 5000" />
            </div>

            <div className={styles.field}>
              <label>Unit *</label>
              <select value={form.unit} onChange={e => setForm({...form, unit: e.target.value})}>
                {UNITS.map(u => <option key={u} value={u}>{u}</option>)}
              </select>
            </div>

            <div className={styles.field}>
              <label>Available Stock *</label>
              <input required inputMode="numeric" pattern="[0-9]*(\.[0-9]+)?" value={form.stock}
                onChange={e => setForm({...form, stock: e.target.value})}
                placeholder="e.g. 50" />
            </div>

            <div className={styles.field}>
              <label>Pickup Location *</label>
              <input required value={form.location} onChange={e => setForm({...form, location: e.target.value})} />
            </div>

            <div className={`${styles.field} ${styles.fullWidth}`}>
              <label>Description *</label>
              <textarea required rows={3} value={form.description}
                onChange={e => setForm({...form, description: e.target.value})} />
            </div>

            <div className={styles.field}>
              <label>Status</label>
              <select value={form.isAvailable} onChange={e => setForm({...form, isAvailable: e.target.value === 'true'})}>
                <option value="true">Active</option>
                <option value="false">Inactive</option>
              </select>
            </div>
          </div>

          <div className={styles.footer}>
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
