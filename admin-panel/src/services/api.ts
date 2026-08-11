const DEFAULT_BASE_URL = 'http://localhost:5000/api/v1';

export const getBaseUrl = (): string => {
  return (import.meta.env.VITE_API_BASE_URL as string) || DEFAULT_BASE_URL;
};

export const getToken = (): string | null => {
  return localStorage.getItem('admin_token');
};

export const setToken = (token: string) => {
  localStorage.setItem('admin_token', token);
};

export const removeToken = () => {
  localStorage.removeItem('admin_token');
};

const generateUUID = (): string => {
  if (typeof crypto !== 'undefined' && crypto.randomUUID) {
    return crypto.randomUUID();
  }
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
};

// Base Fetch Wrapper with JWT Header and 401 redirect to logout
async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  const token = getToken();
  const headers = new Headers(options.headers || {});
  
  if (token) {
    headers.set('Authorization', `Bearer ${token}`);
  }
  
  if (!headers.has('Content-Type') && !(options.body instanceof FormData)) {
    headers.set('Content-Type', 'application/json');
  }

  // Inject correlation ID
  const correlationId = generateUUID();
  headers.set('X-Correlation-ID', correlationId);

  const response = await fetch(`${getBaseUrl()}${path}`, {
    ...options,
    headers,
  });

  if (response.status === 401) {
    removeToken();
    window.dispatchEvent(new Event('auth-logout'));
    throw new Error('Unauthorized');
  }

  if (!response.ok) {
    let errMsg = 'API Request Failed';
    let serverCorrelationId = '';
    try {
      const errData = await response.json();
      errMsg = errData.error || errData.message || errMsg;
      serverCorrelationId = errData.correlation_id || '';
    } catch {
      // ignore
    }
    const finalCorrelationId = serverCorrelationId || correlationId;
    throw new Error(`${errMsg} (Correlation ID: ${finalCorrelationId})`);
  }

  if (response.status === 204) {
    return {} as T;
  }

  return response.json() as Promise<T>;
}

