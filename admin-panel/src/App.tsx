import React, { useEffect, useState } from 'react';
import { Sidebar } from './components/Sidebar';
import { Header } from './components/Header';
import { Login } from './components/Login';
import { modules } from './modules';
import { getToken, removeToken } from './services/api';

export const App: React.FC = () => {
  const [token, setTokenState] = useState<string | null>(getToken());
  const [adminUser, setAdminUser] = useState('Administrator');
  const [activeModuleId, setActiveModuleId] = useState('dashboard');

  useEffect(() => {
    // Attempt to decode initials/name on boot
    const savedToken = getToken();
    if (savedToken) {
      try {
        const payload = JSON.parse(atob(savedToken.split('.')[1]));
        const name = payload.unique_name || payload.sub || 'Admin';
        setAdminUser(name);
      } catch {
        // ignore
      }
    }

    const handleAuthLogout = () => {
      setTokenState(null);
    };

    window.addEventListener('auth-logout', handleAuthLogout);
    return () => window.removeEventListener('auth-logout', handleAuthLogout);
  }, []);

  const handleLoginSuccess = (newToken: string, name: string) => {
    setTokenState(newToken);
    setAdminUser(name);
    setActiveModuleId('dashboard');
  };

  const handleLogout = () => {
    removeToken();
    setTokenState(null);
  };

  if (!token) {
    return <Login onLoginSuccess={handleLoginSuccess} />;
  }

  // Pluggable Module Resolution
  const activeModule = modules.find((m) => m.id === activeModuleId) || modules[0];
  const ActiveComponent = activeModule.component;

  return (
    <div className="app-container">
      <Sidebar activeModuleId={activeModuleId} onSelectModule={setActiveModuleId} />
      
      <main className="main-content">
        <Header
          moduleId={activeModuleId}
          moduleName={activeModule.name}
          adminUsername={adminUser}
          onLogout={handleLogout}
        />
        
        <div className="page-viewport">
          <ActiveComponent />
        </div>
      </main>
    </div>
  );
};

export default App;
