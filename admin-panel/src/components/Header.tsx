import React, { useState } from 'react';
import { removeToken } from '../services/api';

interface HeaderProps {
  moduleName: string;
  adminUsername: string;
  onLogout: () => void;
}

export const Header: React.FC<HeaderProps> = ({ moduleName, adminUsername, onLogout }) => {
  const [showConfirm, setShowConfirm] = useState(false);

  const handleLogoutClick = () => {
    setShowConfirm(true);
  };

  const handleConfirmLogout = () => {
    removeToken();
    setShowConfirm(false);
    onLogout();
  };

  return (
    <header className="app-header">
      <h2 className="header-title">{moduleName}</h2>
      
      <div className="header-user">
        <div className="user-info">
          <div className="user-name">{adminUsername}</div>
          <div className="user-role">System Administrator</div>
        </div>
        <button className="logout-btn" onClick={handleLogoutClick}>
          Log Out
        </button>
      </div>

      {/* Logout Confirmation Dialog */}
      {showConfirm && (
        <div className="modal-overlay" style={{ zIndex: 2000 }}>
          <div className="modal-content" style={{ maxWidth: '380px' }}>
            <div className="modal-header">
              <h3>Confirm Logout</h3>
              <button className="refresh-captcha-btn" style={{ fontSize: '20px' }} onClick={() => setShowConfirm(false)}>&times;</button>
            </div>
            <div className="modal-body">
              <p style={{ fontSize: '14px', color: 'var(--text-main)' }}>
                Are you sure you want to end your administration session?
              </p>
            </div>
            <div className="modal-footer">
              <button className="btn btn-secondary" onClick={() => setShowConfirm(false)}>
                Cancel
              </button>
              <button className="btn btn-danger" onClick={handleConfirmLogout}>
                Confirm Logout
              </button>
            </div>
          </div>
        </div>
      )}
    </header>
  );
};
