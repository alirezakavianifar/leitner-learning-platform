import React, { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { localizeNumber } from '../../i18n';
import { api } from '../../services/api';
import type { Banner, AdminModule } from '../../types';
import { useToast } from '../../components/ToastContext';

export const BannersView: React.FC = () => {
  const { t } = useTranslation();
  const toast = useToast();
  const [banners, setBanners] = useState<Banner[]>([]);
  const [loading, setLoading] = useState(true);
  const [editingItem, setEditingItem] = useState<any | null>(null);
  const [showModal, setShowModal] = useState(false);

  // Form Fields
  const [imageUrl, setImageUrl] = useState('');
  const [linkUrl, setLinkUrl] = useState('');
  const [displayOrder, setDisplayOrder] = useState<number>(0);
  const [isActive, setIsActive] = useState(true);
  const [availableCourses, setAvailableCourses] = useState<{ id: string; title: string }[]>([]);
  const [availablePackages, setAvailablePackages] = useState<{ id: string; title: string }[]>([]);

  const loadCoursesAndPackages = async () => {
    try {
      const [coursesRes, packagesRes] = await Promise.all([
        api.admin.getCourses('', 1, 100, false),
        api.admin.getPackages()
      ]);
      setAvailableCourses((coursesRes.courses || []).map((c: any) => ({ id: c.id, title: c.title })));
      setAvailablePackages((packagesRes.packages || []).map((p: any) => ({ id: p.id, title: p.title })));
    } catch {
      // ignore
    }
  };

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
    } catch (err: any) {
      toast.showError(err.message || 'خطا در دریافت لیست بنرها');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadBanners();
  }, []);

  const openCreate = () => {
    loadCoursesAndPackages();
    setEditingItem(null);
    setImageUrl('');
    setLinkUrl('');
    setDisplayOrder(0);
    setIsActive(true);
    setShowModal(true);
  };

  const openEdit = (item: Banner) => {
    loadCoursesAndPackages();
    setEditingItem(item);
    setImageUrl(item.image_url);
    setLinkUrl(item.link_url || '');
    setDisplayOrder(item.display_order);
    setIsActive(item.is_active);
    setShowModal(true);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!imageUrl.trim()) {
      toast.showWarning(t('banners.alert_image_url_required', 'Please enter an Image URL.'));
      return;
    }

    try {
      const targetLink = linkUrl.trim() === '' ? null : linkUrl.trim();
      if (editingItem) {
        await api.admin.updateBanner(editingItem.id, imageUrl, targetLink, displayOrder, isActive);
        toast.showSuccess(t('banners.alert_save_success', 'Banner updated successfully.'));
      } else {
        await api.admin.createBanner(imageUrl, targetLink, displayOrder, isActive);
        toast.showSuccess(t('banners.alert_create_success', 'Banner created successfully.'));
      }
      setShowModal(false);
      loadBanners();
    } catch (err: any) {
      toast.showError(err.message || t('banners.alert_save_failed', 'Failed to save banner details.'));
    }
  };

  const handleDelete = async (id: string) => {
    const confirmed = await toast.confirm({
      title: 'حذف بنر تبلیغاتی',
      message: t('banners.confirm_delete', 'Are you sure you want to delete this promotional banner?'),
      confirmText: 'حذف بنر',
      cancelText: 'انصراف',
      type: 'danger',
    });

    if (!confirmed) return;

    try {
      await api.admin.deleteBanner(id);
      toast.showSuccess(t('banners.alert_delete_success', 'Banner deleted.'));
      loadBanners();
    } catch (err: any) {
      toast.showError(err.message || t('banners.alert_delete_failed', 'Failed to delete banner.'));
    }
  };

  return (
    <div>
      <div className="table-container">
        <div className="table-header">
          <h2>{t('banners.title')}</h2>
          <button className="btn" onClick={openCreate}>{t('banners.btn_add')}</button>
        </div>

        {loading ? (
          <div className="text-center p-24">{t('login.verifying', 'Loading...')}</div>
        ) : (
          <table className="data-table">
            <thead>
              <tr>
                <th>{t('banners.th_image')}</th>
                <th>{t('banners.field_image')}</th>
                <th>{t('banners.th_link')}</th>
                <th>{t('banners.th_order')}</th>
                <th>{t('banners.th_status')}</th>
                <th>{t('users.th_actions')}</th>
              </tr>
            </thead>
            <tbody>
              {banners.length === 0 ? (
                <tr>
                  <td colSpan={6} className="text-center text-muted">{t('banners.no_banners', 'No promotional banners uploaded.')}</td>
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
                    <td>{item.link_url || <span style={{ fontStyle: 'italic', color: 'var(--text-muted)' }}>{t('banners.status_inactive', 'None')}</span>}</td>
                    <td>{localizeNumber(item.display_order)}</td>
                    <td>
                      <span className={`badge ${item.is_active ? 'completed' : 'failed'}`}>
                        {item.is_active ? t('banners.status_active') : t('banners.status_inactive')}
                      </span>
                    </td>
                    <td>
                      <div style={{ display: 'flex', gap: '8px' }}>
                        <button className="btn btn-secondary" style={{ padding: '6px 12px', fontSize: '12px' }} onClick={() => openEdit(item)}>
                          {t('courses.btn_edit')}
                        </button>
                        <button className="btn btn-danger" style={{ padding: '6px 12px', fontSize: '12px' }} onClick={() => handleDelete(item.id)}>
                          {t('courses.btn_delete')}
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
              <h3>{editingItem ? t('banners.modal_edit') : t('banners.modal_add')}</h3>
              <button className="refresh-captcha-btn" style={{ fontSize: '20px' }} onClick={() => setShowModal(false)}>&times;</button>
            </div>
            <form onSubmit={handleSubmit}>
              <div className="modal-body">
                <div className="form-group">
                  <label>{t('banners.field_image')}</label>
                  <input type="url" placeholder="https://..." value={imageUrl} onChange={(e) => setImageUrl(e.target.value)} required />
                  {imageUrl.trim() && (
                    <div style={{ marginTop: '8px' }}>
                      <img
                        src={imageUrl.trim()}
                        alt="Preview"
                        style={{ width: '100%', maxHeight: '110px', objectFit: 'cover', borderRadius: '6px', border: '1px solid var(--border-color)' }}
                        onError={(e) => { (e.target as HTMLElement).style.display = 'none'; }}
                      />
                    </div>
                  )}
                </div>
                <div className="form-group">
                  <label>{t('banners.field_link', 'Action Link URL / In-App Course Target')}</label>
                  <input
                    type="text"
                    placeholder="https://... or course://<id> or package://<id>"
                    value={linkUrl}
                    onChange={(e) => setLinkUrl(e.target.value)}
                  />
                  {(availableCourses.length > 0 || availablePackages.length > 0) && (
                    <div style={{ marginTop: '6px' }}>
                      <select
                        onChange={(e) => {
                          if (e.target.value) {
                            setLinkUrl(e.target.value);
                          }
                        }}
                        defaultValue=""
                        style={{ fontSize: '12px', padding: '6px' }}
                      >
                        <option value="" disabled>-- {t('banners.select_target', 'Or pick an In-App Course / Package')} --</option>
                        {availableCourses.length > 0 && (
                          <optgroup label="📚 دوره‌های تکی (Courses)">
                            {availableCourses.map((c) => (
                              <option key={c.id} value={`course://${c.id}`}>
                                📖 {c.title}
                              </option>
                            ))}
                          </optgroup>
                        )}
                        {availablePackages.length > 0 && (
                          <optgroup label="📦 بسته‌های آموزشی (Packages)">
                            {availablePackages.map((p) => (
                              <option key={p.id} value={`package://${p.id}`}>
                                🎁 {p.title}
                              </option>
                            ))}
                          </optgroup>
                        )}
                      </select>
                    </div>
                  )}
                  <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '4px' }}>
                    {t('banners.link_hint', 'Enter external web link (https://...) or in-app course deep link (course://<id> / package://<id>).')}
                  </div>
                </div>
                <div className="form-group" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                  <div>
                    <label>{t('banners.field_order')}</label>
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
                      <label htmlFor="bannerActive" style={{ margin: 0, cursor: 'pointer' }}>{t('banners.field_active')}</label>
                    </div>
                  </div>
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-secondary" onClick={() => setShowModal(false)}>
                  {t('courses.btn_cancel')}
                </button>
                <button type="submit" className="btn">
                  {editingItem ? t('courses.btn_save') : t('banners.btn_save')}
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

function BannersModuleView() {
  return <BannersView />;
}

