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
    try {
      const errData = await response.json();
      errMsg = errData.message || errMsg;
    } catch {
      // ignore
    }
    throw new Error(errMsg);
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

    getCourses: (search?: string, page = 1, pageSize = 15) => {
      const params = new URLSearchParams({ page: page.toString(), pageSize: pageSize.toString() });
      if (search) params.set('search', search);
      return request<{ success: boolean; total_count: number; courses: any[] }>(`/admin/courses?${params.toString()}`);
    },

    uploadCourse: (formData: FormData) => request<{ success: boolean; message: string; course_id: string }>('/admin/courses/upload', {
      method: 'POST',
      body: formData
    }),

    updateCourse: (id: string, data: any) => request<{ success: boolean; message: string; course: any }>(`/admin/courses/${id}`, {
      method: 'PUT',
      body: JSON.stringify(data)
    }),

    deleteCourse: (id: string) => request<{ success: boolean; message: string }>(`/admin/courses/${id}`, {
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

    getAuditLogs: (page = 1, pageSize = 30) => request<{ success: boolean; total_count: number; logs: any[] }>(`/admin/audit-logs?page=${page}&pageSize=${pageSize}`)
  }
};
