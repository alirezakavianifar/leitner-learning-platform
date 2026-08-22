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
            default:
              break;
          }
        });
      }
    } catch (err) {
      console.error('Failed to load system settings', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadSettings();
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      setSaving(true);
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

              {/* Live Preview Card */}
              <div style={{ padding: '12px 16px', background: 'rgba(0, 0, 0, 0.25)', borderRadius: '8px', border: '1px dashed var(--border-color)' }}>
                <span className="text-muted" style={{ fontSize: '12px', display: 'block', marginBottom: '8px' }}>
                  {t('settings.preview_label', 'Live Preview in RTL:')}
                </span>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', background: 'var(--card-bg, #1e293b)', padding: '12px 20px', borderRadius: '8px', direction: 'ltr' }}>
                  <div style={{ width: '36px', height: '36px', borderRadius: '50%', background: 'rgba(var(--primary-rgb, 79, 70, 229), 0.2)', color: 'var(--primary)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 'bold', fontSize: '18px' }}>
                    {cardNavIconStyle === 'arrow' ? '←' : cardNavIconStyle === 'double_chevron' ? '«' : cardNavIconStyle === 'circle_arrow' ? '⮜' : cardNavIconStyle === 'triangle' ? '◀' : '‹'}
                  </div>
                  <div style={{ textAlign: 'center', color: '#94a3b8', fontSize: '13px' }}>
                    [ Flashcard Study Canvas ]
                  </div>
                  <div style={{ width: '36px', height: '36px', borderRadius: '50%', background: 'rgba(var(--primary-rgb, 79, 70, 229), 0.2)', color: 'var(--primary)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 'bold', fontSize: '18px' }}>
                    {cardNavIconStyle === 'arrow' ? '→' : cardNavIconStyle === 'double_chevron' ? '»' : cardNavIconStyle === 'circle_arrow' ? '⮞' : cardNavIconStyle === 'triangle' ? '▶' : '›'}
                  </div>
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

