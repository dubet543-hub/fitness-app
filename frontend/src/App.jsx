import React from 'react';
import { Routes, Route, Navigate } from 'react-router-dom';
import LoginPage from './pages/LoginPage';
import UserPage from './pages/UserPage';
import AdminPage from './pages/AdminPage';
import { getUser } from './api';

function RequireAuth({ children, role }) {
  const user = getUser();
  if (!user) return <Navigate to="/" replace />;
  if (role === 'admin' && user.role !== 'admin') return <Navigate to="/dashboard" replace />;
  if (role === 'athlete' && user.role === 'admin') return <Navigate to="/admin" replace />;
  return children;
}

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<LoginPage />} />
      <Route path="/dashboard" element={<RequireAuth role="athlete"><UserPage /></RequireAuth>} />
      <Route path="/admin" element={<RequireAuth role="admin"><AdminPage /></RequireAuth>} />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
