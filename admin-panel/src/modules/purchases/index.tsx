import React, { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { localizeNumber } from '../../i18n';
import { api } from '../../services/api';
import type { Purchase, AdminModule } from '../../types';

export const PurchasesView: React.FC = () => {
  const { t } = useTranslation();
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
          <h2>{t('purchases.title')}</h2>
          <div className="stat-label">{t('users.total') || 'Total'}: {localizeNumber(totalCount)}</div>
        </div>

        {loading ? (
          <div className="text-center p-24">{t('login.verifying', 'Loading...')}</div>
        ) : (
          <table className="data-table">
            <thead>
              <tr>
                <th>{t('purchases.th_user')}</th>
                <th>{t('users.th_mobile')}</th>
                <th>{t('purchases.th_course')}</th>
                <th>{t('purchases.th_gateway')}</th>
                <th>{t('purchases.th_transaction_id', 'Transaction ID')}</th>
                <th>{t('purchases.th_status')}</th>
                <th>{t('purchases.th_date')}</th>
              </tr>
            </thead>
            <tbody>
              {purchases.length === 0 ? (
                <tr>
                  <td colSpan={7} className="text-center text-muted">{t('purchases.no_purchases', 'No purchase records logged.')}</td>
                </tr>
              ) : (
                purchases.map((purchase) => (
                  <tr key={purchase.purchase_id}>
                    <td>
                      <div style={{ fontWeight: 600, color: 'var(--text-inverse)' }}>{purchase.username}</div>
                    </td>
                    <td>{localizeNumber(purchase.mobile_number)}</td>
                    <td>{purchase.course_title}</td>
                    <td>
                      <span className="badge admin" style={{ background: 'rgba(255, 255, 255, 0.05)', color: 'var(--text-main)' }}>
                        {purchase.payment_provider.toLowerCase().includes('direct')
                          ? t('purchases.direct')
                          : purchase.payment_provider.toLowerCase().includes('bazaar') || purchase.payment_provider.toLowerCase().includes('caf')
                          ? t('purchases.bazaar')
                          : purchase.payment_provider.toLowerCase().includes('myket')
                          ? t('purchases.myket')
                          : purchase.payment_provider}
                      </span>
                    </td>
                    <td>
                      <code style={{ fontSize: '12px' }}>{localizeNumber(purchase.transaction_id)}</code>
                    </td>
                    <td>
                      <span className={`badge ${purchase.status.toLowerCase()}`}>
                        {purchase.status === 'COMPLETED' ? t('purchases.status_completed') : t('purchases.status_pending')}
                      </span>
                    </td>
                    <td>{localizeNumber(new Date(purchase.purchased_at).toLocaleString())}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        )}

        <div style={{ padding: '16px 24px', display: 'flex', justifyContent: 'flex-end', borderTop: '1px solid var(--border-color)' }}>
          <div style={{ display: 'flex', gap: '8px' }}>
            <button className="btn btn-secondary" disabled={page === 1} onClick={() => setPage(page - 1)}>
              {t('users.prev', 'Prev')}
            </button>
            <button className="btn btn-secondary" disabled={page * 15 >= totalCount} onClick={() => setPage(page + 1)}>
              {t('users.next', 'Next')}
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

