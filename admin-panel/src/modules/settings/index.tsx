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

  const [rotationInterval, setRotationInterval] = useState(4);
  const [maxBannerCount, setMaxBannerCount] = useState(5);

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
            case 'rotation_interval_seconds':
              setRotationInterval(parseInt(cfg.value) || 4);
              break;
            case 'max_banner_count':
              setMaxBannerCount(parseInt(cfg.value) || 5);
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
        { key: 'rotation_interval_seconds', value: rotationInterval.toString() },
        { key: 'max_banner_count', value: maxBannerCount.toString() },
      ];
      await api.admin.updateConfig(payload);
      toast.showSuccess(t('settings.save_success', 'تنظیمات با موفقیت ذخیره شدند.'));
      loadSettings();
    } catch (err: any) {
      toast.showError(err.message || t('settings.save_failed', 'Failed to save configuration settings.'));
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

