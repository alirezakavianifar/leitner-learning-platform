import React from 'react';

export interface AdminModule {
  id: string;
  name: string;
  icon: (props: React.SVGProps<SVGSVGElement>) => React.ReactNode;
  component: React.ComponentType;
}

export interface User {
  id: string;
  username: string;
  mobile_number: string;
  interests?: string;
  educational_field?: string;
  educational_level?: string;
  is_admin: boolean;
  created_at: string;
}

export interface Course {
  id: string;
  title: string;
  description?: string;
  category?: string;
  difficulty?: string;
  price: number;
  is_published: boolean;
  version: number;
  card_count: number;
  image_url?: string;
  created_at: string;
  updated_at?: string;
  is_archived: boolean;
  archived_at?: string;
  is_critical_update: boolean;
  allowed_platforms?: string;
}

export interface Purchase {
  purchase_id: string;
  user_id: string;
  username: string;
  mobile_number: string;
  course_id: string;
  course_title: string;
  course_price: number;
  payment_provider: string;
  transaction_id: string;
  status: string;
  purchased_at: string;
}

export interface PurchaseFilterParams {
  search?: string;
  status?: string;
  gateway?: string;
  courseId?: string;
  fromDate?: string;
  toDate?: string;
  page?: number;
  pageSize?: number;
}

export interface FlashcardReport {
  report_id: string;
  user_id: string;
  username: string;
  mobile_number: string;
  course_id: string;
  course_title: string;
  card_number: number;
  report_text: string;
  submitted_at: string;
  status: string;
}

export interface Announcement {
  id: string;
  title: string;
  content: string;
  published_at: string;
}

export interface Banner {
  id: string;
  image_url: string;
  link_url?: string;
  display_order: number;
  is_active: boolean;
}

export interface AuditLog {
  id: string;
  actor_username: string;
  action_type: string;
  target_entity: string;
  before_value?: string;
  after_value?: string;
  timestamp: string;
}

export interface CoursePackage {
  id: string;
  title: string;
  description?: string;
  category?: string;
  price: number;
  original_price?: number;
  image_url?: string;
  is_published: boolean;
  is_archived: boolean;
  display_order: number;
  created_at: string;
  updated_at?: string;
  courses: {
    id: string;
    title: string;
    price: number;
    card_count: number;
    image_url?: string;
    is_published: boolean;
  }[];
}

