import React, { useEffect, useState } from 'react';
import { api } from '../../services/api';
import type { Course, AdminModule } from '../../types';

export const CoursesView: React.FC = () => {
  const [courses, setCourses] = useState<Course[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [showEditModal, setShowEditModal] = useState(false);
  const [showUploadModal, setShowUploadModal] = useState(false);
  const [editingCourse, setEditingCourse] = useState<Course | null>(null);
  
  // Edit Form Fields
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [category, setCategory] = useState('');
  const [difficulty, setDifficulty] = useState('Intermediate');
  const [price, setPrice] = useState<number>(0);
  const [isPublished, setIsPublished] = useState(false);

  // Upload Fields
  const [uploadFile, setUploadFile] = useState<File | null>(null);
  const [uploading, setUploading] = useState(false);

  const loadCourses = async () => {
    try {
      setLoading(true);
      const res = await api.admin.getCourses(search, page, 10);
      setCourses(res.courses);
      setTotalPages(Math.ceil(res.total_count / 10) || 1);
    } catch (err) {
      console.error('Failed to load courses', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadCourses();
  }, [page, search]);

  const handleSearchChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setSearch(e.target.value);
    setPage(1);
  };

  const openEdit = (course: any) => {
    setEditingCourse(course);
    setTitle(course.title || '');
    setDescription(course.description || '');
    setCategory(course.category || '');
    setDifficulty(course.difficulty || 'Intermediate');
    setPrice(course.price || 0);
    setIsPublished(course.is_published || false);
    setShowEditModal(true);
  };

  const handleEditSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingCourse) return;

    try {
      await api.admin.updateCourse(editingCourse.id, {
        title,
        description,
        category,
        difficulty,
        price,
        is_published: isPublished
      });
      alert('Course metadata updated successfully.');
      setShowEditModal(false);
      loadCourses();
    } catch (err: any) {
      alert(err.message || 'Failed to update course.');
    }
  };

  const togglePublishStatus = async (course: any) => {
    try {
      await api.admin.updateCourse(course.id, {
        is_published: !course.is_published
      });
      loadCourses();
    } catch (err: any) {
      alert(err.message || 'Failed to toggle publish status.');
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Are you sure you want to delete this course and all associated cards? This cannot be undone.')) {
      return;
    }

    try {
      await api.admin.deleteCourse(id);
      alert('Course deleted successfully.');
      loadCourses();
    } catch (err: any) {
      alert(err.message || 'Failed to delete course.');
    }
  };

  const handleUploadSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!uploadFile) {
      alert('Please select a file to upload.');
      return;
    }

    const formData = new FormData();
    formData.append('file', uploadFile);

    try {
      setUploading(true);
      await api.admin.uploadCourse(formData);
      alert('Course package uploaded and parsed successfully!');
      setShowUploadModal(false);
      setUploadFile(null);
      loadCourses();
    } catch (err: any) {
      alert(err.message || 'Failed to upload course package.');
    } finally {
      setUploading(false);
    }
  };

  return (
    <div>
      <div className="table-container">
        <div className="table-header" style={{ display: 'flex', flexWrap: 'wrap', gap: '16px' }}>
          <div>
            <h2>Course Management Module</h2>
            <p style={{ color: 'var(--text-muted)', fontSize: '13px', marginTop: '4px' }}>
              Upload ZIP packages, modify pricing, difficulty levels, and publish status.
            </p>
          </div>
          <div style={{ display: 'flex', gap: '12px', marginLeft: 'auto', alignItems: 'center' }}>
            <input
              type="text"
              className="search-input"
              placeholder="Search courses..."
              value={search}
              onChange={handleSearchChange}
            />
            <button className="btn" onClick={() => setShowUploadModal(true)}>
              Upload Package
            </button>
          </div>
        </div>

        {loading ? (
          <div className="text-center p-24">Loading courses catalog...</div>
        ) : (
          <div>
            <table className="data-table">
              <thead>
                <tr>
                  <th>Course Title</th>
                  <th>Category</th>
                  <th>Difficulty</th>
                  <th>Price (IRR)</th>
                  <th>Cards</th>
                  <th>Version</th>
                  <th>Status</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {courses.length === 0 ? (
                  <tr>
                    <td colSpan={8} className="text-center text-muted">No courses available. Click "Upload Package" to import one.</td>
                  </tr>
                ) : (
                  courses.map((course) => (
                    <tr key={course.id}>
                      <td>
                        <div style={{ fontWeight: 600, color: 'var(--text-inverse)' }}>{course.title}</div>
                        <div style={{ fontSize: '11px', color: 'var(--text-muted)', maxWidth: '280px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                          {course.description || 'No description provided'}
                        </div>
                      </td>
                      <td>{course.category || <span style={{ fontStyle: 'italic', color: 'var(--text-muted)' }}>None</span>}</td>
                      <td>
                        <span style={{
                          fontSize: '12px',
                          fontWeight: 500,
                          color: course.difficulty === 'Advanced' ? 'var(--accent-red)' : course.difficulty === 'Intermediate' ? 'var(--accent-yellow)' : 'var(--accent-green)'
                        }}>
                          {course.difficulty || 'Intermediate'}
                        </span>
                      </td>
                      <td>
                        {course.price === 0 ? (
                          <span className="badge completed" style={{ fontSize: '10px' }}>Free</span>
                        ) : (
                          `${course.price.toLocaleString()} IRR`
                        )}
                      </td>
                      <td>
                        <strong style={{ color: 'var(--accent-cyan)' }}>{course.card_count}</strong> cards
                      </td>
                      <td>v{course.version}</td>
                      <td>
                        <button
                          style={{
                            background: 'none',
                            border: 'none',
                            cursor: 'pointer',
                            padding: 0
                          }}
                          onClick={() => togglePublishStatus(course)}
                          title="Click to toggle publish status"
                        >
                          <span className={`badge ${course.is_published ? 'completed' : 'pending'}`}>
                            {course.is_published ? 'Published' : 'Draft / Private'}
                          </span>
                        </button>
                      </td>
                      <td>
                        <div style={{ display: 'flex', gap: '8px' }}>
                          <button
                            className="btn btn-secondary"
                            style={{ padding: '6px 12px', fontSize: '12px' }}
                            onClick={() => openEdit(course)}
                          >
                            Edit
                          </button>
                          <button
                            className="btn btn-danger"
                            style={{ padding: '6px 12px', fontSize: '12px' }}
                            onClick={() => handleDelete(course.id)}
                          >
                            Delete
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>

            {/* Pagination */}
            {totalPages > 1 && (
              <div style={{ display: 'flex', justifyContent: 'center', padding: '16px', gap: '12px', borderTop: '1px solid var(--border-color)' }}>
                <button
                  className="btn btn-secondary"
                  style={{ padding: '6px 12px' }}
                  disabled={page === 1}
                  onClick={() => setPage(p => Math.max(p - 1, 1))}
                >
                  Previous
                </button>
                <span style={{ alignSelf: 'center', fontSize: '14px', color: 'var(--text-muted)' }}>
                  Page {page} of {totalPages}
                </span>
                <button
                  className="btn btn-secondary"
                  style={{ padding: '6px 12px' }}
                  disabled={page === totalPages}
                  onClick={() => setPage(p => Math.min(p + 1, totalPages))}
                >
                  Next
                </button>
              </div>
            )}
          </div>
        )}
      </div>

      {/* Edit Modal */}
      {showEditModal && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '500px' }}>
            <div className="modal-header">
              <h3>Edit Course Metadata</h3>
              <button className="refresh-captcha-btn" style={{ fontSize: '20px' }} onClick={() => setShowEditModal(false)}>&times;</button>
            </div>
            <form onSubmit={handleEditSubmit}>
              <div className="modal-body">
                <div className="form-group">
                  <label>Course Title</label>
                  <input type="text" value={title} onChange={(e) => setTitle(e.target.value)} required />
                </div>
                <div className="form-group">
                  <label>Description</label>
                  <textarea rows={3} value={description} onChange={(e) => setDescription(e.target.value)} />
                </div>
                <div className="form-group" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                  <div>
                    <label>Category</label>
                    <input type="text" value={category} onChange={(e) => setCategory(e.target.value)} placeholder="e.g. Languages" />
                  </div>
                  <div>
                    <label>Difficulty</label>
                    <select value={difficulty} onChange={(e) => setDifficulty(e.target.value)}>
                      <option value="Beginner">Beginner</option>
                      <option value="Intermediate">Intermediate</option>
                      <option value="Advanced">Advanced</option>
                    </select>
                  </div>
                </div>
                <div className="form-group" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                  <div>
                    <label>Price (IRR)</label>
                    <input type="number" min="0" value={price} onChange={(e) => setPrice(parseFloat(e.target.value) || 0)} required />
                  </div>
                  <div style={{ display: 'flex', flexDirection: 'column', justifyContent: 'center', height: '100%' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginTop: '12px' }}>
                      <input
                        type="checkbox"
                        id="coursePublish"
                        checked={isPublished}
                        onChange={(e) => setIsPublished(e.target.checked)}
                        style={{ width: 'auto' }}
                      />
                      <label htmlFor="coursePublish" style={{ margin: 0, cursor: 'pointer' }}>Publish Course</label>
                    </div>
                  </div>
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-secondary" onClick={() => setShowEditModal(false)}>
                  Cancel
                </button>
                <button type="submit" className="btn">
                  Save Changes
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Upload Modal */}
      {showUploadModal && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '500px' }}>
            <div className="modal-header">
              <h3>Upload Course ZIP Package</h3>
              <button className="refresh-captcha-btn" style={{ fontSize: '20px' }} onClick={() => setShowUploadModal(false)}>&times;</button>
            </div>
            <form onSubmit={handleUploadSubmit}>
              <div className="modal-body">
                <p style={{ fontSize: '13px', color: 'var(--text-muted)', marginBottom: '16px' }}>
                  Select the compiled <strong>course_package.zip</strong> file compiled using the Course Authoring Kit compiler.
                  The backend will parse the manifest, extract card details, and securely host the package.
                </p>
                <div className="form-group">
                  <label>Select ZIP Package</label>
                  <input
                    type="file"
                    accept=".zip"
                    onChange={(e) => setUploadFile(e.target.files?.[0] || null)}
                    required
                    style={{ padding: '8px' }}
                  />
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-secondary" onClick={() => setShowUploadModal(false)} disabled={uploading}>
                  Cancel
                </button>
                <button type="submit" className="btn" disabled={uploading}>
                  {uploading ? 'Processing Package...' : 'Upload & Import'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export const CoursesModule: AdminModule = {
  id: 'courses',
  name: 'Courses',
  icon: (props) => (
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...props}>
      <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20" />
      <path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z" />
    </svg>
  ),
  component: CoursesModuleView
};

function CoursesModuleView() {
  return <CoursesView />;
}
