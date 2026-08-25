import React, { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { localizeNumber, formatPrice } from '../../i18n';
import { api } from '../../services/api';
import type { Course, CoursePackage, AdminModule } from '../../types';
import { useToast } from '../../components/ToastContext';
import { QuickGrantModal } from '../../components/QuickGrantModal';

export const CoursesView: React.FC = () => {
  const { t } = useTranslation();
  const toast = useToast();
  
  // Tab state
  const [activeTab, setActiveTab] = useState<'courses' | 'packages'>('courses');

  // Quick grant state
  const [showQuickGrantModal, setShowQuickGrantModal] = useState(false);
  const [quickGrantTargetType, setQuickGrantTargetType] = useState<'COURSE' | 'PACKAGE'>('COURSE');
  const [quickGrantCourseId, setQuickGrantCourseId] = useState<string | undefined>(undefined);
  const [quickGrantPackageId, setQuickGrantPackageId] = useState<string | undefined>(undefined);

  // Courses state
  const [courses, setCourses] = useState<Course[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [showEditModal, setShowEditModal] = useState(false);
  const [showUploadModal, setShowUploadModal] = useState(false);
  const [editingCourse, setEditingCourse] = useState<Course | null>(null);
  const [includeArchived, setIncludeArchived] = useState(false);

  // Edit Course Form Fields
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [category, setCategory] = useState('');
  const [difficulty, setDifficulty] = useState('Intermediate');
  const [price, setPrice] = useState<number>(0);
  const [isPublished, setIsPublished] = useState(false);
  const [isCriticalUpdate, setIsCriticalUpdate] = useState(false);

  // Upload Fields
  const [uploadFile, setUploadFile] = useState<File | null>(null);
  const [uploading, setUploading] = useState(false);
  const [uploadProgress, setUploadProgress] = useState<number | null>(null);

  // Packages state
  const [packages, setPackages] = useState<CoursePackage[]>([]);
  const [loadingPackages, setLoadingPackages] = useState(false);
  const [showPackageModal, setShowPackageModal] = useState(false);
  const [editingPackage, setEditingPackage] = useState<CoursePackage | null>(null);
  const [allCoursesForPackage, setAllCoursesForPackage] = useState<Course[]>([]);

  // Package Form Fields
  const [pkgTitle, setPkgTitle] = useState('');
  const [pkgDescription, setPkgDescription] = useState('');
  const [pkgCategory, setPkgCategory] = useState('');
  const [pkgPrice, setPkgPrice] = useState<number>(0);
  const [pkgOriginalPrice, setPkgOriginalPrice] = useState<number | undefined>(undefined);
  const [pkgIsPublished, setPkgIsPublished] = useState(true);
  const [pkgSelectedCourseIds, setPkgSelectedCourseIds] = useState<string[]>([]);

  const loadCourses = async () => {
    try {
      setLoading(true);
      const res = await api.admin.getCourses(search, page, 10, includeArchived);
      setCourses(res.courses || []);
      setTotalPages(Math.ceil((res.total_count || 0) / 10) || 1);
    } catch (err: any) {
      toast.showError(err.message || t('courses.alert_save_failed', 'Failed to load courses.'));
    } finally {
      setLoading(false);
    }
  };

  const loadPackages = async () => {
    try {
      setLoadingPackages(true);
      const res = await api.admin.getPackages();
      setPackages(res.packages || []);
    } catch (err: any) {
      toast.showError(err.message || 'Failed to load packages.');
    } finally {
      setLoadingPackages(false);
    }
  };

  const loadAllCoursesForPackageSelection = async () => {
    try {
      const res = await api.admin.getCourses('', 1, 100, false);
      setAllCoursesForPackage(res.courses || []);
    } catch (err: any) {
      // ignore
    }
  };

  useEffect(() => {
    if (activeTab === 'courses') {
      loadCourses();
    } else {
      loadPackages();
      loadAllCoursesForPackageSelection();
    }
  }, [activeTab, page, search, includeArchived]);

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
    setIsCriticalUpdate(course.is_critical_update || false);
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
        is_published: isPublished,
        is_critical_update: isCriticalUpdate
      });
      toast.showSuccess(t('courses.alert_save_success', 'Course metadata updated successfully.'));
      setShowEditModal(false);
      loadCourses();
    } catch (err: any) {
      toast.showError(err.message || t('courses.alert_save_failed', 'Failed to update course.'));
    }
  };

  const togglePublishStatus = async (course: any) => {
    try {
      await api.admin.updateCourse(course.id, {
        is_published: !course.is_published
      });
      toast.showSuccess(course.is_published ? 'دوره از حالت انتشار خارج شد.' : 'دوره با موفقیت منتشر شد.');
      loadCourses();
    } catch (err: any) {
      toast.showError(err.message || t('courses.alert_save_failed', 'Failed to toggle publish status.'));
    }
  };

  const handleDelete = async (id: string) => {
    const confirmed = await toast.confirm({
      title: t('courses.confirm_archive_title', 'Archive Course'),
      message: t(
        'courses.confirm_delete',
        'This will hide the course from the store. Users who already purchased or downloaded it keep their access. You can unarchive it later. Continue?'
      ),
      confirmText: t('courses.btn_archive', 'Archive'),
      cancelText: 'انصراف',
      type: 'danger',
    });

    if (!confirmed) return;

    try {
      await api.admin.deleteCourse(id);
      toast.showSuccess(t('courses.alert_delete_success', 'Course archived successfully. Existing buyers keep access.'));
      loadCourses();
    } catch (err: any) {
      toast.showError(err.message || t('courses.alert_delete_failed', 'Failed to archive course.'));
    }
  };

  const handleUnarchive = async (id: string) => {
    try {
      await api.admin.unarchiveCourse(id);
      toast.showSuccess(t('courses.alert_unarchive_success', 'Course unarchived successfully.'));
      loadCourses();
    } catch (err: any) {
      toast.showError(err.message || t('courses.alert_unarchive_failed', 'Failed to unarchive course.'));
    }
  };

  const handlePurge = async (id: string) => {
    const confirmed = await toast.confirm({
      title: t('courses.confirm_purge_title', 'Permanently Delete Course'),
      message: t(
        'courses.confirm_purge',
        'This PERMANENTLY deletes the course, its cards, all purchases, and all learner progress. Existing buyers will lose access entirely. This cannot be undone. Only use this for legal/compliance removals.'
      ),
      confirmText: t('courses.btn_purge', 'Permanently Delete'),
      cancelText: 'انصراف',
      type: 'danger',
    });

    if (!confirmed) return;

    try {
      await api.admin.purgeCourse(id);
      toast.showSuccess(t('courses.alert_purge_success', 'Course permanently deleted.'));
      loadCourses();
    } catch (err: any) {
      toast.showError(err.message || t('courses.alert_purge_failed', 'Failed to permanently delete course.'));
    }
  };

  const handleUploadSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!uploadFile) {
      toast.showWarning(t('courses.alert_select_file', 'Please select a file to upload.'));
      return;
    }

    try {
      setUploading(true);
      setUploadProgress(0);
      await api.admin.uploadCourse(uploadFile, (pct) => setUploadProgress(pct));
      toast.showSuccess(t('courses.alert_upload_success', 'Course package uploaded and parsed successfully!'));
      setShowUploadModal(false);
      setUploadFile(null);
      loadCourses();
    } catch (err: any) {
      toast.showError(err.message || t('courses.alert_upload_failed', 'Failed to upload course package.'));
    } finally {
      setUploading(false);
      setUploadProgress(null);
    }
  };

  const openQuickGrantCourse = (course: Course) => {
    setQuickGrantTargetType('COURSE');
    setQuickGrantCourseId(course.id);
    setQuickGrantPackageId(undefined);
    setShowQuickGrantModal(true);
  };

  const openQuickGrantPackage = (pkg: CoursePackage) => {
    setQuickGrantTargetType('PACKAGE');
    setQuickGrantCourseId(undefined);
    setQuickGrantPackageId(pkg.id);
    setShowQuickGrantModal(true);
  };

  // --- Package Handlers ---
  const openCreatePackage = async () => {
    await loadAllCoursesForPackageSelection();
    setEditingPackage(null);
    setPkgTitle('');
    setPkgDescription('');
    setPkgCategory('');
    setPkgPrice(0);
    setPkgOriginalPrice(undefined);
    setPkgIsPublished(true);
    setPkgSelectedCourseIds([]);
    setShowPackageModal(true);
  };

  const openEditPackage = async (pkg: CoursePackage) => {
    await loadAllCoursesForPackageSelection();
    setEditingPackage(pkg);
    setPkgTitle(pkg.title || '');
    setPkgDescription(pkg.description || '');
    setPkgCategory(pkg.category || '');
    setPkgPrice(pkg.price || 0);
    setPkgOriginalPrice(pkg.original_price);
    setPkgIsPublished(pkg.is_published);
    setPkgSelectedCourseIds((pkg.courses || []).map((c) => c.id));
    setShowPackageModal(true);
  };

  const toggleCourseSelectionInPackage = (courseId: string) => {
    setPkgSelectedCourseIds((prev) => {
      const next = prev.includes(courseId)
        ? prev.filter((id) => id !== courseId)
        : [...prev, courseId];

      // Automatically recalculate original sum
      const sum = allCoursesForPackage
        .filter((c) => next.includes(c.id))
        .reduce((acc, c) => acc + (c.price || 0), 0);
      setPkgOriginalPrice(sum > 0 ? sum : undefined);

      return next;
    });
  };

  const handlePackageSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (pkgSelectedCourseIds.length === 0) {
      toast.showWarning('حداقل یک دوره باید در بسته آموزشی انتخاب شود.');
      return;
    }

    try {
      const payload = {
        title: pkgTitle,
        description: pkgDescription,
        category: pkgCategory,
        price: pkgPrice,
        original_price: pkgOriginalPrice,
        is_published: pkgIsPublished,
        course_ids: pkgSelectedCourseIds,
      };

      if (editingPackage) {
        await api.admin.updatePackage(editingPackage.id, payload);
        toast.showSuccess('پکیج آموزشی با موفقیت ویرایش شد.');
      } else {
        await api.admin.createPackage(payload);
        toast.showSuccess('پکیج آموزشی جدید با موفقیت ایجاد شد.');
      }

      setShowPackageModal(false);
      loadPackages();
    } catch (err: any) {
      toast.showError(err.message || 'خطا در ذخیره پکیج آموزشی.');
    }
  };

  const handleDeletePackage = async (id: string) => {
    const confirmed = await toast.confirm({
      title: 'حذف پکیج آموزشی',
      message: 'آیا از حذف این پکیج آموزشی اطمینان دارید؟ دوره‌های موجود در آن حذف نخواهند شد.',
      confirmText: 'حذف پکیج',
      cancelText: 'انصراف',
      type: 'danger',
    });

    if (!confirmed) return;

    try {
      await api.admin.deletePackage(id);
      toast.showSuccess('پکیج آموزشی با موفقیت حذف شد.');
      loadPackages();
    } catch (err: any) {
      toast.showError(err.message || 'خطا در حذف پکیج.');
    }
  };

  return (
    <div>
      {/* Top Tab Bar */}
      <div style={{ display: 'flex', gap: '8px', marginBottom: '16px' }}>
        <button
          className={`btn ${activeTab === 'courses' ? 'btn-primary' : 'btn-secondary'}`}
          onClick={() => setActiveTab('courses')}
        >
          {t('courses.title')}
        </button>
        <button
          className={`btn ${activeTab === 'packages' ? 'btn-primary' : 'btn-secondary'}`}
          onClick={() => setActiveTab('packages')}
        >
          🎁 پکیج‌ها و بسته‌های آموزشی (Bundles)
        </button>
      </div>

      {activeTab === 'courses' ? (
        <div className="table-container">
          <div className="table-header" style={{ display: 'flex', flexWrap: 'wrap', gap: '16px' }}>
            <div>
              <h2>{t('courses.title')}</h2>
              <p style={{ color: 'var(--text-muted)', fontSize: '13px', marginTop: '4px' }}>
                {t('courses.subtitle', 'Upload ZIP packages, modify pricing, difficulty levels, and publish status.')}
              </p>
            </div>
            <div style={{ display: 'flex', gap: '12px', marginLeft: 'auto', alignItems: 'center' }}>
              <label style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '13px', color: 'var(--text-muted)', cursor: 'pointer' }}>
                <input
                  type="checkbox"
                  checked={includeArchived}
                  onChange={(e) => { setIncludeArchived(e.target.checked); setPage(1); }}
                  style={{ width: 'auto' }}
                />
                {t('courses.show_archived', 'Show archived')}
              </label>
              <input
                type="text"
                className="search-input"
                placeholder={t('courses.search_placeholder')}
                value={search}
                onChange={handleSearchChange}
              />
              <button
                type="button"
                className="btn btn-secondary"
                onClick={() => {
                  setQuickGrantTargetType('COURSE');
                  setQuickGrantCourseId(undefined);
                  setQuickGrantPackageId(undefined);
                  setShowQuickGrantModal(true);
                }}
                style={{ display: 'flex', alignItems: 'center', gap: '6px' }}
              >
                <span>🎁</span>
                <span>{t('quick_grant.btn_open', 'اعطای رایگان')}</span>
              </button>
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
                            padding: '2px 8px',
                            borderRadius: '4px',
                            backgroundColor: course.difficulty === 'Beginner' ? 'rgba(76, 175, 80, 0.15)' : course.difficulty === 'Advanced' ? 'rgba(244, 67, 54, 0.15)' : 'rgba(255, 152, 0, 0.15)',
                            color: course.difficulty === 'Beginner' ? '#4caf50' : course.difficulty === 'Advanced' ? '#f44336' : '#ff9800'
                          }}>
                            {course.difficulty || 'Intermediate'}
                          </span>
                        </td>
                        <td>
                          {course.price === 0 ? (
                            <span style={{ color: 'var(--success-color)', fontWeight: 600 }}>{t('courses.free')}</span>
                          ) : (
                            formatPrice(course.price)
                          )}
                        </td>
                        <td>{localizeNumber(course.card_count || 0)}</td>
                        <td>
                          <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>v{course.version}</span>
                          {course.is_critical_update && (
                            <span style={{ fontSize: '10px', color: 'var(--danger-color)', marginLeft: '4px', border: '1px solid var(--danger-color)', padding: '1px 4px', borderRadius: '4px' }}>
                              {t('courses.badge_critical', 'Critical')}
                            </span>
                          )}
                        </td>
                        <td>
                          {course.is_archived ? (
                            <span className="badge" style={{ backgroundColor: 'rgba(158, 158, 158, 0.2)', color: '#9e9e9e' }}>
                              {t('courses.status_archived', 'Archived')}
                            </span>
                          ) : (
                            <button
                              type="button"
                              onClick={() => togglePublishStatus(course)}
                              className={`badge ${course.is_published ? 'badge-success' : 'badge-inactive'}`}
                              style={{ border: 'none', cursor: 'pointer', display: 'inline-flex', alignItems: 'center', gap: '4px' }}
                              title="برای تغییر وضعیت انتشار کلیک کنید"
                            >
                              <span style={{ width: '6px', height: '6px', borderRadius: '50%', backgroundColor: course.is_published ? '#22c55e' : '#eab308' }} />
                              <span>
                                {course.is_published ? t('courses.status_published') : t('courses.status_draft')}
                              </span>
                            </button>
                          )}
                        </td>
                        <td>
                          <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                            <button
                              className="btn btn-secondary"
                              style={{ padding: '6px 10px', fontSize: '12px', display: 'flex', alignItems: 'center', gap: '4px' }}
                              onClick={() => openQuickGrantCourse(course)}
                              title="اعطای دسترسی رایگان این دوره به کاربر"
                            >
                              <span>🎁</span>
                              <span>اعطا</span>
                            </button>
                            <button
                              className="btn btn-secondary"
                              style={{ padding: '6px 12px', fontSize: '12px' }}
                              onClick={() => openEdit(course)}
                            >
                              {t('courses.btn_edit')}
                            </button>
                            {course.is_archived ? (
                              <>
                                <button
                                  className="btn btn-secondary"
                                  style={{ padding: '6px 12px', fontSize: '12px' }}
                                  onClick={() => handleUnarchive(course.id)}
                                >
                                  {t('courses.btn_unarchive', 'Unarchive')}
                                </button>
                                <button
                                  className="btn btn-danger"
                                  style={{ padding: '6px 12px', fontSize: '12px' }}
                                  onClick={() => handlePurge(course.id)}
                                >
                                  {t('courses.btn_purge', 'Permanently Delete')}
                                </button>
                              </>
                            ) : (
                              <button
                                className="btn btn-danger"
                                style={{ padding: '6px 12px', fontSize: '12px' }}
                                onClick={() => handleDelete(course.id)}
                              >
                                {t('courses.btn_archive', 'Archive')}
                              </button>
                            )}
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
                    onClick={() => setPage((p) => Math.max(p - 1, 1))}
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
                    onClick={() => setPage((p) => Math.min(p + 1, totalPages))}
                  >
                    {t('users.next')}
                  </button>
                </div>
              )}
            </div>
          )}
        </div>
      ) : (
        /* Packages View */
        <div className="table-container">
          <div className="table-header" style={{ display: 'flex', flexWrap: 'wrap', gap: '16px', alignItems: 'center' }}>
            <div>
              <h2>🎁 پکیج‌ها و بسته‌های آموزشی</h2>
              <p style={{ color: 'var(--text-muted)', fontSize: '13px', marginTop: '4px' }}>
                ترکیب چند دوره در یک پکیج تخفیف‌دار و امکان خرید یکجای آن‌ها توسط کاربران
              </p>
            </div>
            <div style={{ marginLeft: 'auto' }}>
              <button className="btn" onClick={openCreatePackage}>
                + ایجاد پکیج جدید
              </button>
            </div>
          </div>

          {loadingPackages ? (
            <div className="text-center p-24">درحال بارگذاری پکیج‌ها...</div>
          ) : (
            <table className="data-table">
              <thead>
                <tr>
                  <th>عنوان پکیج</th>
                  <th>دسته‌بندی</th>
                  <th>دوره‌های موجود در بسته</th>
                  <th>قیمت بسته</th>
                  <th>قیمت اصلی تکی</th>
                  <th>تخفیف</th>
                  <th>وضعیت انتشار</th>
                  <th>عملیات</th>
                </tr>
              </thead>
              <tbody>
                {packages.length === 0 ? (
                  <tr>
                    <td colSpan={8} className="text-center text-muted">
                      هنوز هیچ پکیج آموزشی تعریف نشده است. با کلیک بر روی «ایجاد پکیج جدید» اولین بسته را بسازید.
                    </td>
                  </tr>
                ) : (
                  packages.map((pkg) => {
                    const discount =
                      pkg.original_price && pkg.original_price > pkg.price
                        ? Math.round(((pkg.original_price - pkg.price) / pkg.original_price) * 100)
                        : 0;

                    return (
                      <tr key={pkg.id}>
                        <td>
                          <div style={{ fontWeight: 600, color: 'var(--text-inverse)' }}>{pkg.title}</div>
                          {pkg.description && (
                            <div style={{ fontSize: '11px', color: 'var(--text-muted)', maxWidth: '280px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                              {pkg.description}
                            </div>
                          )}
                        </td>
                        <td>{pkg.category || '—'}</td>
                        <td>
                          <div style={{ display: 'flex', gap: '4px', flexWrap: 'wrap' }}>
                            {pkg.courses.map((c) => (
                              <span
                                key={c.id}
                                style={{
                                  fontSize: '11px',
                                  padding: '2px 6px',
                                  borderRadius: '4px',
                                  backgroundColor: 'rgba(59, 130, 246, 0.15)',
                                  color: '#3b82f6',
                                  border: '1px solid rgba(59, 130, 246, 0.3)',
                                }}
                              >
                                {c.title}
                              </span>
                            ))}
                          </div>
                        </td>
                        <td style={{ fontWeight: 600, color: '#ffb300' }}>
                          {pkg.price === 0 ? 'رایگان' : formatPrice(pkg.price)}
                        </td>
                        <td style={{ textDecoration: 'line-through', color: 'var(--text-muted)' }}>
                          {pkg.original_price ? formatPrice(pkg.original_price) : '—'}
                        </td>
                        <td>
                          {discount > 0 ? (
                            <span className="badge badge-success">
                              {discount}٪ تخفیف
                            </span>
                          ) : (
                            '—'
                          )}
                        </td>
                        <td>
                          <span className={`badge ${pkg.is_published ? 'badge-success' : 'badge-inactive'}`}>
                            {pkg.is_published ? 'منتشر شده' : 'پیش‌نویس'}
                          </span>
                        </td>
                        <td>
                          <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                            <button
                              className="btn btn-secondary"
                              style={{ padding: '6px 10px', fontSize: '12px', display: 'flex', alignItems: 'center', gap: '4px' }}
                              onClick={() => openQuickGrantPackage(pkg)}
                              title="اعطای دسترسی رایگان این پکیج به کاربر"
                            >
                              <span>🎁</span>
                              <span>اعطا</span>
                            </button>
                            <button
                              className="btn btn-secondary"
                              style={{ padding: '6px 12px', fontSize: '12px' }}
                              onClick={() => openEditPackage(pkg)}
                            >
                              ویرایش
                            </button>
                            <button
                              className="btn btn-danger"
                              style={{ padding: '6px 12px', fontSize: '12px' }}
                              onClick={() => handleDeletePackage(pkg.id)}
                            >
                              حذف
                            </button>
                          </div>
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          )}
        </div>
      )}

      {/* Edit Course Modal */}
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
                <div className="form-group">
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <input
                      type="checkbox"
                      id="courseCriticalUpdate"
                      checked={isCriticalUpdate}
                      onChange={(e) => setIsCriticalUpdate(e.target.checked)}
                      style={{ width: 'auto' }}
                    />
                    <label htmlFor="courseCriticalUpdate" style={{ margin: 0, cursor: 'pointer' }}>
                      {t('courses.field_critical_update', 'Mark as critical fix (prompts existing users to update)')}
                    </label>
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

      {/* Package Create / Edit Modal */}
      {showPackageModal && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '600px' }}>
            <div className="modal-header">
              <h3>{editingPackage ? 'ویرایش پکیج آموزشی' : 'ایجاد پکیج آموزشی جدید'}</h3>
              <button className="refresh-captcha-btn" style={{ fontSize: '20px' }} onClick={() => setShowPackageModal(false)}>&times;</button>
            </div>
            <form onSubmit={handlePackageSubmit}>
              <div className="modal-body">
                <div className="form-group">
                  <label>عنوان بسته آموزشی *</label>
                  <input
                    type="text"
                    value={pkgTitle}
                    onChange={(e) => setPkgTitle(e.target.value)}
                    placeholder="مثلا: پکیج طلایی ۳ در ۱ زبان انگلیسی"
                    required
                  />
                </div>
                <div className="form-group">
                  <label>توضیحات بسته</label>
                  <textarea
                    rows={2}
                    value={pkgDescription}
                    onChange={(e) => setPkgDescription(e.target.value)}
                    placeholder="توضیحات جامع درباره مزایای خرید این پکیج..."
                  />
                </div>
                <div className="form-group">
                  <label>دسته‌بندی</label>
                  <input
                    type="text"
                    value={pkgCategory}
                    onChange={(e) => setPkgCategory(e.target.value)}
                    placeholder="مثلا: زبان‌های خارجی"
                  />
                </div>

                {/* Course Selection Checklist */}
                <div className="form-group">
                  <label style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <span>انتخاب دوره‌های موجود در این بسته *</span>
                    <span style={{ fontSize: '12px', color: '#3b82f6' }}>
                      {pkgSelectedCourseIds.length} دوره انتخاب شده
                    </span>
                  </label>
                  <div
                    style={{
                      maxHeight: '160px',
                      overflowY: 'auto',
                      border: '1px solid var(--border-color)',
                      borderRadius: '8px',
                      padding: '8px',
                      backgroundColor: 'rgba(0, 0, 0, 0.1)',
                    }}
                  >
                    {allCoursesForPackage.map((c) => {
                      const isChecked = pkgSelectedCourseIds.includes(c.id);
                      return (
                        <div
                          key={c.id}
                          onClick={() => toggleCourseSelectionInPackage(c.id)}
                          style={{
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'space-between',
                            padding: '6px 8px',
                            cursor: 'pointer',
                            borderRadius: '4px',
                            backgroundColor: isChecked ? 'rgba(59, 130, 246, 0.12)' : 'transparent',
                            marginBottom: '4px',
                          }}
                        >
                          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                            <input
                              type="checkbox"
                              checked={isChecked}
                              onChange={() => {}}
                              style={{ width: 'auto' }}
                            />
                            <span style={{ fontSize: '13px', fontWeight: isChecked ? 600 : 400 }}>
                              {c.title}
                            </span>
                          </div>
                          <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                            {formatPrice(c.price)}
                          </span>
                        </div>
                      );
                    })}
                  </div>
                </div>

                <div className="form-group" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                  <div>
                    <label>قیمت اصلی تکی (مجموع)</label>
                    <input
                      type="number"
                      value={pkgOriginalPrice || ''}
                      onChange={(e) => setPkgOriginalPrice(parseFloat(e.target.value) || undefined)}
                      placeholder="خودکار محاسبه می‌شود"
                    />
                  </div>
                  <div>
                    <label>قیمت نهایی بسته (تومان) *</label>
                    <input
                      type="number"
                      min="0"
                      value={pkgPrice}
                      onChange={(e) => setPkgPrice(parseFloat(e.target.value) || 0)}
                      required
                    />
                  </div>
                </div>

                <div className="form-group">
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <input
                      type="checkbox"
                      id="pkgPublish"
                      checked={pkgIsPublished}
                      onChange={(e) => setPkgIsPublished(e.target.checked)}
                      style={{ width: 'auto' }}
                    />
                    <label htmlFor="pkgPublish" style={{ margin: 0, cursor: 'pointer' }}>
                      انتشار و نمایش فوری در بخش دوره‌های اپلیکیشن
                    </label>
                  </div>
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-secondary" onClick={() => setShowPackageModal(false)}>
                  انصراف
                </button>
                <button type="submit" className="btn">
                  ذخیره پکیج آموزشی
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
                  {uploading
                    ? uploadProgress !== null
                      ? uploadProgress >= 99
                        ? 'درحال پردازش روی سرور...'
                        : `درحال آپلود (${uploadProgress}%)...`
                      : t('login.verifying', 'Processing...')
                    : t('courses.btn_add')}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Quick Grant Modal */}
      <QuickGrantModal
        isOpen={showQuickGrantModal}
        onClose={() => setShowQuickGrantModal(false)}
        initialType={quickGrantTargetType}
        initialCourseId={quickGrantCourseId}
        initialPackageId={quickGrantPackageId}
        coursesList={courses}
        packagesList={packages}
        onSuccess={() => {
          if (activeTab === 'courses') loadCourses();
          else loadPackages();
        }}
      />
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
