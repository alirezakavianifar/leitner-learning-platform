import React, { useState, useEffect, useRef } from 'react';
import { useTranslation } from 'react-i18next';
import { api } from '../services/api';
import { useToast } from './ToastContext';
import { formatPrice, localizeNumber } from '../i18n';
import type { User } from '../types';

interface QuickGrantModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess?: () => void;
  initialType?: 'COURSE' | 'PACKAGE';
  initialCourseId?: string;
  initialPackageId?: string;
  coursesList?: any[];
  packagesList?: any[];
}

export const QuickGrantModal: React.FC<QuickGrantModalProps> = ({
  isOpen,
  onClose,
  onSuccess,
  initialType = 'COURSE',
  initialCourseId,
  initialPackageId,
  coursesList,
  packagesList
}) => {
  const { t } = useTranslation();
  const toast = useToast();

  const [grantType, setGrantType] = useState<'COURSE' | 'PACKAGE'>(initialType);
  const [mobileNumber, setMobileNumber] = useState('');
  const [selectedCourseId, setSelectedCourseId] = useState(initialCourseId || '');
  const [selectedPackageId, setSelectedPackageId] = useState(initialPackageId || '');
  const [reason, setReason] = useState('');
  const [submitting, setSubmitting] = useState(false);

  // User Autocomplete Suggestions State
  const [suggestedUsers, setSuggestedUsers] = useState<User[]>([]);
  const [isSearchingUsers, setIsSearchingUsers] = useState(false);
  const [showSuggestions, setShowSuggestions] = useState(false);
  const [selectedUserData, setSelectedUserData] = useState<User | null>(null);

  const [availableCourses, setAvailableCourses] = useState<any[]>(coursesList || []);
  const [availablePackages, setAvailablePackages] = useState<any[]>(packagesList || []);
  const [loadingItems, setLoadingItems] = useState(false);

  const suggestionsRef = useRef<HTMLDivElement>(null);
  const searchTimerRef = useRef<any>(null);

  useEffect(() => {
    if (isOpen) {
      setGrantType(initialType);
      setSelectedCourseId(initialCourseId || '');
      setSelectedPackageId(initialPackageId || '');
      setReason('');
      setMobileNumber('');
      setSuggestedUsers([]);
      setSelectedUserData(null);
      setShowSuggestions(false);

      if ((!coursesList || coursesList.length === 0) || (!packagesList || packagesList.length === 0)) {
        loadCatalogs();
      }
    }
  }, [isOpen, initialType, initialCourseId, initialPackageId]);

  // Handle outside click to close suggestions dropdown
  useEffect(() => {
    const handleOutsideClick = (e: MouseEvent) => {
      if (suggestionsRef.current && !suggestionsRef.current.contains(e.target as Node)) {
        setShowSuggestions(false);
      }
    };
    document.addEventListener('mousedown', handleOutsideClick);
    return () => document.removeEventListener('mousedown', handleOutsideClick);
  }, []);

  const loadCatalogs = async () => {
    try {
      setLoadingItems(true);
      const [cRes, pRes] = await Promise.all([
        api.admin.getCourses('', 1, 100, false),
        api.admin.getPackages()
      ]);
      if (cRes.success) setAvailableCourses(cRes.courses || []);
      if (pRes.success) setAvailablePackages(pRes.packages || []);
    } catch {
      // ignore
    } finally {
      setLoadingItems(false);
    }
  };

  // Debounced user search as admin types in mobileNumber input
  const handleMobileChange = (val: string) => {
    setMobileNumber(val);
    if (selectedUserData && selectedUserData.mobile_number !== val) {
      setSelectedUserData(null);
    }

    if (searchTimerRef.current) {
      clearTimeout(searchTimerRef.current);
    }

    const trimmed = val.trim();
    if (trimmed.length < 2) {
      setSuggestedUsers([]);
      setShowSuggestions(false);
      return;
    }

    setShowSuggestions(true);
    setIsSearchingUsers(true);

    searchTimerRef.current = setTimeout(async () => {
      try {
        const res = await api.admin.getUsers(trimmed, 1, 8);
        if (res.success) {
          setSuggestedUsers(res.users || []);
          // If exact match found, auto-tag user data
          const exact = (res.users || []).find(
            (u: User) => u.mobile_number === trimmed || u.mobile_number.replace(/^\+98/, '0') === trimmed
          );
          if (exact) {
            setSelectedUserData(exact);
          }
        }
      } catch {
        setSuggestedUsers([]);
      } finally {
        setIsSearchingUsers(false);
      }
    }, 250);
  };

  const handleSelectUser = (user: User) => {
    setMobileNumber(user.mobile_number);
    setSelectedUserData(user);
    setShowSuggestions(false);
  };

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    const cleanMobile = mobileNumber.trim();
    if (!cleanMobile) {
      toast.showWarning(t('quick_grant.err_mobile_req', 'شماره موبایل کاربر الزامی است.'));
      return;
    }

    if (grantType === 'COURSE' && !selectedCourseId) {
      toast.showWarning(t('quick_grant.err_course_req', 'لطفاً دوره مورد نظر را انتخاب کنید.'));
      return;
    }

    if (grantType === 'PACKAGE' && !selectedPackageId) {
      toast.showWarning(t('quick_grant.err_package_req', 'لطفاً بسته دوره‌ها را انتخاب کنید.'));
      return;
    }

    try {
      setSubmitting(true);
      const res = await api.admin.quickGrantAccess({
        mobile_number: cleanMobile,
        course_id: grantType === 'COURSE' ? selectedCourseId : undefined,
        package_id: grantType === 'PACKAGE' ? selectedPackageId : undefined,
        reason: reason.trim() || 'Admin manual complimentary grant'
      });

      if (res.success) {
        toast.showSuccess(res.message || t('quick_grant.success', 'دسترسی رایگان با موفقیت به کاربر اعطا شد.'));
        onClose();
        if (onSuccess) onSuccess();
      }
    } catch (err: any) {
      toast.showError(err.message || t('quick_grant.error', 'خطا در فعال‌سازی رایگان دوره'));
    } finally {
      setSubmitting(false);
    }
  };

  const selectedCourse = availableCourses.find((c) => c.id === selectedCourseId);
  const selectedPackage = availablePackages.find((p) => p.id === selectedPackageId);

  return (
    <div className="modal-overlay" style={{ zIndex: 1200 }}>
      <div className="modal-content" style={{ maxWidth: '540px', overflow: 'visible' }}>
        <div className="modal-header">
          <div>
            <h3 style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <span style={{ color: 'var(--accent-cyan)' }}>🎁</span>
              {t('quick_grant.title', 'اعطای دسترسی رایگان به کاربر')}
            </h3>
            <p style={{ margin: '4px 0 0', fontSize: '12px', color: 'var(--text-muted)' }}>
              {t('quick_grant.subtitle', 'فعال‌سازی بدون پرداخت یک دوره یا پکیج برای کاربر مشخص')}
            </p>
          </div>
          <button className="refresh-captcha-btn" style={{ fontSize: '20px' }} onClick={onClose}>
            &times;
          </button>
        </div>

        <form onSubmit={handleSubmit} style={{ overflow: 'visible' }}>
          <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '16px', overflow: 'visible' }}>
            {/* Grant Target Type Tabs */}
            <div style={{ display: 'flex', gap: '8px', background: 'rgba(0,0,0,0.2)', padding: '4px', borderRadius: '8px' }}>
              <button
                type="button"
                className={`btn ${grantType === 'COURSE' ? 'btn-primary' : 'btn-secondary'}`}
                style={{ flex: 1, padding: '8px 12px', fontSize: '13px' }}
                onClick={() => setGrantType('COURSE')}
              >
                {t('quick_grant.tab_course', 'تک دوره')}
              </button>
              <button
                type="button"
                className={`btn ${grantType === 'PACKAGE' ? 'btn-primary' : 'btn-secondary'}`}
                style={{ flex: 1, padding: '8px 12px', fontSize: '13px' }}
                onClick={() => setGrantType('PACKAGE')}
              >
                {t('quick_grant.tab_package', 'بسته کامل (پکیج)')}
              </button>
            </div>

            {/* Recipient Mobile Number with Live Suggestions */}
            <div className="form-group" ref={suggestionsRef} style={{ position: 'relative' }}>
              <label style={{ display: 'flex', justifyContent: 'space-between' }}>
                <span>{t('quick_grant.label_mobile', 'شماره همراه کاربر (دریافت‌کننده):')}</span>
                <span style={{ fontSize: '11px', color: 'var(--text-muted)' }}>جستجو با نام یا شماره</span>
              </label>
              
              <div style={{ position: 'relative' }}>
                <input
                  type="text"
                  placeholder={t('quick_grant.placeholder_mobile', 'شماره موبایل یا نام کاربر را تایپ کنید...')}
                  value={mobileNumber}
                  onChange={(e) => handleMobileChange(e.target.value)}
                  onFocus={() => {
                    if (mobileNumber.trim().length >= 2) {
                      setShowSuggestions(true);
                    }
                  }}
                  required
                  autoFocus
                  style={{
                    width: '100%',
                    paddingLeft: '32px',
                    borderColor: selectedUserData ? 'var(--accent-green)' : undefined
                  }}
                />
                
                {isSearchingUsers && (
                  <div style={{ position: 'absolute', left: '10px', top: '50%', transform: 'translateY(-50%)', fontSize: '11px', color: 'var(--accent-cyan)' }}>
                    ⏳
                  </div>
                )}
              </div>

              {/* Suggestions Dropdown */}
              {showSuggestions && mobileNumber.trim().length >= 2 && (
                <div
                  style={{
                    position: 'absolute',
                    top: 'calc(100% + 4px)',
                    left: 0,
                    right: 0,
                    zIndex: 9999,
                    background: '#121829',
                    border: '1px solid var(--border-color)',
                    borderRadius: '8px',
                    boxShadow: '0 12px 30px rgba(0, 0, 0, 0.6)',
                    maxHeight: '220px',
                    overflowY: 'auto'
                  }}
                >
                  <div style={{ padding: '6px 12px', fontSize: '11px', color: 'var(--text-muted)', borderBottom: '1px solid rgba(255,255,255,0.05)', background: 'rgba(0,0,0,0.2)' }}>
                    {t('quick_grant.suggestions_title', 'کاربران پیشنهادی:')}
                  </div>

                  {isSearchingUsers ? (
                    <div style={{ padding: '12px', fontSize: '12px', textAlign: 'center', color: 'var(--text-muted)' }}>
                      {t('quick_grant.searching_users', 'در حال جستجوی کاربران...')}
                    </div>
                  ) : suggestedUsers.length === 0 ? (
                    <div style={{ padding: '12px', fontSize: '12px', textAlign: 'center', color: 'var(--text-muted)' }}>
                      {t('quick_grant.no_users_found', 'کاربری با این مشخصات یافت نشد')}
                    </div>
                  ) : (
                    suggestedUsers.map((user) => (
                      <div
                        key={user.id}
                        onClick={() => handleSelectUser(user)}
                        style={{
                          padding: '10px 12px',
                          display: 'flex',
                          justifyContent: 'space-between',
                          alignItems: 'center',
                          cursor: 'pointer',
                          borderBottom: '1px solid rgba(255,255,255,0.03)',
                          transition: 'background 0.15s ease'
                        }}
                        onMouseEnter={(e) => (e.currentTarget.style.background = 'rgba(99, 102, 241, 0.15)')}
                        onMouseLeave={(e) => (e.currentTarget.style.background = 'transparent')}
                      >
                        <div>
                          <div style={{ fontWeight: 600, fontSize: '13px', color: 'var(--text-inverse)', display: 'flex', alignItems: 'center', gap: '6px' }}>
                            <span>👤 {user.username}</span>
                            {user.is_admin && (
                              <span className="badge admin" style={{ fontSize: '9px', padding: '1px 4px' }}>ادمین</span>
                            )}
                          </div>
                          <div style={{ fontSize: '11px', color: 'var(--accent-cyan)', marginTop: '2px', direction: 'ltr', textAlign: 'right' }}>
                            {user.mobile_number}
                          </div>
                        </div>

                        <button
                          type="button"
                          className="btn btn-secondary"
                          style={{ padding: '4px 8px', fontSize: '11px', pointerEvents: 'none' }}
                        >
                          انتخاب
                        </button>
                      </div>
                    ))
                  )}
                </div>
              )}

              {/* Verified User Info Pill */}
              {selectedUserData && (
                <div
                  style={{
                    marginTop: '6px',
                    padding: '6px 12px',
                    borderRadius: '6px',
                    background: 'rgba(16, 185, 129, 0.1)',
                    border: '1px solid rgba(16, 185, 129, 0.3)',
                    display: 'flex',
                    justifyContent: 'space-between',
                    alignItems: 'center',
                    fontSize: '12px',
                    color: '#10b981'
                  }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                    <span>✅</span>
                    <span>
                      {t('quick_grant.user_selected', 'کاربر انتخاب‌شده:')} <strong>{selectedUserData.username}</strong> ({selectedUserData.mobile_number})
                    </span>
                  </div>
                  <span style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
                    عضویت: {localizeNumber(new Date(selectedUserData.created_at).toLocaleDateString())}
                  </span>
                </div>
              )}
            </div>

            {/* Course or Package Selector */}
            {grantType === 'COURSE' ? (
              <div className="form-group">
                <label>{t('quick_grant.label_course', 'دوره مورد نظر:')}</label>
                <select
                  value={selectedCourseId}
                  onChange={(e) => setSelectedCourseId(e.target.value)}
                  required
                  disabled={loadingItems}
                  style={{ width: '100%', padding: '10px', background: 'var(--bg-card)', border: '1px solid var(--border-color)', borderRadius: '6px', color: 'var(--text-main)' }}
                >
                  <option value="">{t('quick_grant.select_course', '-- انتخاب دوره --')}</option>
                  {availableCourses.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.title} ({c.price > 0 ? `${formatPrice(c.price)} تومان` : 'رایگان'})
                    </option>
                  ))}
                </select>
                {selectedCourse && (
                  <div style={{ marginTop: '6px', fontSize: '12px', color: 'var(--accent-cyan)' }}>
                    قیمت اصلی دوره: {selectedCourse.price > 0 ? `${formatPrice(selectedCourse.price)} تومان` : 'رایگان'} — کارت‌ها: {selectedCourse.card_count}
                  </div>
                )}
              </div>
            ) : (
              <div className="form-group">
                <label>{t('quick_grant.label_package', 'بسته دوره‌های مورد نظر:')}</label>
                <select
                  value={selectedPackageId}
                  onChange={(e) => setSelectedPackageId(e.target.value)}
                  required
                  disabled={loadingItems}
                  style={{ width: '100%', padding: '10px', background: 'var(--bg-card)', border: '1px solid var(--border-color)', borderRadius: '6px', color: 'var(--text-main)' }}
                >
                  <option value="">{t('quick_grant.select_package', '-- انتخاب پکیج --')}</option>
                  {availablePackages.map((p) => (
                    <option key={p.id} value={p.id}>
                      {p.title} ({formatPrice(p.price)} تومان - شامل {p.courses?.length || 0} دوره)
                    </option>
                  ))}
                </select>
                {selectedPackage && (
                  <div style={{ marginTop: '6px', fontSize: '12px', color: 'var(--accent-cyan)' }}>
                    قیمت پکیج: {formatPrice(selectedPackage.price)} تومان — شامل دوره‌های: {selectedPackage.courses?.map((c: any) => c.title).join('، ')}
                  </div>
                )}
              </div>
            )}

            {/* Reason / Admin Note */}
            <div className="form-group">
              <label>{t('quick_grant.label_reason', 'علت اعطای دسترسی رایگان (جهت ثبت در سیستم نظارت):')}</label>
              <textarea
                rows={2}
                placeholder={t('quick_grant.placeholder_reason', 'مثال: هدیه عضویت ویژه، دانشجو ممتاز، جبران اختلال شبکه، هماهنگی پشتیبانی...')}
                value={reason}
                onChange={(e) => setReason(e.target.value)}
              />
            </div>
          </div>

          <div className="modal-footer">
            <button type="button" className="btn btn-secondary" onClick={onClose} disabled={submitting}>
              {t('courses.btn_cancel', 'انصراف')}
            </button>
            <button type="submit" className="btn btn-success" disabled={submitting}>
              {submitting ? t('login.verifying', 'در حال ثبت...') : t('quick_grant.btn_submit', 'تایید و اعطای دسترسی رایگان')}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
