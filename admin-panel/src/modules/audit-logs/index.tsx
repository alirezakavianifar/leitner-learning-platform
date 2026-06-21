import React, { useEffect, useState } from 'react';
import { api } from '../../services/api';
import type { AuditLog, AdminModule } from '../../types';

export const AuditLogsView: React.FC = () => {
  const [logs, setLogs] = useState<AuditLog[]>([]);
  const [page, setPage] = useState(1);
  const [totalCount, setTotalCount] = useState(0);
  const [loading, setLoading] = useState(true);
  const [selectedLog, setSelectedLog] = useState<AuditLog | null>(null);

  const loadLogs = async () => {
    try {
      setLoading(true);
      const data = await api.admin.getAuditLogs(page, 20);
      if (data.success) {
        const normalized = data.logs.map((l: any) => ({
          id: l.id,
          actor_username: l.actor_username,
          action_type: l.action_type,
          target_entity: l.target_entity,
          before_value: l.before_value,
          after_value: l.after_value,
          timestamp: l.timestamp
        }));
        setLogs(normalized);
        setTotalCount(data.total_count);
      }
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadLogs();
  }, [page]);

  const formatJson = (val?: string) => {
    if (!val) return 'None';
    try {
      const parsed = JSON.parse(val);
      return JSON.stringify(parsed, null, 2);
    } catch {
      return val;
    }
  };

  return (
    <div>
      <div className="table-container">
        <div className="table-header">
          <h2>Security & System Audit Trails</h2>
          <div className="stat-label">Total: {totalCount} actions recorded</div>
        </div>

        {loading ? (
          <div className="text-center p-24">Loading audit trails...</div>
        ) : (
          <table className="data-table">
            <thead>
              <tr>
                <th>Actor Username</th>
                <th>Action</th>
                <th>Target Resource</th>
                <th>Timestamp</th>
                <th>State Diffs</th>
              </tr>
            </thead>
            <tbody>
              {logs.length === 0 ? (
                <tr>
                  <td colSpan={5} className="text-center text-muted">No admin actions recorded yet.</td>
                </tr>
              ) : (
                logs.map((log) => (
                  <tr key={log.id}>
                    <td>
                      <div style={{ fontWeight: 600, color: 'var(--text-inverse)' }}>{log.actor_username}</div>
                    </td>
                    <td>
                      <span className="badge admin" style={{ fontSize: '11px' }}>{log.action_type}</span>
                    </td>
                    <td>{log.target_entity}</td>
                    <td>{new Date(log.timestamp).toLocaleString()}</td>
                    <td>
                      {(log.before_value || log.after_value) ? (
                        <button className="btn btn-secondary" style={{ padding: '4px 8px', fontSize: '11px' }} onClick={() => setSelectedLog(log)}>
                          Compare States
                        </button>
                      ) : (
                        <span style={{ fontStyle: 'italic', color: 'var(--text-muted)', fontSize: '12px' }}>No State Change</span>
                      )}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        )}

        <div style={{ padding: '16px 24px', display: 'flex', justifyContent: 'flex-end', borderTop: '1px solid var(--border-color)' }}>
          <div style={{ display: 'flex', gap: '8px' }}>
            <button className="btn btn-secondary" disabled={page === 1} onClick={() => setPage(page - 1)}>
              Prev
            </button>
            <button className="btn btn-secondary" disabled={page * 20 >= totalCount} onClick={() => setPage(page + 1)}>
              Next
            </button>
          </div>
        </div>
      </div>

      {/* JSON Diff State Modal */}
      {selectedLog && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '800px' }}>
            <div className="modal-header">
              <h3>State Change Detail: {selectedLog.action_type}</h3>
              <button className="refresh-captcha-btn" style={{ fontSize: '20px' }} onClick={() => setSelectedLog(null)}>&times;</button>
            </div>
            <div className="modal-body" style={{ maxHeight: '80vh' }}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                <div>
                  <h4 style={{ color: 'var(--accent-red)', marginBottom: '8px', fontSize: '13px', textTransform: 'uppercase' }}>Before State</h4>
                  <pre style={{ backgroundColor: 'var(--bg-main)', color: '#fda4af', padding: '12px', borderRadius: '6px', fontSize: '12px', overflowX: 'auto', maxHeight: '400px', border: '1px solid rgba(239, 68, 68, 0.2)' }}>
                    {formatJson(selectedLog.before_value)}
                  </pre>
                </div>
                <div>
                  <h4 style={{ color: 'var(--accent-green)', marginBottom: '8px', fontSize: '13px', textTransform: 'uppercase' }}>After State</h4>
                  <pre style={{ backgroundColor: 'var(--bg-main)', color: '#6ee7b7', padding: '12px', borderRadius: '6px', fontSize: '12px', overflowX: 'auto', maxHeight: '400px', border: '1px solid rgba(16, 185, 129, 0.2)' }}>
                    {formatJson(selectedLog.after_value)}
                  </pre>
                </div>
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn btn-secondary" onClick={() => setSelectedLog(null)}>
                Close State Inspector
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export const AuditLogsModule: AdminModule = {
  id: 'audit-logs',
  name: 'Audit Logs',
  icon: (props) => (
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...props}>
      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
      <polyline points="14 2 14 8 20 8" />
      <line x1="16" y1="13" x2="8" y2="13" />
      <line x1="16" y1="17" x2="8" y2="17" />
      <polyline points="10 9 9 9 8 9" />
    </svg>
  ),
  component: AuditLogsView
};
