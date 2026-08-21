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

