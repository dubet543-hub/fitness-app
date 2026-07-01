import React from 'react';
import { useNavigate } from 'react-router-dom';
import { clearSession, getUser } from '../api';

export default function NavBar() {
  const user = getUser();
  const nav  = useNavigate();

  function logout() {
    clearSession();
    nav('/');
  }

  const initials = (user?.name || 'U')[0].toUpperCase();

  return (
    <nav className="sticky top-0 z-40 bg-surface border-b border-bdr">
      <div className="max-w-7xl mx-auto flex items-center justify-between px-6 py-3">
        {/* Logo */}
        <div className="flex items-center gap-2.5">
          <img src="/logo.png" alt="SolidCore AMS" className="h-9 w-auto" />
        </div>

        {/* Right side */}
        <div className="flex items-center gap-3">
          <div className="text-right hidden sm:block">
            <div className="text-sm font-semibold text-tp">{user?.name}</div>
            <div className="text-xs text-ts">{user?.email}</div>
          </div>
          <div className="w-9 h-9 rounded-full bg-accent flex items-center justify-center text-white text-sm font-bold">
            {initials}
          </div>
          <button
            onClick={logout}
            className="text-xs px-3 py-1.5 rounded-lg border border-bdr text-ts hover:text-tp hover:border-ts transition"
          >
            Sign out
          </button>
        </div>
      </div>
    </nav>
  );
}
