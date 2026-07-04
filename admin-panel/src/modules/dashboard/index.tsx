import React, { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { localizeNumber } from '../../i18n';
import { api } from '../../services/api';
import type { AdminModule } from '../../types';

export const DashboardView: React.FC = () => {
  const { t } = useTranslation();
  const [stats, setStats] = useState<any>(null);
  const [recentLogs, setRecentLogs] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    async function loadDashboard() {
      try {
        setLoading(true);
        const data = await api.admin.getStats();
        if (data.success) {
          setStats(data.stats);
        }
        
        const logsData = await api.admin.getAuditLogs(1, 6);
        if (logsData.success) {
          setRecentLogs(logsData.logs);
        }
      } catch (err: any) {
        setError(err.message || 'Failed to load dashboard statistics.');
      } finally {
        setLoading(false);
      }
    }

    loadDashboard();
  }, []);

  if (loading) {
    return <div className="text-center p-24">{t('login.verifying', 'Loading...')}</div>;
  }

  if (error) {
    return <div className="text-center p-24 text-danger">{error}</div>;
  }

  return (
    <div>
      <div className="dashboard-grid">
        <div className="stat-card">
          <div className="stat-label">{t('dashboard.total_users')}</div>
          <div className="stat-val">{localizeNumber(stats?.users_count ?? 0)}</div>
        </div>
        <div className="stat-card cyan">
          <div className="stat-label">{t('dashboard.available_courses')}</div>
          <div className="stat-val">{localizeNumber(stats?.courses_count ?? 0)}</div>
        </div>
        <div className="stat-card green">
          <div className="stat-label">{t('dashboard.paid_enrolments')}</div>
          <div className="stat-val">{localizeNumber(stats?.purchases_count ?? 0)}</div>
        </div>
        <div className="stat-card yellow">
          <div className="stat-label">{t('dashboard.pending_reports')}</div>
          <div className="stat-val">{localizeNumber(stats?.pending_reports_count ?? 0)}</div>
        </div>
        <div className="stat-card red">
          <div className="stat-label">{t('dashboard.active_cards')}</div>
          <div className="stat-val">{localizeNumber(stats?.active_learning_cards ?? 0)}</div>
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '24px', marginTop: '32px' }}>
        {/* CSS-based Custom Chart */}
        <div className="table-container p-24">
          <h3 style={{ marginBottom: '16px' }}>{t('dashboard.enrolment_dist')}</h3>
          <p className="stat-label" style={{ marginBottom: '24px' }}>{t('dashboard.enrolment_subtitle')}</p>
          <div className="graph-container">
            <div className="graph-row">
              <div className="graph-label">{t('purchases.direct', 'Direct (Manual)')}</div>
              <div className="graph-bar-wrapper">
                <div className="graph-bar-fill" style={{ width: '85%' }}></div>
              </div>
              <div className="graph-value">{localizeNumber('85%')}</div>
            </div>
            <div className="graph-row">
              <div className="graph-label">{t('purchases.bazaar', 'Cafe Bazaar')}</div>
              <div className="graph-bar-wrapper">
                <div className="graph-bar-fill" style={{ width: '12%', background: 'var(--accent-cyan)' }}></div>
              </div>
              <div className="graph-value">{localizeNumber('12%')}</div>
            </div>
            <div className="graph-row">
              <div className="graph-label">{t('purchases.myket', 'Myket Store')}</div>
              <div className="graph-bar-wrapper">
                <div className="graph-bar-fill" style={{ width: '3%', background: 'var(--accent-yellow)' }}></div>
              </div>
              <div className="graph-value">{localizeNumber('3%')}</div>
            </div>
          </div>
        </div>

        {/* Recent Activity Log */}
        <div className="table-container p-24" style={{ display: 'flex', flexDirection: 'column' }}>
          <h3 style={{ marginBottom: '16px' }}>{t('dashboard.recent_audit')}</h3>
          <p className="stat-label" style={{ marginBottom: '24px' }}>{t('dashboard.audit_subtitle')}</p>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '14px', flex: 1 }}>
            {recentLogs.length === 0 ? (
              <div className="text-muted" style={{ fontStyle: 'italic', fontSize: '13px' }}>{t('dashboard.no_audit')}</div>
            ) : (
              recentLogs.map((log) => (
                <div key={log.id} style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px', borderBottom: '1px solid var(--border-color)', paddingBottom: '8px' }}>
                  <div>
                    <span style={{ fontWeight: 600, color: 'var(--text-inverse)' }}>{log.actor_username}</span>
                    <span className="badge admin" style={{ fontSize: '9px', marginLeft: '8px', marginRight: '8px', padding: '2px 4px' }}>{log.action_type}</span>
                    <div style={{ color: 'var(--text-muted)', fontSize: '11px', marginTop: '4px' }}>Target: {log.target_entity}</div>
                  </div>
                  <div style={{ color: 'var(--text-muted)', fontSize: '11px' }}>
                    {localizeNumber(new Date(log.timestamp).toLocaleTimeString())}
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export const DashboardModule: AdminModule = {
  id: 'dashboard',
  name: 'Dashboard',
  icon: (props) => (
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...props}>
      <rect x="3" y="3" width="7" height="9" />
      <rect x="14" y="3" width="7" height="5" />
      <rect x="14" y="12" width="7" height="9" />
      <rect x="3" y="16" width="7" height="5" />
    </svg>
  ),
  component: DashboardView
};
