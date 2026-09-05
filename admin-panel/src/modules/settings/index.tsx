import React, { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { api } from '../../services/api';
import type { AdminModule } from '../../types';
import { useToast } from '../../components/ToastContext';

export const SettingsView: React.FC = () => {
  const { t } = useTranslation();
  const toast = useToast();
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  // States for system settings
  const [maintenanceMode, setMaintenanceMode] = useState(false);
  const [apiServer, setApiServer] = useState('');
  const [contentServer, setContentServer] = useState('');
  const [bannerServer, setBannerServer] = useState('');
  
  const [enableAiTutor, setEnableAiTutor] = useState(false);
  const [enableCustomThemes, setEnableCustomThemes] = useState(true);
  const [enableSearchV2, setEnableSearchV2] = useState(true);
  const [enableGamifiedLayout, setEnableGamifiedLayout] = useState(true);
  const [enableScreenshotProtection, setEnableScreenshotProtection] = useState(true);

  const [rotationInterval, setRotationInterval] = useState(4);
  const [maxBannerCount, setMaxBannerCount] = useState(5);
  const [cardNavIconStyle, setCardNavIconStyle] = useState('chevron');
  const [globalIconScale, setGlobalIconScale] = useState(1.0);
  const [cardNavIconSize, setCardNavIconSize] = useState(20);
  const [bottomNavIconSize, setBottomNavIconSize] = useState(26);
  const [appBarIconSize, setAppBarIconSize] = useState(24);
  const [appLogoSize, setAppLogoSize] = useState(110);
  const [appLogoUrl, setAppLogoUrl] = useState('');
  const [uploadingLogo, setUploadingLogo] = useState(false);

  // States for Authentication & Session Validity
  const [jwtLifetimeValue, setJwtLifetimeValue] = useState(1);
  const [jwtLifetimeUnit, setJwtLifetimeUnit] = useState('days');
  const [refreshTokenLifetimeValue, setRefreshTokenLifetimeValue] = useState(30);
  const [refreshTokenLifetimeUnit, setRefreshTokenLifetimeUnit] = useState('days');
  const [enableAutoTokenRefresh, setEnableAutoTokenRefresh] = useState(true);

  // States for Social Messengers & Support
  const [telegramUrl, setTelegramUrl] = useState('https://t.me/RightlearnApp');
  const [baleUrl, setBaleUrl] = useState('https://ble.ir/rightlearnapp');
  const [eitaaUrl, setEitaaUrl] = useState('https://eitaa.com/RightLearnApp');
  const [supportUrl, setSupportUrl] = useState('https://t.me/RLAppSupport');
  const [supportId, setSupportId] = useState('@RLAppSupport');

  // States for Leitner Spaced Repetition Stage Intervals
  const [leitnerBox2Interval, setLeitnerBox2Interval] = useState(3);
  const [leitnerBox3Interval, setLeitnerBox3Interval] = useState(7);
  const [leitnerBox4Interval, setLeitnerBox4Interval] = useState(16);
  const [leitnerBox5Interval, setLeitnerBox5Interval] = useState(31);
  const [leitnerIntervalUnit, setLeitnerIntervalUnit] = useState('days');

  // States for Daily Study Reminders & Notification Schedule
  const [dailyReminderHour, setDailyReminderHour] = useState(9);
  const [dailyReminderMinute, setDailyReminderMinute] = useState(0);
  const [enableDailyReminder, setEnableDailyReminder] = useState(true);

  // States for Admin Login Security & Emergency Access
  const [adminAllowedMobilesList, setAdminAllowedMobilesList] = useState<string[]>(['09120000000', '+989120000000']);
  const [newMobileInput, setNewMobileInput] = useState('');
  const [mobileInputError, setMobileInputError] = useState('');
  const [adminEmergencyBypassEnabled, setAdminEmergencyBypassEnabled] = useState(true);

  const [savingSecurity, setSavingSecurity] = useState(false);

  // Helper functions for mobile number handling and validation
  const toEnglishDigits = (str: string): string => {
    return str
      .replace(/[۰-۹]/g, (d) => '۰۱۲۳۴۵۶۷۸۹'.indexOf(d).toString())
      .replace(/[٠-٩]/g, (d) => '٠١٢٣٤٥٦٧۸۹'.indexOf(d).toString())
      .replace(/[\s\-_()]/g, '');
  };

  const normalizePhone = (phone: string): string => {
    let clean = toEnglishDigits(phone);
    if (clean.startsWith('+98')) clean = '0' + clean.slice(3);
    else if (clean.startsWith('0098')) clean = '0' + clean.slice(4);
    else if (clean.startsWith('98')) clean = '0' + clean.slice(2);
    else if (clean.length === 10 && clean.startsWith('9')) clean = '0' + clean;
    return clean;
  };

  const isValidMobile = (phone: string): boolean => {
    const clean = toEnglishDigits(phone);
    // Standard Iranian mobile: 09XXXXXXXXX (11 digits) or +989XXXXXXXXX or 00989XXXXXXXXX
    return /^(\+98|0098|98|0)?9\d{9}$/.test(clean);
  };

  const persistSecurityConfig = async (mobiles: string[], bypassEnabled: boolean) => {
    try {
      setSavingSecurity(true);
      await api.admin.updateConfig([
        { key: 'admin_allowed_mobile_numbers', value: mobiles.join(', ') },
        { key: 'admin_emergency_bypass_enabled', value: bypassEnabled.toString() }
      ]);
      return true;
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      toast.showError(msg || t('settings.save_failed', 'Failed to save security settings.'));
      return false;
    } finally {
      setSavingSecurity(false);
    }
  };

  const handleAddMobile = async () => {
    const raw = newMobileInput.trim();
    if (!raw) {
      setMobileInputError(t('settings.error_mobile_empty', 'لطفا شماره موبایل را وارد کنید.'));
      return;
    }

    const clean = toEnglishDigits(raw);
    if (!isValidMobile(clean)) {
      setMobileInputError(t('settings.error_mobile_invalid', 'فرمت شماره موبایل نامعتبر است. نمونه صحیح: 09123456789 یا +989123456789 (۱۱ رقم)'));
      return;
    }

    const normalized = normalizePhone(clean);
    if (adminAllowedMobilesList.some((m) => normalizePhone(m) === normalized)) {
      setMobileInputError(t('settings.error_mobile_duplicate', 'این شماره قبلاً در لیست ثبت شده است.'));
      return;
    }

    // Format consistently: if started with +, keep +98..., otherwise store standard 09...
    const formatted = clean.startsWith('+') ? clean : (clean.startsWith('0') ? clean : '0' + clean);
    const updatedList = [...adminAllowedMobilesList, formatted];
    setAdminAllowedMobilesList(updatedList);
    setNewMobileInput('');
    setMobileInputError('');

    // Immediately persist to server so it is never lost
    const ok = await persistSecurityConfig(updatedList, adminEmergencyBypassEnabled);
    if (ok) {
      toast.showSuccess(t('settings.mobile_added_toast', `شماره ${formatted} با موفقیت افزوده و در سرور ذخیره شد.`));
    }
  };

  const handleRemoveMobile = async (indexToRemove: number) => {
    const updatedList = adminAllowedMobilesList.filter((_, idx) => idx !== indexToRemove);
    if (updatedList.length === 0 && !adminEmergencyBypassEnabled) {
      toast.showError(t('settings.error_lockout_risk', 'حداقل یک شماره موبایل باید ثبت شود یا کد اضطراری فعال باشد.'));
      return;
    }

    const removedNumber = adminAllowedMobilesList[indexToRemove];
    setAdminAllowedMobilesList(updatedList);

    // Immediately persist to server
    const ok = await persistSecurityConfig(updatedList, adminEmergencyBypassEnabled);
    if (ok) {
      toast.showSuccess(t('settings.mobile_removed_toast', `شماره ${removedNumber} با موفقیت حذف و تغییرات در سرور ذخیره شد.`));
    }
  };

  const handleToggleEmergencyBypass = async (enabled: boolean) => {
    if (!enabled && adminAllowedMobilesList.length === 0) {
      toast.showError(t('settings.error_lockout_risk', 'حداقل یک شماره موبایل باید ثبت شود یا کد اضطراری فعال باشد.'));
      return;
    }

    setAdminEmergencyBypassEnabled(enabled);
    const ok = await persistSecurityConfig(adminAllowedMobilesList, enabled);
    if (ok) {
      toast.showSuccess(enabled ? 'کد اضطراری ۱۲۳۴۵ برای شماره‌های مجاز فعال شد.' : 'کد اضطراری ۱۲۳۴۵ غیرفعال شد.');
    }
  };

  const applyReminderPreset = (hour: number, minute: number = 0) => {
    setDailyReminderHour(hour);
    setDailyReminderMinute(minute);
    setEnableDailyReminder(true);
  };

  const applyIconScalePreset = (scale: number) => {
    setGlobalIconScale(scale);
    if (scale === 0.85) {
      setCardNavIconSize(16);
      setBottomNavIconSize(22);
      setAppBarIconSize(20);
      setAppLogoSize(90);
    } else if (scale === 1.0) {
      setCardNavIconSize(20);
      setBottomNavIconSize(26);
      setAppBarIconSize(24);
      setAppLogoSize(110);
    } else if (scale === 1.15) {
      setCardNavIconSize(24);
      setBottomNavIconSize(30);
      setAppBarIconSize(28);
      setAppLogoSize(130);
    } else if (scale === 1.3) {
      setCardNavIconSize(28);
      setBottomNavIconSize(34);
      setAppBarIconSize(32);
      setAppLogoSize(150);
    }
  };

  const applyLeitnerPreset = (preset: 'standard' | 'fast_hour' | 'fast_10m') => {
    if (preset === 'standard') {
      setLeitnerBox2Interval(3);
      setLeitnerBox3Interval(7);
      setLeitnerBox4Interval(16);
      setLeitnerBox5Interval(31);
      setLeitnerIntervalUnit('days');
    } else if (preset === 'fast_hour') {
      setLeitnerBox2Interval(5);
      setLeitnerBox3Interval(10);
      setLeitnerBox4Interval(15);
      setLeitnerBox5Interval(20);
      setLeitnerIntervalUnit('minutes');
    } else if (preset === 'fast_10m') {
      setLeitnerBox2Interval(1);
      setLeitnerBox3Interval(2);
      setLeitnerBox4Interval(3);
      setLeitnerBox5Interval(4);
      setLeitnerIntervalUnit('minutes');
    }
  };

  const loadSettings = async () => {
    try {
      setLoading(true);
      const res = await api.admin.getConfig();
      if (res && res.success && Array.isArray(res.configs)) {
        res.configs.forEach((cfg: { key: string; value: string }) => {
          switch (cfg.key) {
            case 'maintenance_mode':
              setMaintenanceMode(cfg.value === 'true');
              break;
            case 'api_server':
              setApiServer(cfg.value);
              break;
            case 'content_server':
              setContentServer(cfg.value);
              break;
            case 'banner_server':
              setBannerServer(cfg.value);
              break;
            case 'enable_ai_tutor':
              setEnableAiTutor(cfg.value === 'true');
              break;
            case 'enable_custom_themes':
              setEnableCustomThemes(cfg.value !== 'false');
              break;
            case 'enable_search_v2':
              setEnableSearchV2(cfg.value !== 'false');
              break;
            case 'enable_gamified_layout':
              setEnableGamifiedLayout(cfg.value !== 'false');
              break;
            case 'enable_screenshot_protection':
              setEnableScreenshotProtection(cfg.value !== 'false');
              break;
            case 'rotation_interval_seconds':
              setRotationInterval(parseInt(cfg.value) || 4);
              break;
            case 'max_banner_count':
              setMaxBannerCount(parseInt(cfg.value) || 5);
              break;
            case 'card_nav_icon_style':
              setCardNavIconStyle(cfg.value || 'chevron');
              break;
            case 'global_icon_scale':
              setGlobalIconScale(parseFloat(cfg.value) || 1.0);
              break;
            case 'card_nav_icon_size':
              setCardNavIconSize(parseInt(cfg.value) || 20);
              break;
            case 'bottom_nav_icon_size':
              setBottomNavIconSize(parseInt(cfg.value) || 26);
              break;
            case 'app_bar_icon_size':
              setAppBarIconSize(parseInt(cfg.value) || 24);
              break;
            case 'app_logo_size':
              setAppLogoSize(parseInt(cfg.value) || 110);
              break;
            case 'app_logo_url':
              setAppLogoUrl(cfg.value || '');
              break;
            case 'jwt_lifetime_value':
              setJwtLifetimeValue(parseInt(cfg.value) || 1);
              break;
            case 'jwt_lifetime_unit':
              setJwtLifetimeUnit(cfg.value || 'days');
              break;
            case 'refresh_token_lifetime_value':
              setRefreshTokenLifetimeValue(parseInt(cfg.value) || 30);
              break;
            case 'refresh_token_lifetime_unit':
              setRefreshTokenLifetimeUnit(cfg.value || 'days');
              break;
            case 'enable_auto_token_refresh':
              setEnableAutoTokenRefresh(cfg.value !== 'false');
              break;
            case 'telegram_url':
              setTelegramUrl(cfg.value || 'https://t.me/RightlearnApp');
              break;
            case 'bale_url':
              setBaleUrl(cfg.value || 'https://ble.ir/rightlearnapp');
              break;
            case 'eitaa_url':
              setEitaaUrl(cfg.value || 'https://eitaa.com/RightLearnApp');
              break;
            case 'support_url':
              setSupportUrl(cfg.value || 'https://t.me/RLAppSupport');
              break;
            case 'support_id':
              setSupportId(cfg.value || '@RLAppSupport');
              break;
            case 'leitner_box2_interval':
              setLeitnerBox2Interval(parseInt(cfg.value) || 3);
              break;
            case 'leitner_box3_interval':
              setLeitnerBox3Interval(parseInt(cfg.value) || 7);
              break;
            case 'leitner_box4_interval':
              setLeitnerBox4Interval(parseInt(cfg.value) || 16);
              break;
            case 'leitner_box5_interval':
              setLeitnerBox5Interval(parseInt(cfg.value) || 31);
              break;
            case 'leitner_interval_unit':
              setLeitnerIntervalUnit(cfg.value || 'days');
              break;
            case 'daily_reminder_hour': {
              const h = parseInt(cfg.value);
              setDailyReminderHour(!isNaN(h) && h >= 0 && h <= 23 ? h : 9);
              break;
            }
            case 'daily_reminder_minute': {
              const m = parseInt(cfg.value);
              setDailyReminderMinute(!isNaN(m) && m >= 0 && m <= 59 ? m : 0);
              break;
            }
            case 'daily_reminder_enabled':
              setEnableDailyReminder(cfg.value !== 'false');
              break;
            case 'admin_allowed_mobile_numbers': {
              const raw = cfg.value || '09120000000, +989120000000';
              const parsed = raw
                .split(',')
                .map((s: string) => s.trim())
                .filter((s: string) => s.length > 0);
              setAdminAllowedMobilesList(parsed.length > 0 ? parsed : ['09120000000', '+989120000000']);
              break;
            }
            case 'admin_emergency_bypass_enabled':
              setAdminEmergencyBypassEnabled(cfg.value !== 'false');
              break;
            default:
              break;
          }
        });
      }
    } catch {
      toast.showError(t('settings.load_failed', 'Failed to load configuration settings.'));
    } finally {
      setLoading(false);
    }
  };

  const handleLogoUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    if (file.size > 5 * 1024 * 1024) {
      toast.showError(t('settings.file_too_large', 'File size exceeds the 5MB limit.'));
      return;
    }

    setUploadingLogo(true);
    try {
      const res = await api.admin.uploadAppLogo(file);
      if (res.success) {
        setAppLogoUrl(res.logo_url);
        toast.showSuccess(t('settings.logo_upload_success', 'New app icon / logo uploaded and propagated successfully!'));
      }
    } catch (err: unknown) {
      const errorMsg = err instanceof Error ? err.message : String(err);
      toast.showError(errorMsg || 'Failed to upload app logo.');
    } finally {
      setUploadingLogo(false);
      e.target.value = '';
    }
  };

  const handleLogoReset = async () => {
    if (!confirm(t('settings.confirm_reset_logo', 'Are you sure you want to reset the in-app logo to the default bundled asset?'))) return;
    setUploadingLogo(true);
    try {
      const res = await api.admin.resetAppLogo();
      if (res.success) {
        setAppLogoUrl('');
        toast.showSuccess(t('settings.logo_reset_success', 'App icon / logo reset to default successfully!'));
      }
    } catch (err: unknown) {
      const errorMsg = err instanceof Error ? err.message : String(err);
      toast.showError(errorMsg || 'Failed to reset logo.');
    } finally {
      setUploadingLogo(false);
    }
  };

  const getResolvedLogoUrl = (url: string) => {
    if (!url) return '';
    if (url.startsWith('http://') || url.startsWith('https://') || url.startsWith('data:')) return url;
    const base = ((import.meta as any).env?.VITE_API_BASE_URL as string || '/api/v1').replace(/\/api\/v1\/?$/, '');
    const clean = url.startsWith('/') ? url : `/${url}`;
    return `${base}${clean}`;
  };

  useEffect(() => {
    loadSettings();
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (adminAllowedMobilesList.length === 0 && !adminEmergencyBypassEnabled) {
      toast.showError(t('settings.error_lockout_risk', 'حداقل یک شماره موبایل باید ثبت شود یا کد اضطراری فعال باشد تا از قفل شدن دسترسی ادمین جلوگیری شود.'));
      return;
    }
    setSaving(true);
    try {
      const payload = [
        { key: 'maintenance_mode', value: maintenanceMode.toString() },
        { key: 'api_server', value: apiServer },
        { key: 'content_server', value: contentServer },
        { key: 'banner_server', value: bannerServer },
        { key: 'enable_ai_tutor', value: enableAiTutor.toString() },
        { key: 'enable_custom_themes', value: enableCustomThemes.toString() },
        { key: 'enable_search_v2', value: enableSearchV2.toString() },
        { key: 'enable_gamified_layout', value: enableGamifiedLayout.toString() },
        { key: 'enable_screenshot_protection', value: enableScreenshotProtection.toString() },
        { key: 'rotation_interval_seconds', value: rotationInterval.toString() },
        { key: 'max_banner_count', value: maxBannerCount.toString() },
        { key: 'card_nav_icon_style', value: cardNavIconStyle },
        { key: 'global_icon_scale', value: globalIconScale.toString() },
        { key: 'card_nav_icon_size', value: cardNavIconSize.toString() },
        { key: 'bottom_nav_icon_size', value: bottomNavIconSize.toString() },
        { key: 'app_bar_icon_size', value: appBarIconSize.toString() },
        { key: 'app_logo_size', value: appLogoSize.toString() },
        { key: 'app_logo_url', value: appLogoUrl },
        { key: 'jwt_lifetime_value', value: jwtLifetimeValue.toString() },
        { key: 'jwt_lifetime_unit', value: jwtLifetimeUnit },
        { key: 'refresh_token_lifetime_value', value: refreshTokenLifetimeValue.toString() },
        { key: 'refresh_token_lifetime_unit', value: refreshTokenLifetimeUnit },
        { key: 'enable_auto_token_refresh', value: enableAutoTokenRefresh.toString() },
        { key: 'telegram_url', value: telegramUrl },
        { key: 'bale_url', value: baleUrl },
        { key: 'eitaa_url', value: eitaaUrl },
        { key: 'support_url', value: supportUrl },
        { key: 'support_id', value: supportId },
        { key: 'leitner_box2_interval', value: leitnerBox2Interval.toString() },
        { key: 'leitner_box3_interval', value: leitnerBox3Interval.toString() },
        { key: 'leitner_box4_interval', value: leitnerBox4Interval.toString() },
        { key: 'leitner_box5_interval', value: leitnerBox5Interval.toString() },
        { key: 'leitner_interval_unit', value: leitnerIntervalUnit },
        { key: 'daily_reminder_hour', value: dailyReminderHour.toString() },
        { key: 'daily_reminder_minute', value: dailyReminderMinute.toString() },
        { key: 'daily_reminder_enabled', value: enableDailyReminder.toString() },
        { key: 'admin_allowed_mobile_numbers', value: adminAllowedMobilesList.join(', ') },
        { key: 'admin_emergency_bypass_enabled', value: adminEmergencyBypassEnabled.toString() },
      ];
      await api.admin.updateConfig(payload);
      toast.showSuccess(t('settings.save_success', 'تنظیمات با موفقیت ذخیره شدند.'));
      loadSettings();
    } catch (err: unknown) {
      const errorMsg = err instanceof Error ? err.message : String(err);
      toast.showError(errorMsg || t('settings.save_failed', 'Failed to save configuration settings.'));
    } finally {
      setSaving(false);
    }
  };

  return (
    <div style={{ maxWidth: '800px', margin: '0 auto' }}>
      <div className="table-container" style={{ padding: '24px' }}>
        <div className="table-header" style={{ marginBottom: '24px' }}>
          <h2>{t('settings.title')}</h2>
          <button className="btn" onClick={loadSettings} disabled={loading}>
            {t('login.captcha_refresh')}
          </button>
        </div>

        {loading ? (
          <div className="text-center p-24">{t('login.verifying', 'Loading settings...')}</div>
        ) : (
          <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
            
            {/* Global Maintenance Mode */}
            <div style={{ padding: '16px', background: 'rgba(0, 0, 0, 0.15)', borderRadius: '8px', border: '1px solid var(--border-color)' }}>
              <h3 style={{ marginTop: 0, display: 'flex', alignItems: 'center', gap: '8px', color: '#ff7a1a' }}>
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/>
                  <line x1="12" y1="9" x2="12" y2="13"/>
                  <line x1="12" y1="17" x2="12.01" y2="17"/>
                </svg>
                {t('settings.section_maintenance')}
              </h3>
              <p className="text-muted" style={{ fontSize: '13px', margin: '4px 0 16px 0' }}>
                {t('settings.maintenance_desc')}
              </p>
              <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                <input
                  type="checkbox"
                  id="maintenance_mode"
                  checked={maintenanceMode}
                  onChange={(e) => setMaintenanceMode(e.target.checked)}
                  style={{ width: '20px', height: '20px', cursor: 'pointer' }}
                />
                <label htmlFor="maintenance_mode" style={{ fontWeight: 'bold', fontSize: '15px', cursor: 'pointer', color: maintenanceMode ? '#ff7a1a' : 'inherit' }}>
                  {t('settings.maintenance_enable')}
                </label>
              </div>
            </div>

            {/* API Endpoints */}
            <div style={{ padding: '16px', background: 'rgba(0, 0, 0, 0.15)', borderRadius: '8px', border: '1px solid var(--border-color)' }}>
              <h3 style={{ marginTop: 0, color: 'var(--primary-hover)' }}>{t('settings.endpoints_title', 'Dynamic Server Endpoints')}</h3>
              <p className="text-muted" style={{ fontSize: '13px', margin: '4px 0 16px 0' }}>
                {t('settings.endpoints_subtitle', 'Define URLs used by the client to communicate with API endpoints.')}
              </p>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                <div className="form-group">
                  <label>{t('settings.api_server_label', 'Primary API Server URL')}</label>
                  <input
                    type="url"
                    value={apiServer}
                    onChange={(e) => setApiServer(e.target.value)}
                    placeholder="https://api.leitnerapp.com"
                    required
                  />
                </div>
                <div className="form-group">
                  <label>{t('settings.content_server_label', 'Content Delivery Server URL')}</label>
                  <input
                    type="url"
                    value={contentServer}
                    onChange={(e) => setContentServer(e.target.value)}
                    placeholder="https://content.leitnerapp.com"
                    required
                  />
                </div>
                <div className="form-group">
                  <label>{t('settings.banner_server_label', 'Promo Banner Media Server URL')}</label>
                  <input
                    type="url"
                    value={bannerServer}
                    onChange={(e) => setBannerServer(e.target.value)}
                    placeholder="https://banners.leitnerapp.com"
                    required
                  />
                </div>
              </div>
            </div>

            {/* Remote Feature Flags */}
            <div style={{ padding: '16px', background: 'rgba(0, 0, 0, 0.15)', borderRadius: '8px', border: '1px solid var(--border-color)' }}>
              <h3 style={{ marginTop: 0, color: 'var(--primary-hover)' }}>{t('settings.section_flags')}</h3>
              <p className="text-muted" style={{ fontSize: '13px', margin: '4px 0 16px 0' }}>
                {t('settings.subtitle')}
              </p>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <input
                    type="checkbox"
                    id="enable_ai_tutor"
                    checked={enableAiTutor}
                    onChange={(e) => setEnableAiTutor(e.target.checked)}
                    style={{ width: '18px', height: '18px' }}
                  />
                  <label htmlFor="enable_ai_tutor">{t('settings.flag_ai_tutor')}</label>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <input
                    type="checkbox"
                    id="enable_custom_themes"
                    checked={enableCustomThemes}
                    onChange={(e) => setEnableCustomThemes(e.target.checked)}
                    style={{ width: '18px', height: '18px' }}
                  />
                  <label htmlFor="enable_custom_themes">{t('settings.flag_themes')}</label>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <input
                    type="checkbox"
                    id="enable_search_v2"
                    checked={enableSearchV2}
                    onChange={(e) => setEnableSearchV2(e.target.checked)}
                    style={{ width: '18px', height: '18px' }}
                  />
                  <label htmlFor="enable_search_v2">{t('settings.flag_search')}</label>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <input
                    type="checkbox"
                    id="enable_gamified_layout"
                    checked={enableGamifiedLayout}
                    onChange={(e) => setEnableGamifiedLayout(e.target.checked)}
                    style={{ width: '18px', height: '18px' }}
                  />
                  <label htmlFor="enable_gamified_layout" style={{ fontWeight: 'bold', color: enableGamifiedLayout ? 'var(--primary-hover)' : 'inherit' }}>
                    {t('settings.flag_gamified_layout', 'Enable Gamified 3D Mobile App Layout')}
                  </label>
                </div>
                <div style={{ display: 'flex', alignItems: 'flex-start', gap: '8px', padding: '10px', background: 'rgba(255, 255, 255, 0.03)', borderRadius: '6px', border: '1px solid rgba(255, 255, 255, 0.05)', marginTop: '4px' }}>
                  <input
                    type="checkbox"
                    id="enable_screenshot_protection"
                    checked={enableScreenshotProtection}
                    onChange={(e) => setEnableScreenshotProtection(e.target.checked)}
                    style={{ width: '18px', height: '18px', marginTop: '2px' }}
                  />
                  <div>
                    <label htmlFor="enable_screenshot_protection" style={{ fontWeight: 'bold', color: enableScreenshotProtection ? 'var(--primary-hover)' : 'inherit', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '6px' }}>
                      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                        <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
                      </svg>
                      {t('settings.flag_screenshot_protection', 'Enable Screenshot & Screen Capture Protection (FLAG_SECURE)')}
                    </label>
                    <p className="text-muted" style={{ fontSize: '12px', margin: '4px 0 0 0' }}>
                      {t('settings.flag_screenshot_protection_desc', 'When enabled, prevents users from capturing screenshots or recording videos of flashcards and course study material on mobile devices.')}
                    </p>
                  </div>
                </div>
              </div>
            </div>

            {/* Authentication & Session Persistence */}
            <div style={{ padding: '16px', background: 'rgba(0, 0, 0, 0.15)', borderRadius: '8px', border: '1px solid var(--border-color)' }}>
              <h3 style={{ marginTop: 0, color: 'var(--primary-hover)', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>
                  <path d="M7 11V7a5 5 0 0 1 10 0v4"/>
                </svg>
                {t('settings.section_auth', 'Authentication & Session Persistence')}
              </h3>
              <p className="text-muted" style={{ fontSize: '13px', margin: '4px 0 16px 0' }}>
                {t('settings.auth_subtitle', 'Configure JWT access token expiry, refresh token duration, and auto-renewal policies.')}
              </p>

              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: '16px', marginBottom: '16px' }}>
                {/* JWT Token Lifetime */}
                <div className="form-group">
                  <label style={{ fontWeight: 'bold', fontSize: '13px' }}>
                    {t('settings.jwt_lifetime_label', 'JWT Access Token Lifetime')}
                  </label>
                  <p className="text-muted" style={{ fontSize: '12px', margin: '2px 0 8px 0' }}>
                    {t('settings.jwt_lifetime_desc', 'How long an active session token stays valid before needing background renewal.')}
                  </p>
                  <div style={{ display: 'flex', gap: '8px' }}>
                    <input
                      type="number"
                      min="1"
                      max="365"
                      value={jwtLifetimeValue}
                      onChange={(e) => setJwtLifetimeValue(Math.max(1, parseInt(e.target.value) || 1))}
                      style={{ flex: 1 }}
                      required
                    />
                    <select
                      value={jwtLifetimeUnit}
                      onChange={(e) => setJwtLifetimeUnit(e.target.value)}
                      style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid var(--border-color)', background: 'var(--input-bg, #1e293b)', color: 'inherit', cursor: 'pointer' }}
                    >
                      <option value="minutes">{t('settings.unit_minutes', 'Minutes')}</option>
                      <option value="hours">{t('settings.unit_hours', 'Hours')}</option>
                      <option value="days">{t('settings.unit_days', 'Days')}</option>
                    </select>
                  </div>
                </div>

                {/* Refresh Token Lifetime */}
                <div className="form-group">
                  <label style={{ fontWeight: 'bold', fontSize: '13px' }}>
                    {t('settings.refresh_token_lifetime_label', 'Refresh Token Duration (Max Inactive Session)')}
                  </label>
                  <p className="text-muted" style={{ fontSize: '12px', margin: '2px 0 8px 0' }}>
                    {t('settings.refresh_token_lifetime_desc', 'How long a user can remain logged in without re-authenticating via SMS OTP.')}
                  </p>
                  <div style={{ display: 'flex', gap: '8px' }}>
                    <input
                      type="number"
                      min="1"
                      max="365"
                      value={refreshTokenLifetimeValue}
                      onChange={(e) => setRefreshTokenLifetimeValue(Math.max(1, parseInt(e.target.value) || 1))}
                      style={{ flex: 1 }}
                      required
                    />
                    <select
                      value={refreshTokenLifetimeUnit}
                      onChange={(e) => setRefreshTokenLifetimeUnit(e.target.value)}
                      style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid var(--border-color)', background: 'var(--input-bg, #1e293b)', color: 'inherit', cursor: 'pointer' }}
                    >
                      <option value="hours">{t('settings.unit_hours', 'Hours')}</option>
                      <option value="days">{t('settings.unit_days', 'Days')}</option>
                      <option value="months">{t('settings.unit_months', 'Months')}</option>
                    </select>
                  </div>
                </div>
              </div>

              {/* Seamless Token Auto-Refresh Toggle */}
              <div style={{ display: 'flex', alignItems: 'flex-start', gap: '8px', padding: '10px', background: 'rgba(255, 255, 255, 0.03)', borderRadius: '6px', border: '1px solid rgba(255, 255, 255, 0.05)', marginBottom: '16px' }}>
                <input
                  type="checkbox"
                  id="enable_auto_token_refresh"
                  checked={enableAutoTokenRefresh}
                  onChange={(e) => setEnableAutoTokenRefresh(e.target.checked)}
                  style={{ width: '18px', height: '18px', marginTop: '2px', cursor: 'pointer' }}
                />
                <div>
                  <label htmlFor="enable_auto_token_refresh" style={{ fontWeight: 'bold', color: enableAutoTokenRefresh ? 'var(--primary-hover)' : 'inherit', cursor: 'pointer' }}>
                    {t('settings.auto_refresh_label', 'Enable Seamless Background Token Renewal')}
                  </label>
                  <p className="text-muted" style={{ fontSize: '12px', margin: '4px 0 0 0' }}>
                    {t('settings.auto_refresh_desc', 'Automatically exchanges refresh tokens for new access tokens before expiry without interrupting user study.')}
                  </p>
                </div>
              </div>

              {/* Policy Live Summary Badge */}
              <div style={{ padding: '10px 14px', background: 'rgba(79, 70, 229, 0.1)', borderRadius: '6px', border: '1px solid rgba(79, 70, 229, 0.25)', display: 'flex', alignItems: 'center', gap: '8px', fontSize: '13px' }}>
                <span style={{ color: 'var(--primary-hover)', fontWeight: 'bold' }}>
                  {t('settings.session_summary_label', 'Effective Session Policy Summary:')}
                </span>
                <span style={{ color: '#e2e8f0' }}>
                  {enableAutoTokenRefresh
                    ? `Users will stay logged in for up to ${refreshTokenLifetimeValue} ${t(`settings.unit_${refreshTokenLifetimeUnit}`, refreshTokenLifetimeUnit)}, renewing access tokens silently every ${jwtLifetimeValue} ${t(`settings.unit_${jwtLifetimeUnit}`, jwtLifetimeUnit)}.`
                    : `Users must re-login via SMS OTP every ${jwtLifetimeValue} ${t(`settings.unit_${jwtLifetimeUnit}`, jwtLifetimeUnit)} (Background renewal disabled).`}
                </span>
              </div>
            </div>

            {/* Section: Admin Security & Login Access */}
            <div style={{ padding: '16px', background: 'rgba(0, 0, 0, 0.15)', borderRadius: '8px', border: '1px solid var(--border-color)' }}>
              <h3 style={{ marginTop: 0, display: 'flex', alignItems: 'center', gap: '8px', color: '#6366f1' }}>
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>
                </svg>
                {t('settings.admin_security_title', 'امنیت ورود به پنل مدیریت (Admin Login & Security)')}
              </h3>
              <p className="text-muted" style={{ fontSize: '13px', margin: '4px 0 16px 0' }}>
                {t('settings.admin_security_desc', 'مدیریت شماره‌های مجاز جهت ورود به پنل ادمین و تنظیمات دسترسی اضطراری')}
              </p>

              <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                {/* Whitelist Phone Numbers Chips/Badges Manager */}
                <div className="form-group">
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '8px' }}>
                    <label style={{ fontWeight: 'bold', fontSize: '13px', margin: 0, display: 'flex', alignItems: 'center', gap: '6px' }}>
                      <span>📱</span>
                      <span>{t('settings.admin_mobiles_label', 'شماره‌های موبایل مجاز جهت ورود ادمین')}</span>
                    </label>
                    <span style={{
                      fontSize: '11px',
                      fontWeight: 'bold',
                      padding: '3px 10px',
                      borderRadius: '12px',
                      background: adminAllowedMobilesList.length > 0 ? 'rgba(99, 102, 241, 0.2)' : 'rgba(239, 68, 68, 0.2)',
                      color: adminAllowedMobilesList.length > 0 ? '#818cf8' : '#f87171',
                      border: adminAllowedMobilesList.length > 0 ? '1px solid rgba(99, 102, 241, 0.3)' : '1px solid rgba(239, 68, 68, 0.3)'
                    }}>
                      {adminAllowedMobilesList.length} {t('settings.active_numbers_badge', 'شماره فعال')}
                    </span>
                  </div>

                  {/* Chips Display Area */}
                  <div style={{
                    minHeight: '52px',
                    padding: '8px 12px',
                    borderRadius: '8px',
                    border: '1px solid var(--border-color)',
                    background: 'var(--input-bg, #1e293b)',
                    display: 'flex',
                    flexWrap: 'wrap',
                    alignItems: 'center',
                    gap: '8px',
                    marginBottom: '10px'
                  }}>
                    {adminAllowedMobilesList.length === 0 ? (
                      <span style={{ fontSize: '12px', color: '#f87171', fontStyle: 'italic' }}>
                        ⚠️ {t('settings.no_numbers_registered', 'هیچ شماره‌ای در لیست ثبت نشده است. لطفا با فرم زیر شماره‌های مجاز را اضافه کنید.')}
                      </span>
                    ) : (
                      adminAllowedMobilesList.map((mobile, idx) => {
                        const isDefaultAdmin = normalizePhone(mobile) === '09120000000';
                        return (
                          <div
                            key={`${mobile}-${idx}`}
                            style={{
                              display: 'inline-flex',
                              alignItems: 'center',
                              gap: '6px',
                              background: 'rgba(99, 102, 241, 0.15)',
                              border: '1px solid rgba(99, 102, 241, 0.4)',
                              borderRadius: '20px',
                              padding: '4px 10px',
                              fontSize: '13px',
                              fontFamily: 'monospace',
                              color: '#c7d2fe',
                              boxShadow: '0 1px 2px rgba(0,0,0,0.1)'
                            }}
                          >
                            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" style={{ opacity: 0.8 }}>
                              <rect x="5" y="2" width="14" height="20" rx="2" ry="2"/>
                              <line x1="12" y1="18" x2="12.01" y2="18"/>
                            </svg>
                            <span style={{ direction: 'ltr', fontWeight: '500' }}>{mobile}</span>
                            {isDefaultAdmin && (
                              <span style={{
                                fontSize: '10px',
                                background: 'rgba(234, 179, 8, 0.25)',
                                color: '#fef08a',
                                padding: '1px 5px',
                                borderRadius: '4px',
                                fontWeight: 'bold'
                              }}>
                                Backup
                              </span>
                            )}
                            <button
                              type="button"
                              onClick={() => handleRemoveMobile(idx)}
                              title={t('common.delete', 'حذف')}
                              style={{
                                background: 'none',
                                border: 'none',
                                color: '#94a3b8',
                                cursor: 'pointer',
                                padding: '0 2px',
                                display: 'inline-flex',
                                alignItems: 'center',
                                justifyContent: 'center',
                                borderRadius: '50%',
                                fontSize: '13px',
                                fontWeight: 'bold',
                                lineHeight: 1,
                                transition: 'color 0.15s ease'
                              }}
                              onMouseEnter={(e) => (e.currentTarget.style.color = '#ef4444')}
                              onMouseLeave={(e) => (e.currentTarget.style.color = '#94a3b8')}
                            >
                              ✕
                            </button>
                          </div>
                        );
                      })
                    )}
                  </div>

                  {/* Add New Mobile Input Group */}
                  <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                    <div style={{ flex: 1, position: 'relative' }}>
                      <input
                        type="text"
                        value={newMobileInput}
                        onChange={(e) => {
                          setNewMobileInput(e.target.value);
                          if (mobileInputError) setMobileInputError('');
                        }}
                        onKeyDown={(e) => {
                          if (e.key === 'Enter') {
                            e.preventDefault();
                            handleAddMobile();
                          }
                        }}
                        placeholder={t('settings.admin_mobile_input_placeholder', 'شماره موبایل را وارد کنید (مانند 09123456789 یا +989123456789)...')}
                        style={{
                          width: '100%',
                          padding: '8px 12px',
                          borderRadius: '6px',
                          border: mobileInputError ? '1px solid #ef4444' : '1px solid var(--border-color)',
                          background: 'var(--input-bg, #1e293b)',
                          color: 'inherit',
                          fontSize: '13px',
                          fontFamily: 'monospace',
                          direction: 'ltr'
                        }}
                      />
                    </div>
                    <button
                      type="button"
                      onClick={handleAddMobile}
                      className="btn"
                      style={{
                        padding: '8px 16px',
                        fontSize: '13px',
                        whiteSpace: 'nowrap',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '6px',
                        cursor: 'pointer'
                      }}
                    >
                      <span>➕</span>
                      <span>{t('settings.add_number_btn', 'افزودن شماره')}</span>
                    </button>
                  </div>

                  {/* Validation Error Message */}
                  {mobileInputError && (
                    <div style={{ color: '#ef4444', fontSize: '12px', marginTop: '6px', display: 'flex', alignItems: 'center', gap: '4px' }}>
                      <span>⚠️</span>
                      <span>{mobileInputError}</span>
                    </div>
                  )}

                  {/* Lockout Risk Warning */}
                  {adminAllowedMobilesList.length === 0 && !adminEmergencyBypassEnabled && (
                    <div style={{
                      marginTop: '8px',
                      padding: '8px 12px',
                      borderRadius: '6px',
                      background: 'rgba(239, 68, 68, 0.15)',
                      border: '1px solid rgba(239, 68, 68, 0.4)',
                      color: '#fca5a5',
                      fontSize: '12px',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '6px'
                    }}>
                      <span>🚨</span>
                      <span>{t('settings.error_lockout_risk', 'حداقل یک شماره موبایل باید ثبت شود یا کد اضطراری فعال باشد تا از قفل شدن دسترسی ادمین جلوگیری شود.')}</span>
                    </div>
                  )}

                  <small style={{ color: 'var(--text-muted)', fontSize: '11.5px', marginTop: '6px', display: 'block' }}>
                    {t('settings.admin_mobiles_help', 'فقط شماره‌های ثبت شده در این لیست اجازه دریافت کد تایید ورود به پنل مدیریت را خواهند داشت.')}
                  </small>
                </div>

                {/* Emergency Bypass Toggle */}
                <div style={{
                  display: 'flex',
                  alignItems: 'flex-start',
                  gap: '12px',
                  padding: '12px 14px',
                  background: adminEmergencyBypassEnabled ? 'rgba(234, 179, 8, 0.08)' : 'rgba(34, 197, 94, 0.08)',
                  borderRadius: '8px',
                  border: adminEmergencyBypassEnabled ? '1px solid rgba(234, 179, 8, 0.3)' : '1px solid rgba(34, 197, 94, 0.3)'
                }}>
                  <input
                    type="checkbox"
                    id="admin_emergency_bypass_enabled"
                    checked={adminEmergencyBypassEnabled}
                    onChange={(e) => handleToggleEmergencyBypass(e.target.checked)}
                    disabled={savingSecurity}
                    style={{ width: '18px', height: '18px', marginTop: '3px', cursor: 'pointer' }}
                  />
                  <div style={{ flex: 1 }}>
                    <label htmlFor="admin_emergency_bypass_enabled" style={{
                      fontWeight: 'bold',
                      fontSize: '13.5px',
                      color: adminEmergencyBypassEnabled ? '#eab308' : '#22c55e',
                      cursor: 'pointer',
                      display: 'block'
                    }}>
                      {t('settings.emergency_bypass_title', 'فعال‌سازی کد اضطراری ۱۲۳۴۵ برای شماره‌های مجاز مدیریت')}
                    </label>
                    <p style={{ fontSize: '12px', margin: '4px 0 0 0', color: 'var(--text-secondary)', lineHeight: '1.5' }}>
                      {adminEmergencyBypassEnabled
                        ? t('settings.emergency_bypass_active_desc', 'کد اضطراری فعال است. برای راه‌اندازی اولیه، تست یا مواقع قطعی سامانه پیامک می‌توانید با شماره‌های مجاز فوق و کد ۱۲۳۴۵ وارد شوید.')
                        : t('settings.emergency_bypass_inactive_desc', 'کد اضطراری غیرفعال است. ورود به پنل مدیریت صرفاً از طریق ارسال کد تایید پیامک به شماره‌های مجاز فوق انجام می‌پذیرد.')}
                    </p>
                  </div>
                </div>

                {/* Instant Auto-Save & Manual Sync Status Callout */}
                <div style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  padding: '10px 14px',
                  background: 'rgba(99, 102, 241, 0.08)',
                  borderRadius: '6px',
                  border: '1px solid rgba(99, 102, 241, 0.25)',
                  flexWrap: 'wrap',
                  gap: '8px'
                }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '12px', color: '#c7d2fe' }}>
                    {savingSecurity ? (
                      <>
                        <span style={{ display: 'inline-block', width: '12px', height: '12px', border: '2px solid #818cf8', borderTopColor: 'transparent', borderRadius: '50%', animation: 'spin 0.8s linear infinite' }} />
                        <span style={{ fontWeight: 'bold' }}>{t('settings.saving_to_server', 'در حال ذخیره‌سازی تغییرات در سرور...')}</span>
                      </>
                    ) : (
                      <>
                        <span>💾</span>
                        <span>{t('settings.auto_save_hint', 'تغییرات شماره‌ها و دسترسی اضطراری به صورت خودکار بلافاصله در سرور ذخیره می‌شوند.')}</span>
                      </>
                    )}
                  </div>
                  <button
                    type="button"
                    onClick={async () => {
                      const ok = await persistSecurityConfig(adminAllowedMobilesList, adminEmergencyBypassEnabled);
                      if (ok) toast.showSuccess(t('settings.mobile_saved_toast', 'تنظیمات امنیتی و شماره‌ها با موفقیت در سرور ذخیره شدند.'));
                    }}
                    disabled={savingSecurity}
                    className="btn"
                    style={{
                      fontSize: '11.5px',
                      padding: '4px 12px',
                      background: 'rgba(99, 102, 241, 0.25)',
                      color: '#e0e7ff',
                      border: '1px solid rgba(99, 102, 241, 0.5)',
                      cursor: 'pointer'
                    }}
                  >
                    {savingSecurity ? '...' : t('settings.force_save_security_btn', 'ذخیره دستی امنیت')}
                  </button>
                </div>
              </div>
            </div>

            {/* Banner Layout and Carousel Configs */}
            <div style={{ padding: '16px', background: 'rgba(0, 0, 0, 0.15)', borderRadius: '8px', border: '1px solid var(--border-color)' }}>
              <h3 style={{ marginTop: 0, color: 'var(--primary-hover)' }}>{t('settings.carousel_title', 'Client Carousel Configurations')}</h3>
              <p className="text-muted" style={{ fontSize: '13px', margin: '4px 0 16px 0' }}>
                {t('settings.carousel_subtitle', 'Adjust display properties of banners dynamically.')}
              </p>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                <div className="form-group">
                  <label>{t('settings.rotation_speed_label', 'Banner Rotation Speed (Seconds)')}</label>
                  <input
                    type="number"
                    min="1"
                    max="60"
                    value={rotationInterval}
                    onChange={(e) => setRotationInterval(parseInt(e.target.value) || 4)}
                    required
                  />
                </div>
                <div className="form-group">
                  <label>{t('settings.max_banner_label', 'Max Dashboard Banner Count')}</label>
                  <input
                    type="number"
                    min="1"
                    max="10"
                    value={maxBannerCount}
                    onChange={(e) => setMaxBannerCount(parseInt(e.target.value) || 5)}
                    required
                  />
                </div>
              </div>
            </div>

            {/* Card Navigation Icon Style */}
            <div style={{ padding: '16px', background: 'rgba(0, 0, 0, 0.15)', borderRadius: '8px', border: '1px solid var(--border-color)' }}>
              <h3 style={{ marginTop: 0, color: 'var(--primary-hover)', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <polygon points="12 2 2 7 12 12 22 7 12 2" />
                  <polyline points="2 17 12 22 22 17" />
                  <polyline points="2 12 12 17 22 12" />
                </svg>
                {t('settings.card_nav_icons_title', 'Card Navigation Icon Style')}
              </h3>
              <p className="text-muted" style={{ fontSize: '13px', margin: '4px 0 16px 0' }}>
                {t('settings.card_nav_icons_subtitle', 'Select the icon design used for Next and Previous card navigation in the mobile app.')}
              </p>

              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))', gap: '12px', marginBottom: '16px' }}>
                {[
                  { id: 'chevron', label: t('settings.icon_style_chevron', 'Standard Chevron (‹ ›)'), left: '‹', right: '›' },
                  { id: 'arrow', label: t('settings.icon_style_arrow', 'Standard Arrow (← →)'), left: '←', right: '→' },
                  { id: 'arrow_ios', label: t('settings.icon_style_arrow_ios', 'iOS Style Arrow (‹ ›)'), left: '‹', right: '›' },
                  { id: 'double_chevron', label: t('settings.icon_style_double_chevron', 'Double Chevron (« »)'), left: '«', right: '»' },
                  { id: 'circle_arrow', label: t('settings.icon_style_circle_arrow', 'Circled Arrow (⮜ ⮞)'), left: '⮜', right: '⮞' },
                  { id: 'triangle', label: t('settings.icon_style_triangle', 'Triangle Caret (◀ ▶)'), left: '◀', right: '▶' },
                ].map((item) => {
                  const isSelected = cardNavIconStyle === item.id;
                  return (
                    <div
                      key={item.id}
                      onClick={() => setCardNavIconStyle(item.id)}
                      style={{
                        padding: '12px',
                        borderRadius: '8px',
                        border: isSelected ? '2px solid var(--primary)' : '1px solid var(--border-color)',
                        background: isSelected ? 'rgba(var(--primary-rgb, 79, 70, 229), 0.15)' : 'rgba(255, 255, 255, 0.03)',
                        cursor: 'pointer',
                        transition: 'all 0.2s ease',
                        display: 'flex',
                        flexDirection: 'column',
                        gap: '8px',
                      }}
                    >
                      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                        <span style={{ fontWeight: isSelected ? 'bold' : 'normal', fontSize: '13px' }}>{item.label}</span>
                        <input
                          type="radio"
                          name="cardNavIconStyle"
                          value={item.id}
                          checked={isSelected}
                          onChange={() => setCardNavIconStyle(item.id)}
                          style={{ cursor: 'pointer' }}
                        />
                      </div>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '6px 10px', background: 'rgba(0,0,0,0.2)', borderRadius: '6px', fontSize: '18px', fontWeight: 'bold' }}>
                        <span style={{ color: 'var(--primary-hover)', display: 'flex', alignItems: 'center', gap: '4px', fontSize: '12px' }}>
                          <span style={{ fontSize: '16px' }}>{item.left}</span> Next
                        </span>
                        <span style={{ color: 'var(--primary-hover)', display: 'flex', alignItems: 'center', gap: '4px', fontSize: '12px' }}>
                          Prev <span style={{ fontSize: '16px' }}>{item.right}</span>
                        </span>
                      </div>
                    </div>
                  );
                })}
              </div>

              {/* Icon Sizing & Visual Scale Controls */}
              <div style={{ marginTop: '20px', paddingTop: '16px', borderTop: '1px solid rgba(255, 255, 255, 0.08)' }}>
                <h4 style={{ margin: '0 0 4px 0', color: 'var(--primary-hover)', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <polyline points="15 3 21 3 21 9" />
                    <polyline points="9 21 3 21 3 15" />
                    <line x1="21" y1="3" x2="14" y2="10" />
                    <line x1="3" y1="21" x2="10" y2="14" />
                  </svg>
                  {t('settings.icon_sizing_title', 'Icon Sizing & Visual Scaling')}
                </h4>
                <p className="text-muted" style={{ fontSize: '12px', margin: '0 0 14px 0' }}>
                  {t('settings.icon_sizing_subtitle', 'Configure global icon scaling and specific icon sizes for card navigation, bottom navigation bar, and app headers.')}
                </p>

                {/* Quick Presets */}
                <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap', marginBottom: '16px' }}>
                  {[
                    { label: t('settings.preset_compact', 'Compact (85%)'), scale: 0.85 },
                    { label: t('settings.preset_standard', 'Standard (100%)'), scale: 1.0 },
                    { label: t('settings.preset_large', 'Large (115%)'), scale: 1.15 },
                    { label: t('settings.preset_xlarge', 'Extra Large (130%)'), scale: 1.3 },
                  ].map((preset) => {
                    const isSelected = Math.abs(globalIconScale - preset.scale) < 0.01;
                    return (
                      <button
                        key={preset.scale}
                        type="button"
                        className="btn"
                        onClick={() => applyIconScalePreset(preset.scale)}
                        style={{
                          fontSize: '12px',
                          padding: '6px 12px',
                          background: isSelected ? 'var(--primary)' : 'rgba(255,255,255,0.08)',
                          borderColor: isSelected ? 'var(--primary)' : 'var(--border-color)',
                          color: isSelected ? '#fff' : 'inherit',
                          cursor: 'pointer'
                        }}
                      >
                        🔍 {preset.label}
                      </button>
                    );
                  })}
                </div>

                {/* Sizing Numeric Fields */}
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(170px, 1fr))', gap: '12px', marginBottom: '16px' }}>
                  <div className="form-group">
                    <label style={{ fontSize: '12px', fontWeight: 'bold' }}>{t('settings.global_icon_scale_label', 'Global Icon Scale')}</label>
                    <input
                      type="number"
                      step="0.05"
                      min="0.7"
                      max="1.5"
                      value={globalIconScale}
                      onChange={(e) => setGlobalIconScale(Math.max(0.5, Math.min(2.0, parseFloat(e.target.value) || 1.0)))}
                      required
                    />
                  </div>
                  <div className="form-group">
                    <label style={{ fontSize: '12px', fontWeight: 'bold' }}>{t('settings.card_nav_icon_size_label', 'Card Nav Icon (px)')}</label>
                    <input
                      type="number"
                      min="12"
                      max="40"
                      value={cardNavIconSize}
                      onChange={(e) => setCardNavIconSize(Math.max(12, Math.min(48, parseInt(e.target.value) || 20)))}
                      required
                    />
                  </div>
                  <div className="form-group">
                    <label style={{ fontSize: '12px', fontWeight: 'bold' }}>{t('settings.bottom_nav_icon_size_label', 'Bottom Bar Icon (px)')}</label>
                    <input
                      type="number"
                      min="16"
                      max="44"
                      value={bottomNavIconSize}
                      onChange={(e) => setBottomNavIconSize(Math.max(16, Math.min(48, parseInt(e.target.value) || 26)))}
                      required
                    />
                  </div>
                  <div className="form-group">
                    <label style={{ fontSize: '12px', fontWeight: 'bold' }}>{t('settings.app_bar_icon_size_label', 'App Bar Action Icon (px)')}</label>
                    <input
                      type="number"
                      min="16"
                      max="44"
                      value={appBarIconSize}
                      onChange={(e) => setAppBarIconSize(Math.max(16, Math.min(48, parseInt(e.target.value) || 24)))}
                      required
                    />
                  </div>
                  <div className="form-group">
                    <label style={{ fontSize: '12px', fontWeight: 'bold' }}>{t('settings.app_logo_size_label', 'In-App Logo / Branding Size (px)')}</label>
                    <input
                      type="number"
                      min="60"
                      max="220"
                      value={appLogoSize}
                      onChange={(e) => setAppLogoSize(Math.max(50, Math.min(260, parseInt(e.target.value) || 110)))}
                      required
                    />
                  </div>
                </div>
              </div>

              {/* Live Preview Card */}
              <div style={{ padding: '14px 16px', background: 'rgba(0, 0, 0, 0.25)', borderRadius: '8px', border: '1px dashed var(--border-color)', display: 'flex', flexDirection: 'column', gap: '14px' }}>
                <div>
                  <span className="text-muted" style={{ fontSize: '12px', display: 'block', marginBottom: '8px' }}>
                    {t('settings.preview_label', 'Live Preview in RTL (Flashcard Study):')} ({cardNavIconSize}px)
                  </span>
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', background: 'var(--card-bg, #1e293b)', padding: '12px 20px', borderRadius: '8px', direction: 'ltr' }}>
                    <div style={{ width: `${Math.max(32, cardNavIconSize + 12)}px`, height: `${Math.max(32, cardNavIconSize + 12)}px`, borderRadius: '50%', background: 'rgba(var(--primary-rgb, 79, 70, 229), 0.2)', color: 'var(--primary)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 'bold', fontSize: `${cardNavIconSize}px` }}>
                      {cardNavIconStyle === 'arrow' ? '←' : cardNavIconStyle === 'double_chevron' ? '«' : cardNavIconStyle === 'circle_arrow' ? '⮜' : cardNavIconStyle === 'triangle' ? '◀' : '‹'}
                    </div>
                    <div style={{ textAlign: 'center', color: '#94a3b8', fontSize: '13px' }}>
                      [ Flashcard Study Canvas ]
                    </div>
                    <div style={{ width: `${Math.max(32, cardNavIconSize + 12)}px`, height: `${Math.max(32, cardNavIconSize + 12)}px`, borderRadius: '50%', background: 'rgba(var(--primary-rgb, 79, 70, 229), 0.2)', color: 'var(--primary)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 'bold', fontSize: `${cardNavIconSize}px` }}>
                      {cardNavIconStyle === 'arrow' ? '→' : cardNavIconStyle === 'double_chevron' ? '»' : cardNavIconStyle === 'circle_arrow' ? '⮞' : cardNavIconStyle === 'triangle' ? '▶' : '›'}
                    </div>
                  </div>
                </div>

                {/* Bottom Navigation Live Preview */}
                <div>
                  <span className="text-muted" style={{ fontSize: '12px', display: 'block', marginBottom: '8px' }}>
                    {t('settings.bottom_nav_preview_label', 'Bottom Navigation Bar Preview:')} ({bottomNavIconSize}px)
                  </span>
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-around', background: 'rgba(15, 23, 42, 0.95)', padding: '10px 16px', borderRadius: '8px', border: '1px solid rgba(255,255,255,0.05)' }}>
                    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '4px', color: 'var(--primary)' }}>
                      <svg width={bottomNavIconSize} height={bottomNavIconSize} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                        <rect x="3" y="3" width="7" height="7" />
                        <rect x="14" y="3" width="7" height="7" />
                        <rect x="14" y="14" width="7" height="7" />
                        <rect x="3" y="14" width="7" height="7" />
                      </svg>
                      <span style={{ fontSize: '11px', fontWeight: 'bold' }}>{t('sidebar.dashboard', 'Home')}</span>
                    </div>
                    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '4px', color: '#94a3b8' }}>
                      <svg width={bottomNavIconSize} height={bottomNavIconSize} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                        <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
                        <polyline points="14 2 14 8 20 8" />
                      </svg>
                      <span style={{ fontSize: '11px' }}>{t('sidebar.cards', 'Review')}</span>
                    </div>
                    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '4px', color: '#94a3b8' }}>
                      <svg width={bottomNavIconSize} height={bottomNavIconSize} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                        <path d="M22 10v6M2 10l10-5 10 5-10 5z" />
                        <path d="M6 12v5c3 3 9 3 12 0v-5" />
                      </svg>
                      <span style={{ fontSize: '11px' }}>{t('sidebar.courses', 'Courses')}</span>
                    </div>
                  </div>
                </div>

                {/* App Logo & Branding Live Preview & Upload */}
                <div style={{ background: 'rgba(15, 23, 42, 0.7)', padding: '16px', borderRadius: '8px', border: '1px solid rgba(255,255,255,0.08)' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' }}>
                    <span className="text-muted" style={{ fontSize: '12px', fontWeight: 'bold' }}>
                      {t('settings.app_logo_preview_label', 'In-App Logo & Branding Preview (About Us / Headers):')} ({appLogoSize}px)
                    </span>
                    <span
                      style={{
                        fontSize: '11px',
                        padding: '3px 8px',
                        borderRadius: '12px',
                        background: appLogoUrl ? 'rgba(16, 185, 129, 0.15)' : 'rgba(99, 102, 241, 0.15)',
                        color: appLogoUrl ? '#10b981' : '#818cf8',
                        border: appLogoUrl ? '1px solid rgba(16, 185, 129, 0.3)' : '1px solid rgba(99, 102, 241, 0.3)',
                        fontWeight: 'bold'
                      }}
                    >
                      {appLogoUrl ? t('settings.custom_logo_active', 'Custom Logo Active') : t('settings.default_logo_active', 'Default Bundled Icon Active')}
                    </span>
                  </div>

                  {/* Logo Display */}
                  <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', background: 'rgba(0, 0, 0, 0.3)', padding: '20px', borderRadius: '8px', border: '1px solid rgba(255,255,255,0.05)', marginBottom: '16px' }}>
                    <div
                      style={{
                        width: `${appLogoSize}px`,
                        height: `${appLogoSize}px`,
                        borderRadius: `${Math.round(appLogoSize * 0.25)}px`,
                        background: 'linear-gradient(135deg, var(--primary) 0%, #a855f7 100%)',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        color: '#ffffff',
                        boxShadow: '0 8px 24px rgba(79, 70, 229, 0.35)',
                        transition: 'all 0.2s ease',
                        overflow: 'hidden',
                        position: 'relative'
                      }}
                    >
                      {appLogoUrl ? (
                        <img
                          src={getResolvedLogoUrl(appLogoUrl)}
                          alt="App Logo"
                          style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                          onError={(e) => {
                            // Fallback to icon if network image fails
                            e.currentTarget.style.display = 'none';
                          }}
                        />
                      ) : (
                        <svg width={Math.round(appLogoSize * 0.55)} height={Math.round(appLogoSize * 0.55)} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                          <path d="M22 10v6M2 10l10-5 10 5-10 5z" />
                          <path d="M6 12v5c3 3 9 3 12 0v-5" />
                        </svg>
                      )}
                    </div>
                    <span style={{ marginTop: '12px', fontSize: '13px', fontWeight: 'bold', color: 'var(--primary-hover)' }}>
                      {t('settings.app_name_preview', 'Leitner Learning Platform')}
                    </span>
                    {appLogoUrl && (
                      <span className="text-muted" style={{ fontSize: '11px', marginTop: '4px', wordBreak: 'break-all' }}>
                        {appLogoUrl}
                      </span>
                    )}
                  </div>

                  {/* Logo Actions */}
                  <div style={{ display: 'flex', gap: '10px', alignItems: 'center', flexWrap: 'wrap' }}>
                    <label
                      className="btn btn-primary"
                      style={{
                        cursor: uploadingLogo ? 'not-allowed' : 'pointer',
                        opacity: uploadingLogo ? 0.7 : 1,
                        display: 'inline-flex',
                        alignItems: 'center',
                        gap: '6px',
                        margin: 0,
                        fontSize: '13px',
                        padding: '8px 16px'
                      }}
                    >
                      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                        <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
                        <polyline points="17 8 12 3 7 8" />
                        <line x1="12" y1="3" x2="12" y2="15" />
                      </svg>
                      {uploadingLogo ? t('settings.uploading_logo', 'Uploading...') : t('settings.upload_logo_btn', 'Upload New Icon / Logo')}
                      <input
                        type="file"
                        accept="image/png,image/jpeg,image/webp,image/svg+xml,image/x-icon"
                        onChange={handleLogoUpload}
                        disabled={uploadingLogo}
                        style={{ display: 'none' }}
                      />
                    </label>

                    {appLogoUrl && (
                      <button
                        type="button"
                        className="btn btn-secondary"
                        onClick={handleLogoReset}
                        disabled={uploadingLogo}
                        style={{
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: '6px',
                          fontSize: '13px',
                          padding: '8px 16px',
                          color: '#ef4444',
                          borderColor: 'rgba(239, 68, 68, 0.3)'
                        }}
                      >
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                          <polyline points="1 4 1 10 7 10" />
                          <path d="M3.51 15a9 9 0 1 0 2.13-9.36L1 10" />
                        </svg>
                        {t('settings.reset_logo_btn', 'Reset to Default Icon')}
                      </button>
                    )}
                  </div>

                  <p className="text-muted" style={{ fontSize: '11px', margin: '8px 0 0 0' }}>
                    {t('settings.upload_logo_subtitle', 'Upload a custom high-resolution logo (PNG/WebP/SVG/ICO, max 5MB). Changes are propagated instantly to all mobile app instances over-the-air.')}
                  </p>
                </div>
              </div>
            </div>

            {/* Leitner Box Progression Timing & Verification */}
            <div style={{ padding: '16px', background: 'rgba(0, 0, 0, 0.15)', borderRadius: '8px', border: '1px solid var(--border-color)' }}>
              <h3 style={{ marginTop: 0, color: 'var(--primary-hover)', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <rect x="2" y="7" width="20" height="14" rx="2" ry="2"/>
                  <path d="M16 21V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16"/>
                </svg>
                {t('settings.section_leitner', 'Leitner Spaced Repetition Stage Intervals')}
              </h3>
              <p className="text-muted" style={{ fontSize: '13px', margin: '4px 0 16px 0' }}>
                {t('settings.leitner_subtitle', 'Configure review intervals for each Leitner stage. Use fast verification presets to test the complete progression within ~1 hour.')}
              </p>

              {/* Quick Presets */}
              <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap', marginBottom: '16px' }}>
                <button
                  type="button"
                  className="btn"
                  onClick={() => applyLeitnerPreset('standard')}
                  style={{
                    fontSize: '12px',
                    padding: '6px 12px',
                    background: leitnerIntervalUnit === 'days' && leitnerBox2Interval === 3 && leitnerBox3Interval === 7 && leitnerBox4Interval === 16 && leitnerBox5Interval === 31 ? 'var(--primary)' : 'rgba(255,255,255,0.08)',
                    borderColor: 'var(--border-color)'
                  }}
                >
                  📅 {t('settings.leitner_preset_standard', 'Standard (Days)')}
                </button>
                <button
                  type="button"
                  className="btn"
                  onClick={() => applyLeitnerPreset('fast_hour')}
                  style={{
                    fontSize: '12px',
                    padding: '6px 12px',
                    background: leitnerIntervalUnit === 'minutes' && leitnerBox2Interval === 5 && leitnerBox3Interval === 10 && leitnerBox4Interval === 15 && leitnerBox5Interval === 20 ? 'var(--primary)' : 'rgba(255,255,255,0.08)',
                    borderColor: 'var(--border-color)'
                  }}
                >
                  ⚡ {t('settings.leitner_preset_fast_hour', 'Fast Verification (1 Hour Total)')}
                </button>
                <button
                  type="button"
                  className="btn"
                  onClick={() => applyLeitnerPreset('fast_10m')}
                  style={{
                    fontSize: '12px',
                    padding: '6px 12px',
                    background: leitnerIntervalUnit === 'minutes' && leitnerBox2Interval === 1 && leitnerBox3Interval === 2 && leitnerBox4Interval === 3 && leitnerBox5Interval === 4 ? 'var(--primary)' : 'rgba(255,255,255,0.08)',
                    borderColor: 'var(--border-color)'
                  }}
                >
                  🚀 {t('settings.leitner_preset_fast_10m', 'Ultra-Fast (10 Mins Total)')}
                </button>
              </div>

              {/* Time Unit Selector */}
              <div className="form-group" style={{ marginBottom: '16px' }}>
                <label style={{ fontWeight: 'bold' }}>{t('settings.leitner_unit_label', 'Stage Interval Time Unit')}</label>
                <select
                  value={leitnerIntervalUnit}
                  onChange={(e) => setLeitnerIntervalUnit(e.target.value)}
                  style={{ width: '100%', padding: '8px 12px', borderRadius: '6px', border: '1px solid var(--border-color)', background: 'var(--input-bg, #0f172a)', color: 'inherit' }}
                >
                  <option value="seconds">{t('settings.unit_seconds', 'Seconds')}</option>
                  <option value="minutes">{t('settings.unit_minutes', 'Minutes')}</option>
                  <option value="hours">{t('settings.unit_hours', 'Hours')}</option>
                  <option value="days">{t('settings.unit_days', 'Days')}</option>
                </select>
              </div>

              {/* Box Stage Inputs */}
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))', gap: '12px', marginBottom: '16px' }}>
                <div className="form-group">
                  <label style={{ fontSize: '13px', fontWeight: 'bold' }}>{t('settings.leitner_box2_label', 'Box 2 Interval')}</label>
                  <input
                    type="number"
                    min="1"
                    value={leitnerBox2Interval}
                    onChange={(e) => setLeitnerBox2Interval(Math.max(1, parseInt(e.target.value) || 1))}
                    required
                  />
                </div>
                <div className="form-group">
                  <label style={{ fontSize: '13px', fontWeight: 'bold' }}>{t('settings.leitner_box3_label', 'Box 3 Interval')}</label>
                  <input
                    type="number"
                    min="1"
                    value={leitnerBox3Interval}
                    onChange={(e) => setLeitnerBox3Interval(Math.max(1, parseInt(e.target.value) || 1))}
                    required
                  />
                </div>
                <div className="form-group">
                  <label style={{ fontSize: '13px', fontWeight: 'bold' }}>{t('settings.leitner_box4_label', 'Box 4 Interval')}</label>
                  <input
                    type="number"
                    min="1"
                    value={leitnerBox4Interval}
                    onChange={(e) => setLeitnerBox4Interval(Math.max(1, parseInt(e.target.value) || 1))}
                    required
                  />
                </div>
                <div className="form-group">
                  <label style={{ fontSize: '13px', fontWeight: 'bold' }}>{t('settings.leitner_box5_label', 'Box 5 Interval')}</label>
                  <input
                    type="number"
                    min="1"
                    value={leitnerBox5Interval}
                    onChange={(e) => setLeitnerBox5Interval(Math.max(1, parseInt(e.target.value) || 1))}
                    required
                  />
                </div>
              </div>

              {/* Summary and Hint Badge */}
              <div style={{ padding: '12px 16px', background: 'rgba(0, 0, 0, 0.25)', borderRadius: '8px', border: '1px dashed var(--border-color)' }}>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '6px' }}>
                  <span style={{ fontWeight: 'bold', fontSize: '13px' }}>
                    {t('settings.leitner_summary_label', 'Total Time to Finished (Box 7):')}
                  </span>
                  <span style={{ color: 'var(--primary-hover)', fontWeight: 'bold', fontSize: '14px' }}>
                    {leitnerBox2Interval + leitnerBox3Interval + leitnerBox4Interval + leitnerBox5Interval} {t(`settings.unit_${leitnerIntervalUnit}`, leitnerIntervalUnit)}
                  </span>
                </div>
                <p className="text-muted" style={{ fontSize: '12px', margin: 0 }}>
                  {t('settings.leitner_test_hint', 'In 1-Hour Verification Mode, cards in Boxes 2–5 become due in minutes (5m → 10m → 15m → 20m), allowing you to quickly verify the entire learning workflow end-to-end.')}
                </p>
              </div>
            </div>

            {/* Daily Study Reminder & Notification Schedule */}
            <div style={{ padding: '16px', background: 'rgba(0, 0, 0, 0.15)', borderRadius: '8px', border: '1px solid var(--border-color)' }}>
              <h3 style={{ marginTop: 0, color: 'var(--primary-hover)', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9" />
                  <path d="M13.73 21a2 2 0 0 1-3.46 0" />
                </svg>
                {t('settings.section_notifications', 'Daily Study Reminders & Notification Schedule')}
              </h3>
              <p className="text-muted" style={{ fontSize: '13px', margin: '4px 0 16px 0' }}>
                {t('settings.notifications_subtitle', 'Configure default push/local study reminder time for mobile users (Iran Local Time). Users without custom times automatically follow this schedule.')}
              </p>

              {/* Master Enable/Disable Switch */}
              <div className="form-group" style={{ marginBottom: '16px' }}>
                <label style={{ cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <input
                    type="checkbox"
                    checked={enableDailyReminder}
                    onChange={(e) => setEnableDailyReminder(e.target.checked)}
                  />
                  <span style={{ fontWeight: 'bold' }}>{t('settings.enable_daily_reminder_label', 'Enable Default Daily Study Reminders')}</span>
                </label>
              </div>

              {enableDailyReminder && (
                <>
                  {/* Quick Presets */}
                  <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap', marginBottom: '16px' }}>
                    {[
                      { label: t('settings.reminder_preset_morning', 'Morning (09:00 AM) - Recommended'), hour: 9, minute: 0, icon: '🌅' },
                      { label: t('settings.reminder_preset_noon', 'Noon (12:00 PM)'), hour: 12, minute: 0, icon: '☀️' },
                      { label: t('settings.reminder_preset_evening', 'Evening (06:00 PM)'), hour: 18, minute: 0, icon: '🌆' },
                      { label: t('settings.reminder_preset_night', 'Night (08:00 PM)'), hour: 20, minute: 0, icon: '🌙' },
                    ].map((preset) => {
                      const isSelected = dailyReminderHour === preset.hour && dailyReminderMinute === preset.minute;
                      return (
                        <button
                          key={preset.label}
                          type="button"
                          className="btn"
                          onClick={() => applyReminderPreset(preset.hour, preset.minute)}
                          style={{
                            fontSize: '12px',
                            padding: '6px 12px',
                            background: isSelected ? 'var(--primary)' : 'rgba(255,255,255,0.08)',
                            borderColor: isSelected ? 'var(--primary)' : 'var(--border-color)',
                            color: isSelected ? '#fff' : 'inherit',
                            cursor: 'pointer'
                          }}
                        >
                          {preset.icon} {preset.label}
                        </button>
                      );
                    })}
                  </div>

                  {/* Time Inputs */}
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))', gap: '12px', marginBottom: '16px' }}>
                    <div className="form-group">
                      <label style={{ fontSize: '13px', fontWeight: 'bold' }}>{t('settings.reminder_hour_label', 'Reminder Hour (0-23)')}</label>
                      <input
                        type="number"
                        min="0"
                        max="23"
                        value={dailyReminderHour}
                        onChange={(e) => setDailyReminderHour(Math.max(0, Math.min(23, parseInt(e.target.value) || 0)))}
                        required
                      />
                    </div>
                    <div className="form-group">
                      <label style={{ fontSize: '13px', fontWeight: 'bold' }}>{t('settings.reminder_minute_label', 'Reminder Minute (0-59)')}</label>
                      <input
                        type="number"
                        min="0"
                        max="59"
                        value={dailyReminderMinute}
                        onChange={(e) => setDailyReminderMinute(Math.max(0, Math.min(59, parseInt(e.target.value) || 0)))}
                        required
                      />
                    </div>
                  </div>

                  {/* Live Summary Callout */}
                  <div style={{ padding: '12px 16px', background: 'rgba(0, 0, 0, 0.25)', borderRadius: '8px', border: '1px dashed var(--border-color)' }}>
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '6px' }}>
                      <span style={{ fontWeight: 'bold', fontSize: '13px' }}>
                        {t('settings.reminder_summary_label', 'Effective Scheduled Reminder Time:')}
                      </span>
                      <span style={{ color: 'var(--primary-hover)', fontWeight: 'bold', fontSize: '15px' }}>
                        🔔 {dailyReminderHour.toString().padStart(2, '0')}:{dailyReminderMinute.toString().padStart(2, '0')} ({dailyReminderHour >= 12 ? `${dailyReminderHour > 12 ? dailyReminderHour - 12 : 12}:${dailyReminderMinute.toString().padStart(2, '0')} PM` : `${dailyReminderHour === 0 ? 12 : dailyReminderHour}:${dailyReminderMinute.toString().padStart(2, '0')} AM`})
                      </span>
                    </div>
                    <p className="text-muted" style={{ fontSize: '12px', margin: 0 }}>
                      {t('settings.reminder_hint', 'Mobile devices will trigger a top notification bar review reminder at this local time each day for all users who have not chosen a personal reminder schedule.')}
                    </p>
                  </div>
                </>
              )}
            </div>

            {/* Social Messengers & Support Links */}
            <div style={{ padding: '16px', background: 'rgba(0, 0, 0, 0.15)', borderRadius: '8px', border: '1px solid var(--border-color)' }}>
              <h3 style={{ marginTop: 0, color: 'var(--primary-hover)', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z"/>
                </svg>
                {t('settings.section_social', 'Social Messengers & Support Links')}
              </h3>
              <p className="text-muted" style={{ fontSize: '13px', margin: '4px 0 16px 0' }}>
                {t('settings.social_subtitle', 'Configure messenger channel links (Telegram, Bale, Eitaa) and direct support handle/URL.')}
              </p>

              <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                {/* Telegram */}
                <div className="form-group">
                  <label style={{ display: 'flex', alignItems: 'center', gap: '8px', fontWeight: 'bold' }}>
                    <span style={{ display: 'inline-block', width: '10px', height: '10px', borderRadius: '50%', background: '#24A1DE' }}></span>
                    {t('settings.telegram_url_label', 'Telegram Channel URL')}
                  </label>
                  <input
                    type="url"
                    value={telegramUrl}
                    onChange={(e) => setTelegramUrl(e.target.value)}
                    placeholder="https://t.me/RightlearnApp"
                    required
                  />
                </div>

                {/* Bale */}
                <div className="form-group">
                  <label style={{ display: 'flex', alignItems: 'center', gap: '8px', fontWeight: 'bold' }}>
                    <span style={{ display: 'inline-block', width: '10px', height: '10px', borderRadius: '50%', background: '#00B18F' }}></span>
                    {t('settings.bale_url_label', 'Bale Messenger URL')}
                  </label>
                  <input
                    type="url"
                    value={baleUrl}
                    onChange={(e) => setBaleUrl(e.target.value)}
                    placeholder="https://ble.ir/rightlearnapp"
                    required
                  />
                </div>

                {/* Eitaa */}
                <div className="form-group">
                  <label style={{ display: 'flex', alignItems: 'center', gap: '8px', fontWeight: 'bold' }}>
                    <span style={{ display: 'inline-block', width: '10px', height: '10px', borderRadius: '50%', background: '#E56717' }}></span>
                    {t('settings.eitaa_url_label', 'Eitaa Messenger URL')}
                  </label>
                  <input
                    type="url"
                    value={eitaaUrl}
                    onChange={(e) => setEitaaUrl(e.target.value)}
                    placeholder="https://eitaa.com/RightLearnApp"
                    required
                  />
                </div>

                {/* Support URL & Handle */}
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                  <div className="form-group">
                    <label style={{ display: 'flex', alignItems: 'center', gap: '8px', fontWeight: 'bold' }}>
                      <span style={{ display: 'inline-block', width: '10px', height: '10px', borderRadius: '50%', background: '#6B4EE6' }}></span>
                      {t('settings.support_url_label', 'Direct Support URL')}
                    </label>
                    <input
                      type="url"
                      value={supportUrl}
                      onChange={(e) => setSupportUrl(e.target.value)}
                      placeholder="https://t.me/RLAppSupport"
                      required
                    />
                  </div>
                  <div className="form-group">
                    <label style={{ fontWeight: 'bold' }}>
                      {t('settings.support_id_label', 'Support Display ID / Handle')}
                    </label>
                    <input
                      type="text"
                      value={supportId}
                      onChange={(e) => setSupportId(e.target.value)}
                      placeholder="@RLAppSupport"
                      required
                    />
                  </div>
                </div>
              </div>
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: '12px' }}>
              <button type="submit" className="btn" style={{ minWidth: '150px' }} disabled={saving}>
                {saving ? t('login.verifying', 'Saving...') : t('settings.btn_save')}
              </button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
};

export const SettingsModule: AdminModule = {
  id: 'settings',
  name: 'Settings',
  icon: (props) => (
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...props}>
      <circle cx="12" cy="12" r="3" />
      <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z" />
    </svg>
  ),
  component: SettingsModuleView
};

function SettingsModuleView() {
  return <SettingsView />;
}

