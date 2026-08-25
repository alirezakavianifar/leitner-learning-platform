import React, { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { localizeNumber, formatPrice } from '../../i18n';
import { api } from '../../services/api';
import type { Purchase, AdminModule } from '../../types';
import { useToast } from '../../components/ToastContext';

export const PurchasesView: React.FC = () => {
  const { t } = useTranslation();
  const toast = useToast();

  const [purchases, setPurchases] = useState<Purchase[]>([]);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(15);
  const [totalCount, setTotalCount] = useState(0);
  const [totalRevenue, setTotalRevenue] = useState(0);
  const [loading, setLoading] = useState(true);
  const [exporting, setExporting] = useState(false);

  // Filter States
  const [searchInput, setSearchInput] = useState('');
  const [activeSearch, setActiveSearch] = useState('');
  const [gatewayFilter, setGatewayFilter] = useState('ALL');
  const [statusFilter, setStatusFilter] = useState('ALL');
  const [dateFilter, setDateFilter] = useState('ALL');

  // Customer inspection modal state
  const [selectedUser, setSelectedUser] = useState<any>(null);
  const [userPurchases, setUserPurchases] = useState<any[]>([]);
  const [showUserModal, setShowUserModal] = useState(false);
  const [userModalLoading, setUserModalLoading] = useState(false);

  // Compute ISO date strings for date presets
  const getDateRange = (preset: string) => {
    const now = new Date();
    if (preset === 'TODAY') {
      const start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      return { fromDate: start.toISOString(), toDate: now.toISOString() };
    }
    if (preset === '7DAYS') {
      const start = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
      return { fromDate: start.toISOString(), toDate: now.toISOString() };
    }
    if (preset === '30DAYS') {
      const start = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
      return { fromDate: start.toISOString(), toDate: now.toISOString() };
    }
    return { fromDate: undefined, toDate: undefined };
  };

  // Debounce search input
  useEffect(() => {
    const timer = setTimeout(() => {
      setActiveSearch(searchInput);
      setPage(1);
    }, 350);
    return () => clearTimeout(timer);
  }, [searchInput]);

  const loadPurchases = async () => {
    try {
      setLoading(true);
      const { fromDate, toDate } = getDateRange(dateFilter);

      const data = await api.admin.getPurchases({
        search: activeSearch || undefined,
        status: statusFilter !== 'ALL' ? statusFilter : undefined,
        gateway: gatewayFilter !== 'ALL' ? gatewayFilter : undefined,
        fromDate,
        toDate,
        page,
        pageSize
      });

      if (data.success) {
        setPurchases(data.purchases);
        setTotalCount(data.total_count);
        setTotalRevenue(data.total_revenue || 0);
      }
    } catch (err: any) {
      console.error(err);
      toast.showError('خطا در دریافت لیست خریدها و تراکنش‌ها');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadPurchases();
  }, [page, pageSize, activeSearch, gatewayFilter, statusFilter, dateFilter]);

  const handleExportCsv = async () => {
    try {
      setExporting(true);
      const { fromDate, toDate } = getDateRange(dateFilter);
      await api.admin.exportPurchases({
        search: activeSearch || undefined,
        status: statusFilter !== 'ALL' ? statusFilter : undefined,
        gateway: gatewayFilter !== 'ALL' ? gatewayFilter : undefined,
        fromDate,
        toDate,
        fallbackData: purchases
      });
      toast.showSuccess('فایل اکسل با موفقیت دانلود شد.');
    } catch (err: any) {
      toast.showError(err.message || 'خطا در خروجی گرفتن از خریدها');
    } finally {
      setExporting(false);
    }
  };

  const handleInspectUser = async (userId: string) => {
    try {
      setUserModalLoading(true);
      setShowUserModal(true);
      const res = await api.admin.getUser(userId);
      if (res.success) {
        setSelectedUser(res.user);
        setUserPurchases(res.purchases || []);
      }
    } catch (err: any) {
      toast.showError('خطا در دریافت جزئیات کاربر');
      setShowUserModal(false);
    } finally {
      setUserModalLoading(false);
    }
  };

  const handleCopyTransaction = (txId: string) => {
    if (navigator.clipboard) {
      navigator.clipboard.writeText(txId);
      toast.showSuccess('شناسه تراکنش در حافظه کپی شد.');
    }
  };

  const completedCount = purchases.filter((p) => p.status === 'COMPLETED').length;
  const successRate = purchases.length > 0 ? Math.round((completedCount / purchases.length) * 100) : 100;

  return (
    <div>
      {/* 1. Dynamic KPI Summary Strip */}
      <div className="dashboard-grid" style={{ marginBottom: '24px' }}>
        <div className="stat-card cyan">
          <div className="stat-label">{t('purchases.kpi_total_count', 'Total Filtered Purchases')}</div>
          <div className="stat-val">{localizeNumber(totalCount)}</div>
        </div>

        <div className="stat-card green">
          <div className="stat-label">{t('purchases.kpi_total_revenue', 'Total Filtered Revenue')}</div>
          <div className="stat-val">{formatPrice(totalRevenue)}</div>
        </div>

        <div className="stat-card yellow">
          <div className="stat-label">{t('purchases.kpi_success_rate', 'Success Rate')}</div>
          <div className="stat-val">%{localizeNumber(successRate)}</div>
        </div>
      </div>

      {/* 2. Main Purchases Container */}
      <div className="table-container">
        {/* Header & Title */}
        <div className="table-header" style={{ flexWrap: 'wrap', gap: '16px' }}>
          <div>
            <h2 style={{ margin: 0 }}>{t('purchases.title')}</h2>
            <p style={{ margin: '4px 0 0', color: 'var(--text-muted)', fontSize: '13px' }}>
              مدیریت، فیلتر و جستجوی پیشرفته تراکنش‌های ثبت‌شده در تمامی درگاه‌ها
            </p>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <button
              className="btn btn-secondary"
              onClick={handleExportCsv}
              disabled={exporting || totalCount === 0}
              style={{ display: 'flex', alignItems: 'center', gap: '8px' }}
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
                <polyline points="7 10 12 15 17 10" />
                <line x1="12" y1="15" x2="12" y2="3" />
              </svg>
              {exporting ? t('purchases.exporting', 'Exporting...') : t('purchases.export_csv', 'Export CSV')}
            </button>
          </div>
        </div>

        {/* 3. Search & Filter Bar */}
        <div
          style={{
            padding: '16px 24px',
            background: 'rgba(255, 255, 255, 0.015)',
            borderBottom: '1px solid var(--border-color)',
            display: 'flex',
            flexWrap: 'wrap',
            gap: '12px',
            alignItems: 'center'
          }}
        >
          {/* Search Box */}
          <div style={{ flex: '1 1 260px', position: 'relative' }}>
            <input
              type="text"
              className="form-control"
              placeholder={t('purchases.search_placeholder', 'Search by mobile, username, or transaction ID...')}
              value={searchInput}
              onChange={(e) => setSearchInput(e.target.value)}
              style={{
                width: '100%',
                paddingLeft: '36px',
                background: 'var(--bg-input, rgba(255, 255, 255, 0.05))',
                borderRadius: 'var(--radius-sm, 6px)'
              }}
            />
            {searchInput && (
              <button
                type="button"
                onClick={() => setSearchInput('')}
                style={{
                  position: 'absolute',
                  left: '10px',
                  top: '50%',
                  transform: 'translateY(-50%)',
                  background: 'transparent',
                  border: 'none',
                  color: 'var(--text-muted)',
                  cursor: 'pointer',
                  fontSize: '14px'
                }}
              >
                ✕
              </button>
            )}
          </div>

          {/* Gateway Filter */}
          <div style={{ minWidth: '150px' }}>
            <select
              className="form-control"
              value={gatewayFilter}
              onChange={(e) => {
                setGatewayFilter(e.target.value);
                setPage(1);
              }}
              style={{ width: '100%', borderRadius: 'var(--radius-sm, 6px)' }}
            >
              <option value="ALL">{t('purchases.gateway_all', 'All Gateways')}</option>
              <option value="ZARINPAL">{t('purchases.gateway_zarinpal', 'ZarinPal')}</option>
              <option value="BAZAAR">{t('purchases.gateway_bazaar', 'Cafe Bazaar')}</option>
              <option value="MYKET">{t('purchases.gateway_myket', 'Myket')}</option>
              <option value="DIRECT">{t('purchases.gateway_direct', 'Direct (Manual)')}</option>
            </select>
          </div>

          {/* Status Filter */}
          <div style={{ minWidth: '150px' }}>
            <select
              className="form-control"
              value={statusFilter}
              onChange={(e) => {
                setStatusFilter(e.target.value);
                setPage(1);
              }}
              style={{ width: '100%', borderRadius: 'var(--radius-sm, 6px)' }}
            >
              <option value="ALL">{t('purchases.status_all', 'All Statuses')}</option>
              <option value="COMPLETED">{t('purchases.status_completed', 'Completed')}</option>
              <option value="PENDING">{t('purchases.status_pending', 'Pending')}</option>
            </select>
          </div>

          {/* Date Filter */}
          <div style={{ minWidth: '150px' }}>
            <select
              className="form-control"
              value={dateFilter}
              onChange={(e) => {
                setDateFilter(e.target.value);
                setPage(1);
              }}
              style={{ width: '100%', borderRadius: 'var(--radius-sm, 6px)' }}
            >
              <option value="ALL">{t('purchases.date_all', 'All Time')}</option>
              <option value="TODAY">{t('purchases.date_today', 'Today')}</option>
              <option value="7DAYS">{t('purchases.date_7days', 'Last 7 Days')}</option>
              <option value="30DAYS">{t('purchases.date_30days', 'Last 30 Days')}</option>
            </select>
          </div>

          {/* Clear Filters Button */}
          {(searchInput || gatewayFilter !== 'ALL' || statusFilter !== 'ALL' || dateFilter !== 'ALL') && (
            <button
              className="btn btn-secondary"
              onClick={() => {
                setSearchInput('');
                setActiveSearch('');
                setGatewayFilter('ALL');
                setStatusFilter('ALL');
                setDateFilter('ALL');
                setPage(1);
              }}
              style={{ fontSize: '12px' }}
            >
              پاک کردن فیلترها
            </button>
          )}
        </div>

        {/* 4. Purchases Table */}
        {loading ? (
          <div className="text-center p-24" style={{ padding: '48px', color: 'var(--text-muted)' }}>
            {t('login.verifying', 'Loading...')}
          </div>
        ) : (
          <table className="data-table">
            <thead>
              <tr>
                <th>{t('purchases.th_user')}</th>
                <th>{t('users.th_mobile')}</th>
                <th>{t('purchases.th_course')}</th>
                <th>{t('purchases.th_amount', 'Amount')}</th>
                <th>{t('purchases.th_gateway')}</th>
                <th>{t('purchases.th_transaction_id', 'Transaction ID')}</th>
                <th>{t('purchases.th_status')}</th>
                <th>{t('purchases.th_date')}</th>
              </tr>
            </thead>
            <tbody>
              {purchases.length === 0 ? (
                <tr>
                  <td colSpan={8} className="text-center text-muted" style={{ padding: '40px' }}>
                    {t('purchases.no_purchases', 'No purchase records found.')}
                  </td>
                </tr>
              ) : (
                purchases.map((purchase) => (
                  <tr key={purchase.purchase_id}>
                    <td>
                      <button
                        type="button"
                        onClick={() => handleInspectUser(purchase.user_id)}
                        style={{
                          background: 'none',
                          border: 'none',
                          padding: 0,
                          color: 'var(--primary-hover, #6366f1)',
                          fontWeight: 600,
                          cursor: 'pointer',
                          textAlign: 'right',
                          textDecoration: 'underline',
                          fontSize: '14px'
                        }}
                      >
                        {purchase.username || 'کاربر مهمان'}
                      </button>
                    </td>
                    <td style={{ direction: 'ltr', textAlign: 'right' }}>
                      {localizeNumber(purchase.mobile_number)}
                    </td>
                    <td>
                      <div style={{ fontWeight: 500, color: 'var(--text-inverse)' }}>
                        {purchase.course_title}
                      </div>
                    </td>
                    <td>
                      <span style={{ fontWeight: 600, color: 'var(--accent-green, #10b981)' }}>
                        {formatPrice(purchase.course_price || 0)}
                      </span>
                    </td>
                    <td>
                      <span
                        className="badge admin"
                        style={{
                          background: 'rgba(255, 255, 255, 0.05)',
                          color: 'var(--text-main)',
                          border: '1px solid var(--border-color)'
                        }}
                      >
                        {purchase.payment_provider.toUpperCase().includes('DIRECT')
                          ? t('purchases.direct')
                          : purchase.payment_provider.toUpperCase().includes('BAZAAR') || purchase.payment_provider.toUpperCase().includes('CAF')
                          ? t('purchases.bazaar')
                          : purchase.payment_provider.toUpperCase().includes('MYKET')
                          ? t('purchases.myket')
                          : purchase.payment_provider.toUpperCase().includes('ZARINPAL')
                          ? t('purchases.gateway_zarinpal')
                          : purchase.payment_provider}
                      </span>
                    </td>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                        <code style={{ fontSize: '11px', background: 'rgba(0,0,0,0.2)', padding: '2px 6px', borderRadius: '4px' }}>
                          {localizeNumber(purchase.transaction_id)}
                        </code>
                        <button
                          type="button"
                          onClick={() => handleCopyTransaction(purchase.transaction_id)}
                          title="کپی شناسه تراکنش"
                          style={{
                            background: 'transparent',
                            border: 'none',
                            cursor: 'pointer',
                            color: 'var(--text-muted)',
                            padding: '2px'
                          }}
                        >
                          <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                            <rect x="9" y="9" width="13" height="13" rx="2" ry="2" />
                            <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" />
                          </svg>
                        </button>
                      </div>
                    </td>
                    <td>
                      <span className={`badge ${purchase.status.toLowerCase()}`}>
                        {purchase.status === 'COMPLETED' ? t('purchases.status_completed') : t('purchases.status_pending')}
                      </span>
                    </td>
                    <td style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                      {localizeNumber(new Date(purchase.purchased_at).toLocaleString())}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        )}

        {/* 5. Pagination & Page Size Toolbar */}
        <div
          style={{
            padding: '16px 24px',
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
            borderTop: '1px solid var(--border-color)',
            flexWrap: 'wrap',
            gap: '12px'
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '13px', color: 'var(--text-muted)' }}>
            <span>{t('purchases.page_size', 'Rows per page:')}</span>
            <select
              className="form-control"
              value={pageSize}
              onChange={(e) => {
                setPageSize(Number(e.target.value));
                setPage(1);
              }}
              style={{ width: '70px', padding: '4px 8px', borderRadius: 'var(--radius-sm, 6px)' }}
            >
              <option value={15}>15</option>
              <option value={50}>50</option>
              <option value={100}>100</option>
            </select>
            <span>
              نمایش {localizeNumber(purchases.length > 0 ? (page - 1) * pageSize + 1 : 0)} تا{' '}
              {localizeNumber(Math.min(page * pageSize, totalCount))} از {localizeNumber(totalCount)} مورد
            </span>
          </div>

          <div style={{ display: 'flex', gap: '8px' }}>
            <button
              className="btn btn-secondary"
              disabled={page === 1 || loading}
              onClick={() => setPage((p) => p - 1)}
            >
              {t('users.prev', 'Prev')}
            </button>
            <button
              className="btn btn-secondary"
              disabled={page * pageSize >= totalCount || loading}
              onClick={() => setPage((p) => p + 1)}
            >
              {t('users.next', 'Next')}
            </button>
          </div>
        </div>
      </div>

      {/* 6. Customer 360 Inspection Modal */}
      {showUserModal && (
        <div
          style={{
            position: 'fixed',
            inset: 0,
            backgroundColor: 'rgba(0, 0, 0, 0.75)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 1000,
            padding: '16px'
          }}
        >
          <div
            style={{
              background: 'var(--bg-sidebar, #1e1e2d)',
              border: '1px solid var(--border-color)',
              borderRadius: 'var(--radius-lg, 12px)',
              width: '100%',
              maxWidth: '560px',
              maxHeight: '90vh',
              overflowY: 'auto',
              boxShadow: '0 20px 40px rgba(0, 0, 0, 0.5)',
              padding: '24px'
            }}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
              <h3 style={{ margin: 0, fontSize: '18px', color: 'var(--text-inverse)' }}>
                مشخصات کاربر و تاریخچه دوره‌ها
              </h3>
              <button
                type="button"
                onClick={() => setShowUserModal(false)}
                style={{
                  background: 'transparent',
                  border: 'none',
                  color: 'var(--text-muted)',
                  fontSize: '18px',
                  cursor: 'pointer'
                }}
              >
                ✕
              </button>
            </div>

            {userModalLoading ? (
              <div style={{ padding: '32px', textAlign: 'center', color: 'var(--text-muted)' }}>
                {t('login.verifying', 'Loading...')}
              </div>
            ) : selectedUser ? (
              <div>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', marginBottom: '20px' }}>
                  <div style={{ background: 'rgba(255,255,255,0.03)', padding: '10px 14px', borderRadius: '8px' }}>
                    <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>نام کاربری</div>
                    <div style={{ fontWeight: 600, marginTop: '4px' }}>{selectedUser.username || '—'}</div>
                  </div>
                  <div style={{ background: 'rgba(255,255,255,0.03)', padding: '10px 14px', borderRadius: '8px' }}>
                    <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>شماره همراه</div>
                    <div style={{ fontWeight: 600, marginTop: '4px', direction: 'ltr', textAlign: 'right' }}>
                      {localizeNumber(selectedUser.mobile_number)}
                    </div>
                  </div>
                  <div style={{ background: 'rgba(255,255,255,0.03)', padding: '10px 14px', borderRadius: '8px' }}>
                    <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>رشته تحصیلی</div>
                    <div style={{ fontWeight: 500, marginTop: '4px' }}>{selectedUser.educational_field || '—'}</div>
                  </div>
                  <div style={{ background: 'rgba(255,255,255,0.03)', padding: '10px 14px', borderRadius: '8px' }}>
                    <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>مقطع تحصیلی</div>
                    <div style={{ fontWeight: 500, marginTop: '4px' }}>{selectedUser.educational_level || '—'}</div>
                  </div>
                </div>

                <h4 style={{ margin: '16px 0 8px', fontSize: '14px', color: 'var(--text-inverse)' }}>
                  دوره‌های فعال / خریداری شده ({localizeNumber(userPurchases.length)})
                </h4>

                {userPurchases.length === 0 ? (
                  <div style={{ fontSize: '13px', color: 'var(--text-muted)', padding: '12px', background: 'rgba(255,255,255,0.02)', borderRadius: '6px' }}>
                    هیچ دوره‌ای برای این کاربر ثبت نشده است.
                  </div>
                ) : (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                    {userPurchases.map((up: any) => (
                      <div
                        key={up.purchase_id || up.course_id}
                        style={{
                          display: 'flex',
                          justifyContent: 'space-between',
                          alignItems: 'center',
                          padding: '10px 14px',
                          background: 'rgba(255, 255, 255, 0.03)',
                          borderRadius: '6px',
                          border: '1px solid var(--border-color)'
                        }}
                      >
                        <span style={{ fontSize: '13px', fontWeight: 500 }}>{up.course_title}</span>
                        <span className={`badge ${up.status.toLowerCase()}`}>
                          {up.status === 'COMPLETED' ? t('purchases.status_completed') : t('purchases.status_pending')}
                        </span>
                      </div>
                    ))}
                  </div>
                )}

                <div style={{ marginTop: '24px', display: 'flex', justifyContent: 'flex-end' }}>
                  <button className="btn btn-secondary" onClick={() => setShowUserModal(false)}>
                    بستن
                  </button>
                </div>
              </div>
            ) : null}
          </div>
        </div>
      )}
    </div>
  );
};

export const PurchasesModule: AdminModule = {
  id: 'purchases',
  name: 'Purchases',
  icon: (props) => (
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...props}>
      <rect x="2" y="4" width="20" height="16" rx="2" ry="2" />
      <line x1="12" y1="1" x2="12" y2="4" />
      <line x1="12" y1="20" x2="12" y2="23" />
      <line x1="2" y1="10" x2="22" y2="10" />
    </svg>
  ),
  component: PurchasesView
};
