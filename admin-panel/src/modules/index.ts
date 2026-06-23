import type { AdminModule } from '../types';
import { DashboardModule } from './dashboard';
import { UsersModule } from './users';
import { CoursesModule } from './courses';
import { PurchasesModule } from './purchases';
import { ReportsModule } from './reports';
import { AnnouncementsModule } from './announcements';
import { BannersModule } from './banners';
import { AuditLogsModule } from './audit-logs';
import { SettingsModule } from './settings';

export const modules: AdminModule[] = [
  DashboardModule,
  UsersModule,
  CoursesModule,
  PurchasesModule,
  ReportsModule,
  AnnouncementsModule,
  BannersModule,
  AuditLogsModule,
  SettingsModule
];
