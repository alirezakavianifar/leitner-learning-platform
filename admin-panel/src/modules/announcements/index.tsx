import React, { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { localizeNumber } from '../../i18n';
import { api } from '../../services/api';
import type { Announcement, AdminModule } from '../../types';
import { useToast } from '../../components/ToastContext';

export const AnnouncementsView: React.FC = () => {
  const { t } = useTranslation();
  const toast = useToast();
  const [announcements, setAnnouncements] = useState<Announcement[]>([]);
  const [loading, setLoading] = useState(true);
  const [editingItem, setEditingItem] = useState<Announcement | null>(null);
  const [showModal, setShowModal] = useState(false);

  // Form Fields
  const [title, setTitle] = useState('');
  const [content, setContent] = useState('');

  const loadAnnouncements = async () => {
    try {
      setLoading(true);
      const data = await api.admin.getAnnouncements();
      setAnnouncements(data);
    } catch (err: any) {
      toast.showError(err.message || 'خطا در دریافت اطلاعیه‌ها');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadAnnouncements();
  }, []);

  const openCreate = () => {
    setEditingItem(null);
    setTitle('');
    setContent('');
    setShowModal(true);
  };

  const openEdit = (item: Announcement) => {
    setEditingItem(item);
    setTitle(item.title);
    setContent(item.content);
    setShowModal(true);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim() || !content.trim()) {
      toast.showWarning('لطفاً عنوان و متن اطلاعیه را وارد نمایید.');
      return;
    }

    try {
      if (editingItem) {
        await api.admin.updateAnnouncement(editingItem.id, title, content);
        toast.showSuccess(t('announcements.alert_save_success', 'Announcement updated successfully.'));
      } else {
        await api.admin.createAnnouncement(title, content);
        toast.showSuccess(t('announcements.alert_create_success', 'Announcement created successfully.'));
      }
      setShowModal(false);
      loadAnnouncements();
    } catch (err: any) {
      toast.showError(err.message || t('announcements.alert_save_failed', 'Failed to save announcement.'));
    }
  };

  const handleDelete = async (id: string) => {
    const confirmed = await toast.confirm({
      title: 'حذف اطلاعیه',
      message: t('announcements.confirm_delete', 'Are you sure you want to delete this announcement?'),
      confirmText: 'حذف اطلاعیه',
      cancelText: 'انصراف',
      type: 'danger',
    });

    if (!confirmed) return;
    try {
      await api.admin.deleteAnnouncement(id);
      toast.showSuccess(t('announcements.alert_delete_success', 'Announcement deleted.'));
      loadAnnouncements();
    } catch (err: any) {
      toast.showError(err.message || t('announcements.alert_delete_failed', 'Failed to delete announcement.'));
    }
  };

  return (
    <div>
      <div className="table-container">
        <div className="table-header">
          <h2>{t('announcements.title')}</h2>
          <button className="btn" onClick={openCreate}>{t('announcements.btn_add')}</button>
        </div>

        {loading ? (
          <div className="text-center p-24">{t('login.verifying', 'Loading...')}</div>
        ) : (
          <table className="data-table">
            <thead>
              <tr>
                <th>{t('announcements.th_title')}</th>
                <th>{t('announcements.th_content')}</th>
                <th>{t('announcements.th_published')}</th>
                <th>{t('announcements.th_actions')}</th>
              </tr>
            </thead>
            <tbody>
              {announcements.length === 0 ? (
                <tr>
                  <td colSpan={4} className="text-center text-muted">{t('announcements.no_announcements', 'No announcements posted yet.')}</td>
                </tr>
              ) : (
                announcements.map((item) => (
                  <tr key={item.id}>
                    <td>
                      <div style={{ fontWeight: 600, color: 'var(--text-inverse)' }}>{item.title}</div>
                    </td>
                    <td style={{ maxWidth: '300px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                      {item.content}
                    </td>
                    <td>{localizeNumber(new Date(item.published_at).toLocaleString())}</td>
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
              <h3>{editingItem ? t('announcements.modal_edit') : t('announcements.modal_add')}</h3>
              <button className="refresh-captcha-btn" style={{ fontSize: '20px' }} onClick={() => setShowModal(false)}>&times;</button>
            </div>
            <form onSubmit={handleSubmit}>
              <div className="modal-body">
                <div className="form-group">
                  <label>{t('announcements.field_title')}</label>
                  <input type="text" value={title} onChange={(e) => setTitle(e.target.value)} required />
                </div>
                <div className="form-group">
                  <label>{t('announcements.field_content')}</label>
                  <textarea rows={5} value={content} onChange={(e) => setContent(e.target.value)} required></textarea>
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-secondary" onClick={() => setShowModal(false)}>
                  {t('courses.btn_cancel')}
                </button>
                <button type="submit" className="btn">
                  {editingItem ? t('courses.btn_save') : t('announcements.btn_save')}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export const AnnouncementsModule: AdminModule = {
  id: 'announcements',
  name: 'Announcements',
  icon: (props) => (
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...props}>
      <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9" />
      <path d="M13.73 21a2 2 0 0 1-3.46 0" />
    </svg>
  ),
  component: AnnouncementsView
};