export const api = {
  auth: {
    getCaptcha: () => request<{ success: boolean; captcha_id: string; image_base64: string }>('/auth/captcha'),
    requestOtp: (mobileNumber: string, captchaId: string, captchaAnswer: string) => 
      request<{ success: boolean; message: string; expires_in_seconds: number }>('/auth/otp/request', {
        method: 'POST',
        body: JSON.stringify({ mobile_number: mobileNumber, captcha_id: captchaId, captcha_answer: captchaAnswer })
      }),
    verifyOtp: (mobileNumber: string, otpCode: string) => 
      request<{ success: boolean; token: string; refresh_token: string; role: string }>('/auth/otp/verify', {
        method: 'POST',
        body: JSON.stringify({ mobile_number: mobileNumber, otp_code: otpCode })
      })
  },
  admin: {
    getStats: () => request<{ success: boolean; stats: any }>('/admin/dashboard/stats'),

    getCourses: (search?: string, page = 1, pageSize = 15, includeArchived = false) => {
      const params = new URLSearchParams({ page: page.toString(), pageSize: pageSize.toString() });
      if (search) params.set('search', search);
      if (includeArchived) params.set('includeArchived', 'true');
      return request<{ success: boolean; total_count: number; courses: any[] }>(`/admin/courses?${params.toString()}`);
    },

    uploadCourse: async (fileOrFormData: File | FormData, onProgress?: (pct: number) => void) => {
      const baseUrl = getBaseUrl();

      const sendXhr = (url: string, body: FormData, onChunkProgress?: (pct: number) => void) => {
        return new Promise<any>((resolve, reject) => {
          const activeToken = getToken();
          const xhr = new XMLHttpRequest();
          xhr.open('POST', url, true);
          if (activeToken) xhr.setRequestHeader('Authorization', `Bearer ${activeToken}`);
          xhr.setRequestHeader('X-Correlation-ID', generateUUID());

          if (xhr.upload && onChunkProgress) {
            xhr.upload.onprogress = (e) => {
              if (e.lengthComputable) {
                onChunkProgress(Math.round((e.loaded / e.total) * 100));
              }
            };
          }

          xhr.onload = () => {
            if (xhr.status >= 200 && xhr.status < 300) {
              try {
                resolve(JSON.parse(xhr.responseText));
              } catch {
                resolve({ success: true, message: 'Uploaded successfully', course_id: '' });
              }
            } else {
              let msg = 'Upload failed';
              try {
                const json = JSON.parse(xhr.responseText);
                msg = json.message || json.error || msg;
              } catch {
                if (xhr.status === 408) msg = 'Upload timed out. Please try again.';
                if (xhr.status === 413) msg = 'File size is too large.';
              }
              reject(new Error(msg));
            }
          };

          xhr.onerror = () => reject(new Error('Network error during upload'));
          xhr.ontimeout = () => reject(new Error('Upload chunk timed out'));
          xhr.timeout = 180000; // 3 minutes per 1MB chunk

          xhr.send(body);
        });
      };

      let file: File | null = null;
      if (fileOrFormData instanceof File) {
        file = fileOrFormData;
      } else if (fileOrFormData instanceof FormData) {
        const fileEntry = fileOrFormData.get('file');
        if (fileEntry instanceof File) {
          file = fileEntry;
        }
      }

      // If we don't have a direct File object, fallback to single form post
      if (!file) {
        const formData = fileOrFormData instanceof FormData ? fileOrFormData : new FormData();
        return sendXhr(`${baseUrl}/admin/courses/upload`, formData, onProgress);
      }

      const CHUNK_SIZE = 2 * 1024 * 1024; // 2 MB per chunk
      const totalChunks = Math.ceil(file.size / CHUNK_SIZE);

      if (totalChunks <= 1) {
        const formData = new FormData();
        formData.append('file', file);
        return sendXhr(`${baseUrl}/admin/courses/upload`, formData, (pct) => {
          if (onProgress) onProgress(Math.min(99, pct));
        }).then((res) => {
          if (onProgress) onProgress(100);
          return res;
        });
      }

      const uploadId = generateUUID();
      let lastResult: any = null;
      let maxProgress = 0;

      for (let i = 0; i < totalChunks; i++) {
        const start = i * CHUNK_SIZE;
        const end = Math.min(file.size, start + CHUNK_SIZE);
        const chunkBlob = file.slice(start, end);

        let attempts = 0;
        let success = false;

        while (attempts < 3 && !success) {
          try {
            attempts++;
            // Rebuild FormData on every attempt - a previously-sent FormData body can be
            // consumed/empty on retry in some browsers, which produced empty-chunk 400s.
            const formData = new FormData();
            formData.append('file', chunkBlob, file.name);
            formData.append('uploadId', uploadId);
            formData.append('chunkIndex', String(i));
            formData.append('totalChunks', String(totalChunks));
            formData.append('fileName', file.name);

            lastResult = await sendXhr(`${baseUrl}/admin/courses/upload-chunk`, formData, (chunkPct) => {
              if (onProgress) {
                const currentTotalProgress = Math.round(((i + (chunkPct / 100)) / totalChunks) * 99);
                if (currentTotalProgress > maxProgress) {
                  maxProgress = currentTotalProgress;
                  onProgress(maxProgress);
                }
              }
            });
            success = true;
          } catch (err) {
            if (attempts >= 3) throw err;
            await new Promise((r) => setTimeout(r, 1000));
          }
        }

        if (onProgress) {
          const overallPct = Math.round(((i + 1) / totalChunks) * 99);
          if (overallPct > maxProgress) {
            maxProgress = overallPct;
            onProgress(maxProgress);
          }
        }
      }

      // Final chunk response must report completed=true after the server reassembles the ZIP.
      if (!lastResult || lastResult.completed !== true) {
        throw new Error(
          lastResult?.message ||
            'Upload finished sending chunks, but the server did not assemble the course package. Please try again.'
        );
      }

      if (onProgress) {
        onProgress(100);
      }

      return lastResult;
    },

    updateCourse: (id: string, data: any) => request<{ success: boolean; message: string; course: any }>(`/admin/courses/${id}`, {
      method: 'PUT',
      body: JSON.stringify(data)
    }),

    deleteCourse: (id: string) => request<{ success: boolean; message: string }>(`/admin/courses/${id}`, {
      method: 'DELETE'
    }),

    unarchiveCourse: (id: string) => request<{ success: boolean; message: string; course: any }>(`/admin/courses/${id}/unarchive`, {
      method: 'POST'
    }),

    purgeCourse: (id: string) => request<{ success: boolean; message: string }>(`/admin/courses/${id}/purge`, {
      method: 'DELETE'
    }),
    
    getUsers: (search?: string, page = 1, pageSize = 15) => {
      const params = new URLSearchParams({ page: page.toString(), pageSize: pageSize.toString() });
      if (search) params.set('search', search);
      return request<{ success: boolean; total_count: number; users: any[] }>(`/admin/users?${params.toString()}`);
    },
    
    getUser: (id: string) => request<{ success: boolean; user: any; purchases: any[] }>(`/admin/users/${id}`),
    
    updateUser: (id: string, data: any) => request<{ success: boolean; message: string; user: any }>(`/admin/users/${id}`, {
      method: 'PUT',
      body: JSON.stringify(data)
    }),
    
    getPurchases: (page = 1, pageSize = 15) => request<{ success: boolean; total_count: number; purchases: any[] }>(`/admin/purchases?page=${page}&pageSize=${pageSize}`),
    
    toggleCourseAccess: (userId: string, courseId: string, grantAccess: boolean, reason: string) => 
      request<{ success: boolean; message: string }>(`/admin/users/${userId}/courses/${courseId}`, {
        method: 'PATCH',
        body: JSON.stringify({ grant_access: grantAccess, reason })
      }),
      
    getReports: (status?: string) => {
      const path = status ? `/admin/reports?status=${status}` : '/admin/reports';
      return request<any[]>(path);
    },
    
    updateReportStatus: (id: string, status: string) => 
      request<{ success: boolean; report: any }>(`/admin/reports/${id}`, {
        method: 'PATCH',
        body: JSON.stringify({ status })
      }),

    getAnnouncements: () => request<any[]>('/admin/announcements'),
    createAnnouncement: (title: string, content: string) => request<{ success: boolean; announcement: any }>('/admin/announcements', {
      method: 'POST',
      body: JSON.stringify({ title, content })
    }),
    updateAnnouncement: (id: string, title: string, content: string) => request<{ success: boolean; announcement: any }>(`/admin/announcements/${id}`, {
      method: 'PUT',
      body: JSON.stringify({ title, content })
    }),
    deleteAnnouncement: (id: string) => request<{ success: boolean }>('/admin/announcements/' + id, {
      method: 'DELETE'
    }),

    getBanners: () => request<any[]>('/admin/banners'),
    createBanner: (imageUrl: string, linkUrl: string | null, displayOrder: number, isActive: boolean) => request<{ success: boolean; banner: any }>('/admin/banners', {
      method: 'POST',
      body: JSON.stringify({ image_url: imageUrl, link_url: linkUrl, display_order: displayOrder, is_active: isActive })
    }),
    updateBanner: (id: string, imageUrl: string, linkUrl: string | null, displayOrder: number, isActive: boolean) => request<{ success: boolean; banner: any }>(`/admin/banners/${id}`, {
      method: 'PUT',
      body: JSON.stringify({ image_url: imageUrl, link_url: linkUrl, display_order: displayOrder, is_active: isActive })
    }),
    deleteBanner: (id: string) => request<{ success: boolean }>('/admin/banners/' + id, {
      method: 'DELETE'
    }),

    getConfig: () => request<{ success: boolean; configs: any[] }>('/admin/config'),
    updateConfig: (configs: { key: string; value: string }[]) => request<{ success: boolean; message: string }>('/admin/config', {
      method: 'PUT',
      body: JSON.stringify({ configs })
    }),

    getAuditLogs: (page = 1, pageSize = 30) => request<{ success: boolean; total_count: number; logs: any[] }>(`/admin/audit-logs?page=${page}&pageSize=${pageSize}`)
  }
};
