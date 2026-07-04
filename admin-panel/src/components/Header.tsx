import React, { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { removeToken } from '../services/api';

interface HeaderProps {
  moduleId: string;
  moduleName: string;
  adminUsername: string;
  onLogout: () => void;
}

export const Header: React.FC<HeaderProps> = ({ moduleId, moduleName, adminUsername, onLogout }) => {
  const { t, i18n } = useTranslation();
  const [showConfirm, setShowConfirm] = useState(false);

  const handleLogoutClick = () => {
    setShowConfirm(true);
  };

  const handleConfirmLogout = () => {
    removeToken();
    setShowConfirm(false);
    onLogout();
  };

  const toggleLanguage = () => {
    const nextLang = i18n.language === 'fa' ? 'en' : 'fa';
    i18n.changeLanguage(nextLang);
  };

  return (
    <header className="app-header">
      <h2 className="header-title">{t(`menu.${moduleId}`, moduleName)}</h2>
      
      <div className="header-user">
        <button className="btn btn-secondary language-toggle-btn" onClick={toggleLanguage} style={{ padding: '6px 12px', fontSize: '13px', border: '1px solid var(--border-color)' }}>
          {i18n.language === 'fa' ? 'English' : 'فارسی'}
        </button>

        <div className="user-info">
          <div className="user-name">{adminUsername}</div>
          <div className="user-role">{t('system_admin')}</div>
        </div>
        <button className="logout-btn" onClick={handleLogoutClick}>
          {t('logout')}
        </button>
      </div>

      {/* Logout Confirmation Dialog */}
      {showConfirm && (
        <div className="modal-overlay" style={{ zIndex: 2000 }}>
          <div className="modal-content" style={{ maxWidth: '380px' }}>
            <div className="modal-header">
              <h3>{t('logout_confirm_title', 'Confirm Logout')}</h3>
              <button className="refresh-captcha-btn" style={{ fontSize: '20px' }} onClick={() => setShowConfirm(false)}>&times;</button>
            </div>
            <div className="modal-body">
              <p style={{ fontSize: '14px', color: 'var(--text-main)' }}>
                {t('logout_confirm_desc', 'Are you sure you want to end your administration session?')}
              </p>
            </div>
            <div className="modal-footer">
              <button className="btn btn-secondary" onClick={() => setShowConfirm(false)}>
                {t('courses.btn_cancel', 'Cancel')}
              </button>
              <button className="btn btn-danger" onClick={handleConfirmLogout}>
                {t('logout')}
              </button>
            </div>
          </div>
        </div>
      )}
    </header>
  );
};

