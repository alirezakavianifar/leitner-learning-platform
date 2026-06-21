import React, { useEffect, useState } from 'react';
import { api } from '../../services/api';
import type { Purchase, AdminModule } from '../../types';

export const PurchasesView: React.FC = () => {
  const [purchases, setPurchases] = useState<Purchase[]>([]);
  const [page, setPage] = useState(1);
  const [totalCount, setTotalCount] = useState(0);
  const [loading, setLoading] = useState(true);

  const loadPurchases = async () => {
    try {
      setLoading(true);
      const data = await api.admin.getPurchases(page, 15);
      if (data.success) {
        setPurchases(data.purchases);
        setTotalCount(data.total_count);
      }
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadPurchases();
  }, [page]);

  return (
    <div>
      <div className="table-container">
        <div className="table-header">
          <h2>Purchase & Enrolment Logs</h2>
          <div className="stat-label">Total: {totalCount} records</div>
        </div>

        {loading ? (
          <div className="text-center p-24">Loading transaction records...</div>
        ) : (
          <table className="data-table">
            <thead>
              <tr>
                <th>Student</th>
                <th>Mobile Number</th>
                <th>Course</th>
                <th>Payment Provider</th>
                <th>Transaction ID</th>
                <th>Status</th>
                <th>Date</th>
              </tr>
            </thead>
            <tbody>
              {purchases.length === 0 ? (
                <tr>
                  <td colSpan={7} className="text-center text-muted">No purchase records logged.</td>
                </tr>
              ) : (
                purchases.map((purchase) => (
                  <tr key={purchase.purchase_id}>
                    <td>
                      <div style={{ fontWeight: 600, color: 'var(--text-inverse)' }}>{purchase.username}</div>
                    </td>
                    <td>{purchase.mobile_number}</td>
                    <td>{purchase.course_title}</td>
                    <td>
                      <span className="badge admin" style={{ background: 'rgba(255, 255, 255, 0.05)', color: 'var(--text-main)' }}>
                        {purchase.payment_provider}
                      </span>
                    </td>
                    <td>
                      <code style={{ fontSize: '12px' }}>{purchase.transaction_id}</code>
                    </td>
                    <td>
                      <span className={`badge ${purchase.status.toLowerCase()}`}>
                        {purchase.status}
                      </span>
                    </td>
                    <td>{new Date(purchase.purchased_at).toLocaleString()}</td>
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
            <button className="btn btn-secondary" disabled={page * 15 >= totalCount} onClick={() => setPage(page + 1)}>
              Next
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

export const PurchasesModule: AdminModule = {
  id: 'purchases',
  name: 'Purchases',
  icon: (props) => (
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...props}>
      <rect x="2" y="4" width="20" height="16" rx="2" ry="2" />
      <line x1="2" y1="10" x2="22" y2="10" />
    </svg>
  ),
  component: PurchasesView
};
