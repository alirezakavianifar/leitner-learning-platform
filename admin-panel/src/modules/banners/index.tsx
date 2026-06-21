import React, { useEffect, useState } from 'react';
import { api } from '../../services/api';
import type { Banner, AdminModule } from '../../types';

export const BannersView: React.FC = () => {
  const [banners, setBanners] = useState<Banner[]>([]);
  const [loading, setLoading] = useState(true);
  const [editingItem, setEditingItem] = useState<any | null>(null);
  const [showModal, setShowModal] = useState(false);

  // Form Fields
  const [imageUrl, setImageUrl] = useState('');
  const [linkUrl, setLinkUrl] = useState('');
  const [displayOrder, setDisplayOrder] = useState<number>(0);
  const [isActive, setIsActive] = useState(true);

  const loadBanners = async () => {
    try {
      setLoading(true);
      const data = await api.admin.getBanners();
      // Since backend Banner models map differently, normalize lists
      const normalized = data.map((b: any) => ({
        id: b.id,
        image_url: b.image_url,
        link_url: b.link_url,
        display_order: b.display_order,
        is_active: b.is_active
      }));
      setBanners(normalized);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadBanners();
  }, []);

  const openCreate = () => {
    setEditingItem(null);
    setImageUrl('');
    setLinkUrl('');
    setDisplayOrder(0);
    setIsActive(true);
    setShowModal(true);
  };

  const openEdit = (item: Banner) => {
    setEditingItem(item);
    setImageUrl(item.image_url);
    setLinkUrl(item.link_url || '');
    setDisplayOrder(item.display_order);
    setIsActive(item.is_active);
    setShowModal(true);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!imageUrl.trim()) return;

    try {
      const targetLink = linkUrl.trim() === '' ? null : linkUrl.trim();
      if (editingItem) {
        await api.admin.updateBanner(editingItem.id, imageUrl, targetLink, displayOrder, isActive);
        alert('Banner updated successfully.');
      } else {
        await api.admin.createBanner(imageUrl, targetLink, displayOrder, isActive);
        alert('Banner created successfully.');
      }
      setShowModal(false);
      loadBanners();
    } catch (err: any) {
      alert(err.message || 'Failed to save banner details.');
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Are you sure you want to delete this promotional banner?')) return;
    try {
      await api.admin.deleteBanner(id);
      alert('Banner deleted.');
      loadBanners();
    } catch (err: any) {
      alert(err.message || 'Failed to delete banner.');
    }
  };

  return (
    <div>
      <div className="table-container">
        <div className="table-header">
          <h2>Carousel Promotional Banners</h2>
          <button className="btn" onClick={openCreate}>Add Banner</button>
        </div>

        {loading ? (
          <div className="text-center p-24">Loading banners...</div>
        ) : (
          <table className="data-table">
            <thead>
              <tr>
                <th>Preview</th>
                <th>Image URL</th>
                <th>Link URL</th>
                <th>Display Order</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {banners.length === 0 ? (
                <tr>
                  <td colSpan={6} className="text-center text-muted">No promotional banners uploaded.</td>
                </tr>
              ) : (
                banners.map((item) => (
                  <tr key={item.id}>
                    <td>
                      <img
                        src={item.image_url}
                        alt="banner"
                        style={{ width: '80px', height: '40px', objectFit: 'cover', borderRadius: '4px', border: '1px solid var(--border-color)' }}
                        onError={(e) => {
                          (e.target as HTMLImageElement).src = 'https://placehold.co/80x40/1b2336/94a3b8?text=No+Image';
                        }}
                      />
                    </td>
                    <td>
                      <code style={{ fontSize: '11px' }}>{item.image_url}</code>
                    </td>
                    <td>{item.link_url || <span style={{ fontStyle: 'italic', color: 'var(--text-muted)' }}>None</span>}</td>
                    <td>{item.display_order}</td>
                    <td>
                      <span className={`badge ${item.is_active ? 'completed' : 'failed'}`}>
                        {item.is_active ? 'Active' : 'Inactive'}
                      </span>
                    </td>
                    <td>
                      <div style={{ display: 'flex', gap: '8px' }}>
                        <button className="btn btn-secondary" style={{ padding: '6px 12px', fontSize: '12px' }} onClick={() => openEdit(item)}>
                          Edit
                        </button>
                        <button className="btn btn-danger" style={{ padding: '6px 12px', fontSize: '12px' }} onClick={() => handleDelete(item.id)}>
                          Delete
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        )}
      </div>

      {showModal && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '500px' }}>
            <div className="modal-header">
              <h3>{editingItem ? 'Edit Promotional Banner' : 'Add Promotional Banner'}</h3>
              <button className="refresh-captcha-btn" style={{ fontSize: '20px' }} onClick={() => setShowModal(false)}>&times;</button>
            </div>
            <form onSubmit={handleSubmit}>
              <div className="modal-body">
                <div className="form-group">
                  <label>Image Resource URL</label>
                  <input type="url" placeholder="https://..." value={imageUrl} onChange={(e) => setImageUrl(e.target.value)} required />
                </div>
                <div className="form-group">
                  <label>Redirection Target Link URL (Optional)</label>
                  <input type="url" placeholder="https://..." value={linkUrl} onChange={(e) => setLinkUrl(e.target.value)} />
                </div>
                <div className="form-group" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                  <div>
                    <label>Display Order Sequence</label>
                    <input type="number" min="0" value={displayOrder} onChange={(e) => setDisplayOrder(parseInt(e.target.value) || 0)} required />
                  </div>
                  <div style={{ display: 'flex', flexDirection: 'column', justifyContent: 'center', height: '100%' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginTop: '12px' }}>
                      <input
                        type="checkbox"
                        id="bannerActive"
                        checked={isActive}
                        onChange={(e) => setIsActive(e.target.checked)}
                        style={{ width: 'auto' }}
                      />
                      <label htmlFor="bannerActive" style={{ margin: 0, cursor: 'pointer' }}>Mark Banner Active</label>
                    </div>
                  </div>
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-secondary" onClick={() => setShowModal(false)}>
                  Cancel
                </button>
                <button type="submit" className="btn">
                  {editingItem ? 'Save Changes' : 'Upload Banner'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export const BannersModule: AdminModule = {
  id: 'banners',
  name: 'Banners',
  icon: (props) => (
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...props}>
      <rect x="3" y="3" width="18" height="18" rx="2" ry="2" />
      <circle cx="8.5" cy="8.5" r="1.5" />
      <polyline points="21 15 16 10 5 21" />
    </svg>
  ),
  component: BannersModuleView
};

// Simple helper to resolve React TS compilation naming conflicts
function BannersModuleView() {
  return <BannersView />;
}
