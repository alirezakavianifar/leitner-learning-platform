import React, { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { localizeNumber, formatPrice } from '../../i18n';
import { api } from '../../services/api';
import type { Course, AdminModule } from '../../types';

export const CoursesView: React.FC = () => {
  const { t } = useTranslation();
  const [courses, setCourses] = useState<Course[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [showEditModal, setShowEditModal] = useState(false);
  const [showUploadModal, setShowUploadModal] = useState(false);
  const [editingCourse, setEditingCourse] = useState<Course | null>(null);
  
  // Edit Form Fields
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [category, setCategory] = useState('');
  const [difficulty, setDifficulty] = useState('Intermediate');
  const [price, setPrice] = useState<number>(0);
  const [isPublished, setIsPublished] = useState(false);

  // Upload Fields
  const [uploadFile, setUploadFile] = useState<File | null>(null);
  const [uploading, setUploading] = useState(false);

  const loadCourses = async () => {
    try {
      setLoading(true);
      const res = await api.admin.getCourses(search, page, 10);
      setCourses(res.courses);
      setTotalPages(Math.ceil(res.total_count / 10) || 1);
    } catch (err) {
      console.error('Failed to load courses', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadCourses();
  }, [page, search]);

  const handleSearchChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setSearch(e.target.value);
    setPage(1);
  };

  const openEdit = (course: any) => {
    setEditingCourse(course);
    setTitle(course.title || '');
    setDescription(course.description || '');
    setCategory(course.category || '');
    setDifficulty(course.difficulty || 'Intermediate');
    setPrice(course.price || 0);
    setIsPublished(course.is_published || false);
    setShowEditModal(true);
  };

  const handleEditSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingCourse) return;

    try {
      await api.admin.updateCourse(editingCourse.id, {
        title,
        description,
        category,
        difficulty,
        price,
        is_published: isPublished
      });
      alert(t('courses.alert_save_success', 'Course metadata updated successfully.'));
      setShowEditModal(false);
      loadCourses();
    } catch (err: any) {
      alert(err.message || t('courses.alert_save_failed', 'Failed to update course.'));
    }
  };

  const togglePublishStatus = async (course: any) => {
    try {
      await api.admin.updateCourse(course.id, {
        is_published: !course.is_published
      });
      loadCourses();
    } catch (err: any) {
      alert(err.message || t('courses.alert_save_failed', 'Failed to toggle publish status.'));
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm(t('courses.confirm_delete', 'Are you sure you want to delete this course and all associated cards? This cannot be undone.'))) {
      return;
    }

    try {
      await api.admin.deleteCourse(id);
      alert(t('courses.alert_delete_success', 'Course deleted successfully.'));
      loadCourses();
    } catch (err: any) {
      alert(err.message || t('courses.alert_delete_failed', 'Failed to delete course.'));
    }
  };

  const handleUploadSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!uploadFile) {
      alert(t('courses.alert_select_file', 'Please select a file to upload.'));
      return;
    }

    const formData = new FormData();
    formData.append('file', uploadFile);

    try {
      setUploading(true);
      await api.admin.uploadCourse(formData);
      alert(t('courses.alert_upload_success', 'Course package uploaded and parsed successfully!'));
      setShowUploadModal(false);
      setUploadFile(null);
      loadCourses();
    } catch (err: any) {
      alert(err.message || t('courses.alert_upload_failed', 'Failed to upload course package.'));
    } finally {
      setUploading(false);
    }
  };

  return (
    <div>
      <div className="table-container">
        <div className="table-header" style={{ display: 'flex', flexWrap: 'wrap', gap: '16px' }}>
          <div>
            <h2>{t('courses.title')}</h2>
            <p style={{ color: 'var(--text-muted)', fontSize: '13px', marginTop: '4px' }}>
              {t('courses.subtitle', 'Upload ZIP packages, modify pricing, difficulty levels, and publish status.')}
            </p>
          </div>
          <div style={{ display: 'flex', gap: '12px', marginLeft: 'auto', alignItems: 'center' }}>
            <input
              type="text"
              className="search-input"
              placeholder={t('courses.search_placeholder')}
              value={search}
              onChange={handleSearchChange}
            />
            <button className="btn" onClick={() => setShowUploadModal(true)}>
              {t('courses.btn_add')}
            </button>
          </div>
        </div>

        {loading ? (
          <div className="text-center p-24">{t('login.verifying', 'Loading...')}</div>
        ) : (
          <div>
            <table className="data-table">
              <thead>
                <tr>
                  <th>{t('courses.th_title')}</th>
                  <th>{t('courses.field_category')}</th>
                  <th>{t('courses.th_difficulty', 'Difficulty')}</th>
                  <th>{t('courses.th_price')}</th>
                  <th>{t('courses.th_cards')}</th>
                  <th>{t('courses.th_version', 'Version')}</th>
                  <th>{t('users.th_status')}</th>
                  <th>{t('courses.th_actions')}</th>
                </tr>
              </thead>
              <tbody>
                {courses.length === 0 ? (
                  <tr>
                    <td colSpan={8} className="text-center text-muted">{t('courses.no_courses', 'No courses available.')}</td>
                  </tr>
                ) : (
                  courses.map((course) => (
                    <tr key={course.id}>
                      <td>
                        <div style={{ fontWeight: 600, color: 'var(--text-inverse)' }}>{course.title}</div>
                        <div style={{ fontSize: '11px', color: 'var(--text-muted)', maxWidth: '280px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                          {course.description || t('courses.no_description', 'No description provided')}
                        </div>
                      </td>
                      <td>{course.category || <span style={{ fontStyle: 'italic', color: 'var(--text-muted)' }}>{t('banners.status_inactive', 'None')}</span>}</td>
                      <td>
                        <span style={{
                          fontSize: '12px',
                          fontWeight: 500,
                          color: course.difficulty === 'Advanced' ? 'var(--accent-red)' : course.difficulty === 'Intermediate' ? 'var(--accent-yellow)' : 'var(--accent-green)'
                        }}>
                          {course.difficulty === 'Advanced' 
                            ? t('courses.difficulty_advanced', 'Advanced')
                            : course.difficulty === 'Beginner'
                            ? t('courses.difficulty_beginner', 'Beginner')
                            : t('courses.difficulty_intermediate', 'Intermediate')}
                        </span>
                      </td>
                      <td>
                        {course.price === 0 ? (
                          <span className="badge completed" style={{ fontSize: '10px' }}>{t('courses.status_free')}</span>
                        ) : (
                          `${formatPrice(course.price)} ${t('courses.irr', 'IRR')}`
                        )}
                      </td>
                      <td>
                        <strong style={{ color: 'var(--accent-cyan)' }}>{localizeNumber(course.card_count)}</strong> {t('courses.cards_unit', 'cards')}
                      </td>
                      <td>v{localizeNumber(course.version)}</td>
                      <td>
                        <button
                          style={{
                            background: 'none',
                            border: 'none',
                            cursor: 'pointer',
                            padding: 0
                          }}
                          onClick={() => togglePublishStatus(course)}
                          title="Click to toggle publish status"
                        >
                          <span className={`badge ${course.is_published ? 'completed' : 'pending'}`}>
                            {course.is_published ? t('announcements.th_published', 'Published') : t('courses.status_draft', 'Draft / Private')}
                          </span>
                        </button>
                      </td>
                      <td>
                        <div style={{ display: 'flex', gap: '8px' }}>
                          <button
                            className="btn btn-secondary"
                            style={{ padding: '6px 12px', fontSize: '12px' }}
                            onClick={() => openEdit(course)}
                          >
                            {t('courses.btn_edit')}
                          </button>
                          <button
                            className="btn btn-danger"
                            style={{ padding: '6px 12px', fontSize: '12px' }}
                            onClick={() => handleDelete(course.id)}
                          >
                            {t('courses.btn_delete')}
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>

            {/* Pagination */}
            {totalPages > 1 && (
              <div style={{ display: 'flex', justifyContent: 'center', padding: '16px', gap: '12px', borderTop: '1px solid var(--border-color)' }}>
                <button
                  className="btn btn-secondary"
                  style={{ padding: '6px 12px' }}
                  disabled={page === 1}
                  onClick={() => setPage(p => Math.max(p - 1, 1))}
                >
                  {t('users.prev')}
                </button>
                <span style={{ alignSelf: 'center', fontSize: '14px', color: 'var(--text-muted)' }}>
                  {t('courses.pagination_page', 'Page')} {localizeNumber(page)} {t('courses.pagination_of', 'of')} {localizeNumber(totalPages)}
                </span>
                <button
                  className="btn btn-secondary"
                  style={{ padding: '6px 12px' }}
                  disabled={page === totalPages}
                  onClick={() => setPage(p => Math.min(p + 1, totalPages))}
                >
                  {t('users.next')}
                </button>
              </div>
            )}
          </div>
        )}
      </div>

      {/* Edit Modal */}
      {showEditModal && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '500px' }}>
            <div className="modal-header">
              <h3>{t('courses.modal_edit_title')}</h3>
              <button className="refresh-captcha-btn" style={{ fontSize: '20px' }} onClick={() => setShowEditModal(false)}>&times;</button>
            </div>
            <form onSubmit={handleEditSubmit}>
              <div className="modal-body">
                <div className="form-group">
                  <label>{t('courses.field_title')}</label>
                  <input type="text" value={title} onChange={(e) => setTitle(e.target.value)} required />
                </div>
                <div className="form-group">
                  <label>{t('courses.field_description', 'Description')}</label>
                  <textarea rows={3} value={description} onChange={(e) => setDescription(e.target.value)} />
                </div>
                <div className="form-group" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                  <div>
                    <label>{t('courses.field_category')}</label>
                    <input type="text" value={category} onChange={(e) => setCategory(e.target.value)} placeholder="e.g. Languages" />
                  </div>
                  <div>
                    <label>{t('courses.th_difficulty', 'Difficulty')}</label>
                    <select value={difficulty} onChange={(e) => setDifficulty(e.target.value)}>
                      <option value="Beginner">{t('courses.difficulty_beginner', 'Beginner')}</option>
                      <option value="Intermediate">{t('courses.difficulty_intermediate', 'Intermediate')}</option>
                      <option value="Advanced">{t('courses.difficulty_advanced', 'Advanced')}</option>
                    </select>
                  </div>
                </div>
                <div className="form-group" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                  <div>
                    <label>{t('courses.field_price')}</label>
                    <input type="number" min="0" value={price} onChange={(e) => setPrice(parseFloat(e.target.value) || 0)} required />
                  </div>
                  <div style={{ display: 'flex', flexDirection: 'column', justifyContent: 'center', height: '100%' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginTop: '12px' }}>
                      <input
                        type="checkbox"
                        id="coursePublish"
                        checked={isPublished}
                        onChange={(e) => setIsPublished(e.target.checked)}
                        style={{ width: 'auto' }}
                      />
                      <label htmlFor="coursePublish" style={{ margin: 0, cursor: 'pointer' }}>{t('courses.field_publish', 'Publish Course')}</label>
                    </div>
                  </div>
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-secondary" onClick={() => setShowEditModal(false)}>
                  {t('courses.btn_cancel')}
                </button>
                <button type="submit" className="btn">
                  {t('courses.btn_save')}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Upload Modal */}
      {showUploadModal && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '500px' }}>
            <div className="modal-header">
              <h3>{t('courses.modal_add_title')}</h3>
              <button className="refresh-captcha-btn" style={{ fontSize: '20px' }} onClick={() => setShowUploadModal(false)}>&times;</button>
            </div>
            <form onSubmit={handleUploadSubmit}>
              <div className="modal-body">
                <p style={{ fontSize: '13px', color: 'var(--text-muted)', marginBottom: '16px' }}>
                  {t('courses.upload_desc', 'Select the compiled course ZIP package.')}
                </p>
                <div className="form-group">
                  <label>{t('courses.field_file')}</label>
                  <input
                    type="file"
                    accept=".zip"
                    onChange={(e) => setUploadFile(e.target.files?.[0] || null)}
                    required
                    style={{ padding: '8px' }}
                  />
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-secondary" onClick={() => setShowUploadModal(false)} disabled={uploading}>
                  {t('courses.btn_cancel')}
                </button>
                <button type="submit" className="btn" disabled={uploading}>
                  {uploading ? t('login.verifying', 'Processing...') : t('courses.btn_add')}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export const CoursesModule: AdminModule = {
  id: 'courses',
  name: 'Courses',
  icon: (props) => (
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...props}>
      <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20" />
      <path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z" />
    </svg>
  ),
  component: CoursesModuleView
};

function CoursesModuleView() {
  return <CoursesView />;
}
