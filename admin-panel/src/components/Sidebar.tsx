import React from 'react';
import type { AdminModule } from '../types';
import { modules } from '../modules';

interface SidebarProps {
  activeModuleId: string;
  onSelectModule: (id: string) => void;
}

export const Sidebar: React.FC<SidebarProps> = ({ activeModuleId, onSelectModule }) => {
  return (
    <aside className="sidebar">
      <div className="sidebar-logo">
        <div className="logo-icon">L</div>
        <div className="logo-text">Leitner Portal</div>
      </div>
      
      <ul className="sidebar-menu">
        {modules.map((mod: AdminModule) => {
          const Icon = mod.icon;
          return (
            <li key={mod.id} className={`sidebar-item ${activeModuleId === mod.id ? 'active' : ''}`}>
              <button onClick={() => onSelectModule(mod.id)}>
                <Icon />
                <span>{mod.name}</span>
              </button>
            </li>
          );
        })}
      </ul>
    </aside>
  );
};
