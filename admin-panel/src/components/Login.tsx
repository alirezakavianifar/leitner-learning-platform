import React, { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { localizeNumber } from '../i18n';
import { api, setToken } from '../services/api';

interface LoginProps {
  onLoginSuccess: (token: string, username: string) => void;
}

export const Login: React.FC<LoginProps> = ({ onLoginSuccess }) => {
  const { t } = useTranslation();
  const [step, setStep] = useState<'REQUEST' | 'VERIFY'>('REQUEST');
  const [mobileNumber, setMobileNumber] = useState('');
  const [otpCode, setOtpCode] = useState('');
  
  // CAPTCHA State
  const [captchaId, setCaptchaId] = useState('');
  const [captchaImage, setCaptchaImage] = useState('');
  const [captchaAnswer, setCaptchaAnswer] = useState('');
  
  // UX State
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [timer, setTimer] = useState(0);

  const fetchCaptcha = async () => {
    try {
      setError('');
      setCaptchaAnswer('');
      const data = await api.auth.getCaptcha();
      if (data.success) {
        setCaptchaId(data.captcha_id);
        setCaptchaImage(data.image_base64);
      }
    } catch (err: any) {
      setError(t('login.error_captcha'));
    }
  };

  useEffect(() => {
    fetchCaptcha();
  }, []);

  // Countdown timer for resending OTP
  useEffect(() => {
    if (timer > 0) {
      const interval = setInterval(() => {
        setTimer((prev) => prev - 1);
      }, 1000);
      return () => clearInterval(interval);
    }
  }, [timer]);

  const handleRequestOtp = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!mobileNumber.trim()) {
      setError(t('login.error_mobile_req'));
      return;
    }
    if (!captchaAnswer.trim()) {
      setError(t('login.error_captcha_req'));
      return;
    }

    try {
      setLoading(true);
      setError('');
      
      const res = await api.auth.requestOtp(mobileNumber, captchaId, captchaAnswer);
      if (res.success) {
        setStep('VERIFY');
        setTimer(res.expires_in_seconds || 120);
      }
    } catch (err: any) {
      setError(err.message || t('login.error_failed'));
      fetchCaptcha(); // Reload CAPTCHA on failure
    } finally {
      setLoading(false);
    }
  };

  const handleVerifyOtp = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!otpCode.trim()) {
      setError(t('login.error_otp_req'));
      return;
    }

    try {
      setLoading(true);
      setError('');
      
      const res = await api.auth.verifyOtp(mobileNumber, otpCode);
      if (res.success) {
        if (res.role !== 'Admin') {
          setError(t('login.error_denied'));
          setStep('REQUEST');
          fetchCaptcha();
          return;
        }

        // Decode name from JWT or use general string
        let name = 'Administrator';
        try {
          const payload = JSON.parse(atob(res.token.split('.')[1]));
          name = payload.unique_name || payload.sub || 'Admin';
        } catch {
          // ignore
        }

        setToken(res.token);
        onLoginSuccess(res.token, name);
      }
    } catch (err: any) {
      setError(err.message || t('login.error_failed'));
    } finally {
      setLoading(false);
    }
  };

  const handleResendOtp = async () => {
    if (timer > 0) return;
    setStep('REQUEST');
    fetchCaptcha();
  };

  return (
    <div className="login-page">
      <div className="login-card">
        <div className="login-header">
          <h2>{t('login.console_title')}</h2>
          <p>{step === 'REQUEST' ? t('login.sign_in_desc') : t('login.enter_sms_desc')}</p>
        </div>

        {error && (
          <div className="text-danger text-center" style={{ fontSize: '13px', backgroundColor: 'rgba(239, 68, 68, 0.08)', padding: '10px', borderRadius: '6px', marginBottom: '18px', border: '1px solid rgba(239, 68, 68, 0.2)' }}>
            {error}
          </div>
        )}

        {step === 'REQUEST' ? (
          <form onSubmit={handleRequestOtp}>
            <div className="form-group">
              <label>{t('login.mobile_label')}</label>
              <input
                type="tel"
                placeholder={t('login.mobile_placeholder')}
                value={mobileNumber}
                onChange={(e) => setMobileNumber(e.target.value)}
                required
                disabled={loading}
              />
            </div>

            <div className="form-group">
              <label>{t('login.captcha_label')}</label>
              <div className="captcha-container">
                <div className="captcha-image-wrapper" onClick={fetchCaptcha} title="Click to refresh CAPTCHA">
                  {captchaImage ? (
                    <img src={captchaImage} alt="Captcha" style={{ height: '42px' }} />
                  ) : (
                    <div style={{ height: '42px', width: '130px', display: 'flex', alignItems: 'center', justifyContent: 'center', background: '#e2e8f0', color: '#64748b', fontSize: '12px' }}>
                      Generating...
                    </div>
                  )}
                </div>
                <button type="button" className="refresh-captcha-btn" onClick={fetchCaptcha}>
                  {t('login.captcha_refresh')}
                </button>
              </div>
              <input
                type="text"
                placeholder={t('login.captcha_placeholder')}
                value={captchaAnswer}
                onChange={(e) => setCaptchaAnswer(e.target.value)}
                required
                disabled={loading}
              />
            </div>

            <button type="submit" className="btn" style={{ width: '100%', marginTop: '12px' }} disabled={loading}>
              {loading ? t('login.requesting_otp') : t('login.send_code_btn')}
            </button>
          </form>
        ) : (
          <form onSubmit={handleVerifyOtp}>
            <div className="form-group">
              <label>{t('login.sms_code_label')}</label>
              <input
                type="text"
                placeholder={t('login.sms_code_placeholder')}
                value={otpCode}
                onChange={(e) => setOtpCode(e.target.value)}
                required
                disabled={loading}
                autoFocus
              />
            </div>

            <button type="submit" className="btn" style={{ width: '100%', marginTop: '12px' }} disabled={loading}>
              {loading ? t('login.verifying') : t('login.access_dashboard_btn')}
            </button>

            <div className="text-center" style={{ marginTop: '18px' }}>
              {timer > 0 ? (
                <span style={{ fontSize: '13px', color: 'var(--text-muted)' }}>
                  {t('login.resend_timer', { timer: localizeNumber(timer) })}
                </span>
              ) : (
                <button type="button" className="refresh-captcha-btn" onClick={handleResendOtp} style={{ fontWeight: 600 }}>
                  {t('login.resend_btn')}
                </button>
              )}
            </div>
          </form>
        )}
        <div style={{ marginTop: '20px', padding: '12px', borderTop: '1px solid rgba(0, 0, 0, 0.08)', fontSize: '12px', color: '#64748b', textAlign: 'center', direction: 'rtl' }}>
          <strong>جهت بررسی ناظر محترم سامانه پیامکی:</strong>
          <div style={{ marginTop: '4px' }}>
            شماره موبایل تست: <code style={{ userSelect: 'all', background: 'rgba(0,0,0,0.05)', padding: '2px 4px', borderRadius: '4px', fontFamily: 'monospace' }}>09120000000</code>
          </div>
          <div style={{ marginTop: '2px' }}>
            کد تایید پیامک (بای‌پس): <code style={{ userSelect: 'all', background: 'rgba(0,0,0,0.05)', padding: '2px 4px', borderRadius: '4px', fontFamily: 'monospace' }}>12345</code>
          </div>
        </div>
      </div>
    </div>
  );
};

