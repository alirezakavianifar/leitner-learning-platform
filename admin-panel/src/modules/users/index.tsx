import React, { useEffect, useState } from 'react';
import { api } from '../../services/api';
import type { User, AdminModule } from '../../types';

export const UsersView: React.FC = () => {
  const [users, setUsers] = useState<User[]>([]);
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [totalCount, setTotalCount] = useState(0);
  const [loading, setLoading] = useState(true);
  const [selectedUser, setSelectedUser] = useState<any>(null);
  const [purchases, setPurchases] = useState<any[]>([]);
  const [courses, setCourses] = useState<any[]>([]);
  const [showEditModal, setShowEditModal] = useState(false);
  
  // User profile edit form fields
  const [editUsername, setEditUsername] = useState('');
  const [editInterests, setEditInterests] = useState('');
  const [editField, setEditField] = useState('');
  const [editLevel, setEditLevel] = useState('');
  const [editIsAdmin, setEditIsAdmin] = useState(false);

  // Manual course toggle form fields
  const [showToggleModal, setShowToggleModal] = useState(false);
  const [targetCourse, setTargetCourse] = useState<any>(null);
  const [grantState, setGrantState] = useState(true);
  const [overrideReason, setOverrideReason] = useState('');

  const loadUsers = async () => {
    try {
      setLoading(true);
      const data = await api.admin.getUsers(search, page, 10);
      if (data.success) {
        setUsers(data.users);
        setTotalCount(data.total_count);
      }
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadUsers();
  }, [page]);

  const handleSearchSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setPage(1);
    loadUsers();
  };

  const handleOpenEdit = async (user: User) => {
    try {
      const userData = await api.admin.getUser(user.id);
      if (userData.success) {
        setSelectedUser(userData.user);
        setPurchases(userData.purchases);
        
        // Populate profile form
        setEditUsername(userData.user.username);
        setEditInterests(userData.user.interests || '');
        setEditField(userData.user.educational_field || '');
        setEditLevel(userData.user.educational_level || '');
        setEditIsAdmin(userData.user.is_admin);
        
        // Fetch all courses to match status
        const token = localStorage.getItem('admin_token');
        const res = await fetch('http://localhost:5000/api/v1/courses', {
          headers: token ? { 'Authorization': `Bearer ${token}` } : {}
        });
        if (res.ok) {
          const list = await res.json();
          setCourses(list);
        }

        setShowEditModal(true);
      }
    } catch (err) {
      alert('Error fetching user data');
    }
  };

  const handleProfileSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedUser) return;
    try {
      const res = await api.admin.updateUser(selectedUser.id, {
        username: editUsername,
        interests: editInterests,
        educational_field: editField,
        educational_level: editLevel,
        is_admin: editIsAdmin
      });
      if (res.success) {
        alert('Profile updated successfully.');
        setShowEditModal(false);
        loadUsers();
      }
    } catch (err: any) {
      alert(err.message || 'Failed to update profile.');
    }
  };

  const openCourseToggle = (course: any, isCurrentlyPurchased: boolean) => {
    setTargetCourse(course);
    setGrantState(!isCurrentlyPurchased);
    setOverrideReason('');
    setShowToggleModal(true);
  };

  const handleCourseToggleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedUser || !targetCourse) return;
    if (!overrideReason.trim()) {
      alert('A reason is required for auditing purposes.');
      return;
    }

    try {
      const res = await api.admin.toggleCourseAccess(
        selectedUser.id,
        targetCourse.id,
        grantState,
        overrideReason
      );

      if (res.success) {
        alert(grantState ? 'Course access granted!' : 'Course access revoked!');
        setShowToggleModal(false);
        // Reload user details
        const userData = await api.admin.getUser(selectedUser.id);
        if (userData.success) {
          setPurchases(userData.purchases);
        }
      }
    } catch (err: any) {
      alert(err.message || 'Failed to toggle course access.');
    }
  };

  return (
    <div>
      <div className="table-container">
        <div className="table-header">
          <h2>User Accounts Management</h2>
          <form onSubmit={handleSearchSubmit} style={{ display: 'flex', gap: '12px' }}>
            <input
              type="text"
              placeholder="Search by Mobile or Name..."
              className="search-input"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
            <button type="submit" className="btn">Search</button>
          </form>
        </div>

        {loading ? (
          <div className="text-center p-24">Loading accounts...</div>
        ) : (
          <table className="data-table">
            <thead>
              <tr>
                <th>Username</th>
                <th>Mobile Number</th>
                <th>Role</th>
                <th>Registered Date</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {users.length === 0 ? (
                <tr>
                  <td colSpan={5} className="text-center text-muted">No users found.</td>
                </tr>
              ) : (
                users.map((user) => (
                  <tr key={user.id}>
                    <td>
                      <div style={{ fontWeight: 600, color: 'var(--text-inverse)' }}>{user.username}</div>
                    </td>
                    <td>{user.mobile_number}</td>
                    <td>
                      <span className={`badge ${user.is_admin ? 'admin' : 'student'}`}>
                        {user.is_admin ? 'Admin' : 'Student'}
                      </span>
                    </td>
                    <td>{new Date(user.created_at).toLocaleDateString()}</td>
                    <td>
                      <button className="btn btn-secondary" onClick={() => handleOpenEdit(user)}>
                        Manage Access
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        )}

        <div style={{ padding: '16px 24px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderTop: '1px solid var(--border-color)' }}>
          <div className="stat-label">Total: {totalCount} users</div>
          <div style={{ display: 'flex', gap: '8px' }}>
            <button className="btn btn-secondary" disabled={page === 1} onClick={() => setPage(page - 1)}>
              Prev
            </button>
            <button className="btn btn-secondary" disabled={page * 10 >= totalCount} onClick={() => setPage(page + 1)}>
              Next
            </button>
          </div>
        </div>
      </div>

      {/* User Details & Edit Modal */}
      {showEditModal && selectedUser && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '750px' }}>
            <div className="modal-header">
              <h3>Manage User: {selectedUser.username}</h3>
              <button className="refresh-captcha-btn" style={{ fontSize: '20px' }} onClick={() => setShowEditModal(false)}>&times;</button>
            </div>
            
            <div className="modal-body" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '24px' }}>
              {/* Profile Details Form */}
              <form onSubmit={handleProfileSubmit}>
                <h4 style={{ marginBottom: '16px', color: 'var(--primary-hover)' }}>Edit Profile Info</h4>
                
                <div className="form-group">
                  <label>Mobile Number (Read-Only)</label>
                  <input type="text" value={selectedUser.mobile_number} disabled style={{ opacity: 0.6 }} />
                </div>
                
                <div className="form-group">
                  <label>Username</label>
                  <input type="text" value={editUsername} onChange={(e) => setEditUsername(e.target.value)} required />
                </div>
                
                <div className="form-group">
                  <label>Interests</label>
                  <input type="text" value={editInterests} onChange={(e) => setEditInterests(e.target.value)} />
                </div>
                
                <div className="form-group">
                  <label>Educational Field</label>
                  <input type="text" value={editField} onChange={(e) => setEditField(e.target.value)} />
                </div>
                
                <div className="form-group">
                  <label>Educational Level</label>
                  <input type="text" value={editLevel} onChange={(e) => setEditLevel(e.target.value)} />
                </div>
                
                <div className="form-group" style={{ display: 'flex', alignItems: 'center', gap: '8px', marginTop: '12px' }}>
                  <input
                    type="checkbox"
                    id="isAdminCheck"
                    checked={editIsAdmin}
                    onChange={(e) => setEditIsAdmin(e.target.checked)}
                    style={{ width: 'auto' }}
                  />
                  <label htmlFor="isAdminCheck" style={{ margin: 0, cursor: 'pointer' }}>Grant Admin Privileges</label>
                </div>
                
                <button type="submit" className="btn" style={{ width: '100%', marginTop: '24px' }}>
                  Save Profile Changes
                </button>
              </form>

              {/* Course Access Management */}
              <div>
                <h4 style={{ marginBottom: '16px', color: 'var(--accent-cyan)' }}>Course Access Matrix</h4>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', maxHeight: '350px', overflowY: 'auto', paddingRight: '8px' }}>
                  {courses.length === 0 ? (
                    <div className="text-muted" style={{ fontStyle: 'italic', fontSize: '13px' }}>No courses exist in catalog.</div>
                  ) : (
                    courses.map((course) => {
                      const purchase = purchases.find(p => p.course_id === course.id);
                      const isPurchased = purchase && purchase.status === 'COMPLETED';
                      
                      return (
                        <div key={course.id} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '12px', border: '1px solid var(--border-color)', borderRadius: '8px', background: 'rgba(0, 0, 0, 0.15)' }}>
                          <div style={{ marginRight: '8px' }}>
                            <div style={{ fontWeight: 600, fontSize: '13px' }}>{course.title}</div>
                            <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
                              {course.price === 0 ? 'Free' : `${course.price.toLocaleString()} IRR`}
                            </div>
                          </div>
                          <button
                            className={`btn ${isPurchased ? 'btn-danger' : 'btn-success'}`}
                            style={{ padding: '6px 12px', fontSize: '12px' }}
                            onClick={() => openCourseToggle(course, !!isPurchased)}
                          >
                            {isPurchased ? 'Revoke' : 'Grant'}
                          </button>
                        </div>
                      );
                    })
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Manual Grant/Revoke Prompt Modal */}
      {showToggleModal && targetCourse && (
        <div className="modal-overlay" style={{ zIndex: 1100 }}>
          <div className="modal-content" style={{ maxWidth: '450px' }}>
            <div className="modal-header">
              <h3>Confirm Manual Override</h3>
              <button className="refresh-captcha-btn" style={{ fontSize: '20px' }} onClick={() => setShowToggleModal(false)}>&times;</button>
            </div>
            <form onSubmit={handleCourseToggleSubmit}>
              <div className="modal-body">
                <p style={{ fontSize: '14px', marginBottom: '16px' }}>
                  You are about to <strong>{grantState ? 'GRANT' : 'REVOKE'}</strong> access to the course:
                  <br />
                  <span style={{ color: 'var(--primary-hover)', fontWeight: 600 }}>{targetCourse.title}</span>
                </p>
                <div className="form-group">
                  <label>Reason for auditing (Required)</label>
                  <textarea
                    rows={3}
                    placeholder="Provide details about why access is being overridden (e.g. manual user purchase, support case)..."
                    value={overrideReason}
                    onChange={(e) => setOverrideReason(e.target.value)}
                    required
                  ></textarea>
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-secondary" onClick={() => setShowToggleModal(false)}>
                  Cancel
                </button>
                <button type="submit" className={`btn ${grantState ? 'btn-success' : 'btn-danger'}`}>
                  Confirm Override
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export const UsersModule: AdminModule = {
  id: 'users',
  name: 'Users',
  icon: (props) => (
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...props}>
      <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
      <circle cx="9" cy="7" r="4" />
      <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
      <path d="M16 3.13a4 4 0 0 1 0 7.75" />
    </svg>
  ),
  component: UsersView
};
