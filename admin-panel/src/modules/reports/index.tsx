import React, { useEffect, useState } from 'react';
import { api } from '../../services/api';
import type { FlashcardReport, AdminModule } from '../../types';

export const ReportsView: React.FC = () => {
  const [reports, setReports] = useState<FlashcardReport[]>([]);
  const [filterStatus, setFilterStatus] = useState<string>('PENDING');
  const [loading, setLoading] = useState(true);

  const loadReports = async () => {
    try {
      setLoading(true);
      const data = await api.admin.getReports(filterStatus);
      setReports(data);
    } catch (err) {
      console.error(err);
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
        alert(`Report marked as ${newStatus}`);
        loadReports();
      }
    } catch (err: any) {
      alert(err.message || 'Failed to update report status.');
    }
  };

  return (
    <div>
      <div className="table-container">
        <div className="table-header">
          <h2>Flashcard Content Reports</h2>
          <div style={{ display: 'flex', gap: '8px' }}>
            {['PENDING', 'REVIEWED', 'RESOLVED', ''].map((status) => (
              <button
                key={status}
                onClick={() => setFilterStatus(status)}
                className={`btn ${filterStatus === status ? '' : 'btn-secondary'}`}
                style={{ padding: '6px 12px', fontSize: '13px' }}
              >
                {status === '' ? 'All' : status}
              </button>
            ))}
          </div>
        </div>

        {loading ? (
          <div className="text-center p-24">Loading typo reports...</div>
        ) : (
          <table className="data-table">
            <thead>
              <tr>
                <th>Submitted By</th>
                <th>Course</th>
                <th>Card No.</th>
                <th>Description</th>
                <th>Submitted At</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {reports.length === 0 ? (
                <tr>
                  <td colSpan={7} className="text-center text-muted">No typo reports logged.</td>
                </tr>
              ) : (
                reports.map((report) => (
                  <tr key={report.report_id}>
                    <td>
                      <div style={{ fontWeight: 600, color: 'var(--text-inverse)' }}>{report.username}</div>
                      <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>{report.mobile_number}</div>
                    </td>
                    <td>{report.course_title}</td>
                    <td>
                      <span className="badge admin" style={{ fontSize: '12px' }}>#{report.card_number}</span>
                    </td>
                    <td style={{ maxWidth: '250px', wordBreak: 'break-word' }}>{report.report_text}</td>
                    <td>{new Date(report.submitted_at).toLocaleString()}</td>
                    <td>
                      <span className={`badge ${report.status.toLowerCase()}`}>
                        {report.status}
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
                            Mark Reviewed
                          </button>
                        )}
                        {report.status !== 'RESOLVED' && (
                          <button
                            className="btn"
                            style={{ padding: '4px 8px', fontSize: '11px', background: 'var(--accent-green)' }}
                            onClick={() => updateStatus(report.report_id, 'RESOLVED')}
                          >
                            Resolve
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
