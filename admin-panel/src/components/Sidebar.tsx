import React from 'react';
import { useTranslation } from 'react-i18next';
import type { AdminModule } from '../types';
import { modules } from '../modules';

interface SidebarProps {
  activeModuleId: string;
  onSelectModule: (id: string) => void;
}

export const Sidebar: React.FC<SidebarProps> = ({ activeModuleId, onSelectModule }) => {
  const { t } = useTranslation();

  return (
    <aside className="sidebar">
      <div className="sidebar-logo">
        <div className="logo-icon">L</div>
        <div className="logo-text">{t('logo')}</div>
      </div>
      
      <ul className="sidebar-menu">
        {modules.map((mod: AdminModule) => {
          const Icon = mod.icon;
          return (
            <li key={mod.id} className={`sidebar-item ${activeModuleId === mod.id ? 'active' : ''}`}>
              <button onClick={() => onSelectModule(mod.id)}>
                <Icon />
                <span>{t(`menu.${mod.id}`, mod.name)}</span>
              </button>
            </li>
          );
        })}
      </ul>
    </aside>
  );
};

