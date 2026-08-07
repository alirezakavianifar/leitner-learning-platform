import React, { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { localizeNumber } from '../../i18n';
import { api } from '../../services/api';
import type { FlashcardReport, AdminModule } from '../../types';
import { useToast } from '../../components/ToastContext';

export const ReportsView: React.FC = () => {
  const { t } = useTranslation();
  const toast = useToast();
  const [reports, setReports] = useState<FlashcardReport[]>([]);
  const [filterStatus, setFilterStatus] = useState<string>('PENDING');
  const [loading, setLoading] = useState(true);

  const loadReports = async () => {
    try {
      setLoading(true);
      const data = await api.admin.getReports(filterStatus);
      setReports(data);
    } catch (err: any) {
      toast.showError(err.message || 'خطا در دریافت لیست گزارش‌ها');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadReports();
  }, [filterStatus]);

  const updateStatus = async (id: string, newStatus: string) => {
    try {
      const res = await api.admin.updateReportStatus(id, newStatus);
      if (res.success) {
        toast.showSuccess(`وضعیت گزارش با موفقیت به ${newStatus === 'RESOLVED' ? 'حل شده' : 'بررسی شده'} تغییر یافت.`);
        loadReports();
      }
    } catch (err: any) {
      toast.showError(err.message || t('reports.alert_failed', 'Failed to update report status.'));
    }
  };

  return (
    <div>
      <div className="table-container">
        <div className="table-header">
          <h2>{t('reports.title')}</h2>
          <div style={{ display: 'flex', gap: '8px' }}>
            {['PENDING', 'REVIEWED', 'RESOLVED', ''].map((status) => (
              <button
                key={status}
                onClick={() => setFilterStatus(status)}
                className={`btn ${filterStatus === status ? '' : 'btn-secondary'}`}
                style={{ padding: '6px 12px', fontSize: '13px' }}
              >
                {status === '' 
                  ? t('reports.filter_all', 'All') 
                  : status === 'PENDING'
                  ? t('reports.status_pending', 'Pending')
                  : status === 'REVIEWED'
                  ? t('reports.status_reviewed', 'Reviewed')
                  : t('reports.status_resolved', 'Resolved')}
              </button>
            ))}
          </div>
        </div>

        {loading ? (
          <div className="text-center p-24">{t('login.verifying', 'Loading...')}</div>
        ) : (
          <table className="data-table">
            <thead>
              <tr>
                <th>{t('reports.th_submitted_by')}</th>
                <th>{t('reports.th_course')}</th>
                <th>{t('reports.th_card_no')}</th>
                <th>{t('reports.th_description')}</th>
                <th>{t('reports.th_submitted_at')}</th>
                <th>{t('reports.th_status')}</th>
                <th>{t('reports.th_actions')}</th>
              </tr>
            </thead>
            <tbody>
              {reports.length === 0 ? (
                <tr>
                  <td colSpan={7} className="text-center text-muted">{t('reports.no_reports')}</td>
                </tr>
              ) : (
                reports.map((report) => (
                  <tr key={report.report_id}>
                    <td>
                      <div style={{ fontWeight: 600, color: 'var(--text-inverse)' }}>{report.username}</div>
                      <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>{localizeNumber(report.mobile_number)}</div>
                    </td>
                    <td>{report.course_title}</td>
                    <td>
                      <span className="badge admin" style={{ fontSize: '12px' }}>#{localizeNumber(report.card_number)}</span>
                    </td>
                    <td style={{ maxWidth: '250px', wordBreak: 'break-word' }}>{report.report_text}</td>
                    <td>{localizeNumber(new Date(report.submitted_at).toLocaleString())}</td>
                    <td>
                      <span className={`badge ${report.status.toLowerCase()}`}>
                        {report.status === 'PENDING'
                          ? t('reports.status_pending', 'Pending')
                          : report.status === 'REVIEWED'
                          ? t('reports.status_reviewed', 'Reviewed')
                          : t('reports.status_resolved', 'Resolved')}
                      </span>
                    </td>
                    <td>
                      <div style={{ display: 'flex', gap: '6px' }}>
                        {report.status !== 'REVIEWED' && (
                          <button
                            className="btn btn-secondary"
                            style={{ padding: '4px 8px', fontSize: '11px' }}
                            onClick={() => updateStatus(report.report_id, 'REVIEWED')}
                          >
                            {t('reports.btn_mark_reviewed')}
                          </button>
                        )}
                        {report.status !== 'RESOLVED' && (
                          <button
                            className="btn"
                            style={{ padding: '4px 8px', fontSize: '11px', background: 'var(--accent-green)' }}
                            onClick={() => updateStatus(report.report_id, 'RESOLVED')}
                          >
                            {t('reports.btn_resolve')}
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
};

export const ReportsModule: AdminModule = {
  id: 'reports',
  name: 'Reports',
  icon: (props) => (
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...props}>
      <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z" />
      <line x1="12" y1="9" x2="12" y2="13" />
      <line x1="12" y1="17" x2="12.01" y2="17" />
    </svg>
  ),
  component: ReportsView
};

