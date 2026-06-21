import React, { useEffect, useState } from 'react';
import { api, setToken } from '../services/api';

interface LoginProps {
  onLoginSuccess: (token: string, username: string) => void;
}

export const Login: React.FC<LoginProps> = ({ onLoginSuccess }) => {
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
      setError('Could not retrieve visual CAPTCHA.');
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
      setError('Mobile number is required.');
      return;
    }
    if (!captchaAnswer.trim()) {
      setError('Please answer the CAPTCHA math challenge.');
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
      setError(err.message || 'OTP dispatch failed. Check CAPTCHA and mobile input.');
      fetchCaptcha(); // Reload CAPTCHA on failure
    } finally {
      setLoading(false);
    }
  };

  const handleVerifyOtp = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!otpCode.trim()) {
      setError('Verification code is required.');
      return;
    }

    try {
      setLoading(true);
      setError('');
      
      const res = await api.auth.verifyOtp(mobileNumber, otpCode);
      if (res.success) {
        if (res.role !== 'Admin') {
          setError('Access Denied: Only administrators can access this terminal.');
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
      setError(err.message || 'Verification failed. Re-enter the OTP.');
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
          <h2>Administrative Console</h2>
          <p>{step === 'REQUEST' ? 'Sign in to access control portal' : 'Enter the SMS code sent to you'}</p>
        </div>

        {error && (
          <div className="text-danger text-center" style={{ fontSize: '13px', backgroundColor: 'rgba(239, 68, 68, 0.08)', padding: '10px', borderRadius: '6px', marginBottom: '18px', border: '1px solid rgba(239, 68, 68, 0.2)' }}>
            {error}
          </div>
        )}

        {step === 'REQUEST' ? (
          <form onSubmit={handleRequestOtp}>
            <div className="form-group">
              <label>Mobile Number</label>
              <input
                type="tel"
                placeholder="e.g. +989123456789 or 09123456789"
                value={mobileNumber}
                onChange={(e) => setMobileNumber(e.target.value)}
                required
                disabled={loading}
              />
            </div>

            <div className="form-group">
              <label>CAPTCHA Math Challenge</label>
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
                  Refresh
                </button>
              </div>
              <input
                type="text"
                placeholder="Answer"
                value={captchaAnswer}
                onChange={(e) => setCaptchaAnswer(e.target.value)}
                required
                disabled={loading}
              />
            </div>

            <button type="submit" className="btn" style={{ width: '100%', marginTop: '12px' }} disabled={loading}>
              {loading ? 'Requesting OTP...' : 'Send Verification Code'}
            </button>
          </form>
        ) : (
          <form onSubmit={handleVerifyOtp}>
            <div className="form-group">
              <label>Verification SMS Code</label>
              <input
                type="text"
                placeholder="Enter 5-digit code (use 12345 to bypass)"
                value={otpCode}
                onChange={(e) => setOtpCode(e.target.value)}
                required
                disabled={loading}
                autoFocus
              />
            </div>

            <button type="submit" className="btn" style={{ width: '100%', marginTop: '12px' }} disabled={loading}>
              {loading ? 'Verifying...' : 'Access Dashboard'}
            </button>

            <div className="text-center" style={{ marginTop: '18px' }}>
              {timer > 0 ? (
                <span style={{ fontSize: '13px', color: 'var(--text-muted)' }}>
                  Resend code in {timer}s
                </span>
              ) : (
                <button type="button" className="refresh-captcha-btn" onClick={handleResendOtp} style={{ fontWeight: 600 }}>
                  Resend OTP Code
                </button>
              )}
            </div>
          </form>
        )}
      </div>
    </div>
  );
};
