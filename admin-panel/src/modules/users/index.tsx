import React, { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { localizeNumber, formatPrice } from '../../i18n';
import { api } from '../../services/api';
import type { User, AdminModule } from '../../types';
import { useToast } from '../../components/ToastContext';
import { QuickGrantModal } from '../../components/QuickGrantModal';

export const UsersView: React.FC = () => {
  const { t } = useTranslation();
  const toast = useToast();

  const [users, setUsers] = useState<User[]>([]);
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [totalCount, setTotalCount] = useState(0);
  const [loading, setLoading] = useState(true);

  // Selected User Modal State
  const [selectedUser, setSelectedUser] = useState<any>(null);
  const [purchases, setPurchases] = useState<any[]>([]);
  const [packagePurchases, setPackagePurchases] = useState<any[]>([]);
  const [courses, setCourses] = useState<any[]>([]);
  const [packages, setPackages] = useState<any[]>([]);
  const [showEditModal, setShowEditModal] = useState(false);
  const [accessTab, setAccessTab] = useState<'courses' | 'packages'>('courses');
  const [courseFilter, setCourseFilter] = useState('');

  // Quick Grant Modal State
  const [showQuickGrantModal, setShowQuickGrantModal] = useState(false);

  // User profile edit form fields
  const [editUsername, setEditUsername] = useState('');
  const [editInterests, setEditInterests] = useState('');
  const [editField, setEditField] = useState('');
  const [editLevel, setEditLevel] = useState('');
  const [editIsAdmin, setEditIsAdmin] = useState(false);

  // Manual course/package toggle form fields
  const [showToggleModal, setShowToggleModal] = useState(false);
  const [targetItem, setTargetItem] = useState<any>(null);
  const [targetItemType, setTargetItemType] = useState<'COURSE' | 'PACKAGE'>('COURSE');
  const [grantState, setGrantState] = useState(true);
  const [overrideReason, setOverrideReason] = useState('');

  const loadUsers = async () => {
    try {
      setLoading(true);
      const res = await api.admin.getUsers(search, page, 10);
      setUsers(res.users);
      setTotalCount(res.total_count);
    } catch (err: any) {
      toast.showError(err.message || 'خطا در دریافت لیست کاربران');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadUsers();
  }, [page, search]);

  const handleSearchSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setPage(1);
  };

  const handleOpenEdit = async (user: User) => {
    try {
      const [res, coursesRes, packagesRes] = await Promise.all([
        api.admin.getUser(user.id),
        api.admin.getCourses(undefined, 1, 100),
        api.admin.getPackages()
      ]);

      if (res.success) {
        setSelectedUser(res.user);
        setEditUsername(res.user.username || '');
        setEditInterests(res.user.interests || '');
        setEditField(res.user.educational_field || '');
        setEditLevel(res.user.educational_level || '');
        setEditIsAdmin(res.user.is_admin || false);
        setPurchases(res.purchases || []);
        setPackagePurchases((res as any).package_purchases || []);
        if (coursesRes.success) setCourses(coursesRes.courses || []);
        if (packagesRes.success) setPackages(packagesRes.packages || []);
        setCourseFilter('');
        setAccessTab('courses');
        setShowEditModal(true);
      }
    } catch (err: any) {
      toast.showError('خطا در دریافت اطلاعات کاربر');
    }
  };

  const handleProfileSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedUser) return;
    try {
      const res = await api.admin.updateUser(selectedUser.id, {
        username: editUsername,
        interests: editInterests,
        educational_field: editField,
        educational_level: editLevel,
        is_admin: editIsAdmin
      });
      if (res.success) {
        toast.showSuccess('اطلاعات کاربر با موفقیت بروزرسانی شد.');
        setShowEditModal(false);
        loadUsers();
      }
    } catch (err: any) {
      toast.showError(err.message || 'خطا در ثبت تغییرات پروفایل.');
    }
  };

  const openCourseToggle = (course: any, isCurrentlyPurchased: boolean) => {
    setTargetItem(course);
    setTargetItemType('COURSE');
    setGrantState(!isCurrentlyPurchased);
    setOverrideReason('');
    setShowToggleModal(true);
  };

  const openPackageToggle = (pkg: any, isCurrentlyPurchased: boolean) => {
    setTargetItem(pkg);
    setTargetItemType('PACKAGE');
    setGrantState(!isCurrentlyPurchased);
    setOverrideReason('');
    setShowToggleModal(true);
  };

  const handleToggleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedUser || !targetItem) return;
    if (!overrideReason.trim()) {
      toast.showWarning('ثبت دلیل تغییر دسترسی جهت ثبت در سیستم نظارت الزامی است.');
      return;
    }

    try {
      if (targetItemType === 'COURSE') {
        const res = await api.admin.toggleCourseAccess(
          selectedUser.id,
          targetItem.id,
          grantState,
          overrideReason
        );
        if (res.success) {
          toast.showSuccess(grantState ? 'دسترسی دوره با موفقیت اعطا شد!' : 'دسترسی دوره با موفقیت لغو شد!');
        }
      } else {
        const res = await api.admin.togglePackageAccess(
          selectedUser.id,
          targetItem.id,
          grantState,
          overrideReason
        );
        if (res.success) {
          toast.showSuccess(grantState ? 'دسترسی بسته و کلیه دوره‌های آن اعطا شد!' : 'دسترسی بسته لغو شد!');
        }
      }

      setShowToggleModal(false);

      // Reload user access states
      const userData = await api.admin.getUser(selectedUser.id);
      if (userData.success) {
        setPurchases(userData.purchases || []);
        setPackagePurchases((userData as any).package_purchases || []);
      }
    } catch (err: any) {
      toast.showError(err.message || 'خطا در تغییر دسترسی.');
    }
  };

  const filteredCourses = courses.filter((c) =>
    c.title.toLowerCase().includes(courseFilter.toLowerCase()) ||
    (c.category && c.category.toLowerCase().includes(courseFilter.toLowerCase()))
  );

  return (
    <div>
      <div className="table-container">
        <div className="table-header" style={{ flexWrap: 'wrap', gap: '16px' }}>
          <div>
            <h2 style={{ margin: 0 }}>{t('users.title')}</h2>
            <p style={{ margin: '4px 0 0', color: 'var(--text-muted)', fontSize: '13px' }}>
              مشاهده اطلاعات دانشجویان، ویرایش دسترسی‌ها و اعطای رایگان دوره‌ها
            </p>
          </div>

          <div style={{ display: 'flex', gap: '12px', alignItems: 'center' }}>
            <button
              type="button"
              className="btn btn-primary"
              onClick={() => setShowQuickGrantModal(true)}
              style={{ display: 'flex', alignItems: 'center', gap: '8px' }}
            >
              <span>🎁</span>
              <span>{t('quick_grant.btn_open', 'اعطای رایگان دوره / پکیج')}</span>
            </button>

            <form onSubmit={handleSearchSubmit} style={{ display: 'flex', gap: '8px' }}>
              <input
                type="text"
                placeholder={t('users.search_placeholder')}
                className="search-input"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
              <button type="submit" className="btn">{t('users.search_btn', 'Search')}</button>
            </form>
          </div>
        </div>

        {loading ? (
          <div className="text-center p-24">{t('login.verifying', 'Loading...')}</div>
        ) : (
          <table className="data-table">
            <thead>
              <tr>
                <th>{t('users.field_username')}</th>
                <th>{t('users.th_mobile')}</th>
                <th>{t('users.role', 'Role')}</th>
                <th>{t('users.th_joined')}</th>
                <th>{t('users.th_actions')}</th>
              </tr>
            </thead>
            <tbody>
              {users.length === 0 ? (
                <tr>
                  <td colSpan={5} className="text-center text-muted">{t('users.no_users', 'No users found.')}</td>
                </tr>
              ) : (
                users.map((user) => (
                  <tr key={user.id}>
                    <td>
                      <div style={{ fontWeight: 600, color: 'var(--text-inverse)' }}>{user.username}</div>
                    </td>
                    <td>{localizeNumber(user.mobile_number)}</td>
                    <td>
                      <span className={`badge ${user.is_admin ? 'admin' : 'student'}`}>
                        {user.is_admin ? t('system_admin') : t('login.role_student', 'Student')}
                      </span>
                    </td>
                    <td>{localizeNumber(new Date(user.created_at).toLocaleDateString())}</td>
                    <td>
                      <button className="btn btn-secondary" onClick={() => handleOpenEdit(user)}>
                        {t('users.btn_view_profile', 'Manage Access')}
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        )}

        <div style={{ padding: '16px 24px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderTop: '1px solid var(--border-color)' }}>
          <div className="stat-label">{t('users.total') || 'Total'}: {localizeNumber(totalCount)}</div>
          <div style={{ display: 'flex', gap: '8px' }}>
            <button className="btn btn-secondary" disabled={page === 1} onClick={() => setPage(page - 1)}>
              {t('users.prev', 'Prev')}
            </button>
            <button className="btn btn-secondary" disabled={page * 10 >= totalCount} onClick={() => setPage(page + 1)}>
              {t('users.next', 'Next')}
            </button>
          </div>
        </div>
      </div>

      {/* User Details & Access Modal */}
      {showEditModal && selectedUser && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '850px' }}>
            <div className="modal-header">
              <h3>{t('users.modal_title')}: {selectedUser.username}</h3>
              <button className="refresh-captcha-btn" style={{ fontSize: '20px' }} onClick={() => setShowEditModal(false)}>&times;</button>
            </div>
            
            <div className="modal-body" style={{ display: 'grid', gridTemplateColumns: '1fr 1.3fr', gap: '24px' }}>
              {/* Profile Details Form */}
              <form onSubmit={handleProfileSubmit}>
                <h4 style={{ marginBottom: '16px', color: 'var(--primary-hover)' }}>{t('users.modal_title')}</h4>
                
                <div className="form-group">
                  <label>{t('users.field_mobile')}</label>
                  <input type="text" value={localizeNumber(selectedUser.mobile_number)} disabled style={{ opacity: 0.6 }} />
                </div>
                
                <div className="form-group">
                  <label>{t('users.field_username')}</label>
                  <input type="text" value={editUsername} onChange={(e) => setEditUsername(e.target.value)} required />
                </div>
                
                <div className="form-group">
                  <label>{t('users.field_interests')}</label>
                  <input type="text" value={editInterests} onChange={(e) => setEditInterests(e.target.value)} />
                </div>
                
                <div className="form-group">
                  <label>{t('users.field_field')}</label>
                  <input type="text" value={editField} onChange={(e) => setEditField(e.target.value)} />
                </div>
                
                <div className="form-group">
                  <label>{t('users.field_level')}</label>
                  <input type="text" value={editLevel} onChange={(e) => setEditLevel(e.target.value)} />
                </div>
                
                <div className="form-group" style={{ display: 'flex', alignItems: 'center', gap: '8px', marginTop: '12px' }}>
                  <input
                    type="checkbox"
                    id="isAdminCheck"
                    checked={editIsAdmin}
                    onChange={(e) => setEditIsAdmin(e.target.checked)}
                    style={{ width: 'auto' }}
                  />
                  <label htmlFor="isAdminCheck" style={{ margin: 0, cursor: 'pointer' }}>{t('users.grant_admin', 'Grant Admin Privileges')}</label>
                </div>
                
                <button type="submit" className="btn" style={{ width: '100%', marginTop: '20px' }}>
                  {t('courses.btn_save', 'Save Changes')}
                </button>
              </form>

              {/* Course & Package Access Matrix */}
              <div>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' }}>
                  <h4 style={{ margin: 0, color: 'var(--accent-cyan)' }}>مدیریت دسترسی‌های کاربر</h4>
                  <div style={{ display: 'flex', gap: '4px', background: 'rgba(0,0,0,0.2)', padding: '2px', borderRadius: '6px' }}>
                    <button
                      type="button"
                      className={`btn ${accessTab === 'courses' ? 'btn-primary' : 'btn-secondary'}`}
                      style={{ padding: '4px 10px', fontSize: '11px' }}
                      onClick={() => setAccessTab('courses')}
                    >
                      دوره‌ها ({purchases.filter(p => p.status === 'COMPLETED').length})
                    </button>
                    <button
                      type="button"
                      className={`btn ${accessTab === 'packages' ? 'btn-primary' : 'btn-secondary'}`}
                      style={{ padding: '4px 10px', fontSize: '11px' }}
                      onClick={() => setAccessTab('packages')}
                    >
                      بسته‌ها ({packagePurchases.filter(p => p.status === 'COMPLETED').length})
                    </button>
                  </div>
                </div>

                {accessTab === 'courses' ? (
                  <div>
                    <input
                      type="text"
                      placeholder="جستجوی دوره برای فعال‌سازی..."
                      value={courseFilter}
                      onChange={(e) => setCourseFilter(e.target.value)}
                      style={{ width: '100%', padding: '8px 12px', fontSize: '12px', marginBottom: '12px', borderRadius: '6px' }}
                    />
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', maxHeight: '320px', overflowY: 'auto', paddingRight: '4px' }}>
                      {filteredCourses.length === 0 ? (
                        <div className="text-muted" style={{ fontStyle: 'italic', fontSize: '13px', textAlign: 'center', padding: '16px' }}>
                          دوره‌ای یافت نشد.
                        </div>
                      ) : (
                        filteredCourses.map((course) => {
                          const purchase = purchases.find((p) => p.course_id === course.id);
                          const isPurchased = purchase && purchase.status === 'COMPLETED';
                          const isDirectGrant = purchase && (purchase.payment_provider === 'ADMIN_GRANT' || purchase.payment_provider === 'DIRECT');
                          
                          return (
                            <div
                              key={course.id}
                              style={{
                                display: 'flex',
                                justifyContent: 'space-between',
                                alignItems: 'center',
                                padding: '10px 12px',
                                border: '1px solid var(--border-color)',
                                borderRadius: '8px',
                                background: isPurchased ? 'rgba(46, 204, 113, 0.05)' : 'rgba(0, 0, 0, 0.15)'
                              }}
                            >
                              <div style={{ marginRight: '8px', flex: 1 }}>
                                <div style={{ fontWeight: 600, fontSize: '13px' }}>{course.title}</div>
                                <div style={{ fontSize: '11px', color: 'var(--text-muted)', display: 'flex', gap: '8px', alignItems: 'center', marginTop: '2px' }}>
                                  <span>{course.price === 0 ? t('courses.status_free') : `${formatPrice(course.price)} ${t('courses.irr', 'Toman')}`}</span>
                                  {isPurchased && isDirectGrant && (
                                    <span className="badge" style={{ background: 'rgba(52, 152, 219, 0.2)', color: '#3498db', fontSize: '10px' }}>
                                      🎁 {t('quick_grant.provider_admin_grant', 'هدیه ادمین')}
                                    </span>
                                  )}
                                </div>
                              </div>
                              <button
                                className={`btn ${isPurchased ? 'btn-danger' : 'btn-success'}`}
                                style={{ padding: '6px 12px', fontSize: '12px', whiteSpace: 'nowrap' }}
                                onClick={() => openCourseToggle(course, !!isPurchased)}
                              >
                                {isPurchased ? t('users.btn_revoke', 'Revoke') : t('users.btn_grant', 'Grant Free')}
                              </button>
                            </div>
                          );
                        })
                      )}
                    </div>
                  </div>
                ) : (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', maxHeight: '350px', overflowY: 'auto', paddingRight: '4px' }}>
                    {packages.length === 0 ? (
                      <div className="text-muted" style={{ fontStyle: 'italic', fontSize: '13px', textAlign: 'center', padding: '16px' }}>
                        هیچ پکیجی تعریف نشده است.
                      </div>
                    ) : (
                      packages.map((pkg) => {
                        const pkgPurchase = packagePurchases.find((p) => p.package_id === pkg.id);
                        const isPurchased = pkgPurchase && pkgPurchase.status === 'COMPLETED';
                        
                        return (
                          <div
                            key={pkg.id}
                            style={{
                              display: 'flex',
                              justifyContent: 'space-between',
                              alignItems: 'center',
                              padding: '10px 12px',
                              border: '1px solid var(--border-color)',
                              borderRadius: '8px',
                              background: isPurchased ? 'rgba(46, 204, 113, 0.05)' : 'rgba(0, 0, 0, 0.15)'
                            }}
                          >
                            <div style={{ marginRight: '8px', flex: 1 }}>
                              <div style={{ fontWeight: 600, fontSize: '13px' }}>{pkg.title}</div>
                              <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
                                {formatPrice(pkg.price)} تومان — شامل {pkg.courses?.length || 0} دوره
                              </div>
                            </div>
                            <button
                              className={`btn ${isPurchased ? 'btn-danger' : 'btn-success'}`}
                              style={{ padding: '6px 12px', fontSize: '12px', whiteSpace: 'nowrap' }}
                              onClick={() => openPackageToggle(pkg, !!isPurchased)}
                            >
                              {isPurchased ? 'لغو دسترسی پکیج' : 'اعطای کامل پکیج'}
                            </button>
                          </div>
                        );
                      })
                    )}
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Manual Grant/Revoke Prompt Modal */}
      {showToggleModal && targetItem && (
        <div className="modal-overlay" style={{ zIndex: 1250 }}>
          <div className="modal-content" style={{ maxWidth: '450px' }}>
            <div className="modal-header">
              <h3>{t('users.confirm_override_title', 'Confirm Manual Override')}</h3>
              <button className="refresh-captcha-btn" style={{ fontSize: '20px' }} onClick={() => setShowToggleModal(false)}>&times;</button>
            </div>
            <form onSubmit={handleToggleSubmit}>
              <div className="modal-body">
                <p style={{ fontSize: '14px', marginBottom: '16px' }}>
                  {t('users.override_desc_1', 'You are about to')} <strong>{grantState ? t('users.btn_grant') : t('users.btn_revoke')}</strong> {t('users.override_desc_2', 'access to the item:')}
                  <br />
                  <span style={{ color: 'var(--primary-hover)', fontWeight: 600 }}>{targetItem.title}</span>
                </p>
                <div className="form-group">
                  <label>{t('users.audit_reason_label', 'Reason for auditing (Required)')}</label>
                  <textarea
                    rows={3}
                    placeholder={t('users.audit_reason_placeholder', 'Provide override reason details...')}
                    value={overrideReason}
                    onChange={(e) => setOverrideReason(e.target.value)}
                    required
                  ></textarea>
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-secondary" onClick={() => setShowToggleModal(false)}>
                  {t('courses.btn_cancel', 'Cancel')}
                </button>
                <button type="submit" className={`btn ${grantState ? 'btn-success' : 'btn-danger'}`}>
                  {t('users.confirm_override_btn', 'Confirm Override')}
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
        onSuccess={() => {
          loadUsers();
        }}
      />
    </div>
  );
};

export const UsersModule: AdminModule = {
  id: 'users',
  name: 'Users',
  icon: (props) => (
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...props}>
      <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
      <circle cx="9" cy="7" r="4" />
      <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
      <path d="M16 3.13a4 4 0 0 1 0 7.75" />
    </svg>
  ),
  component: UsersView
};
