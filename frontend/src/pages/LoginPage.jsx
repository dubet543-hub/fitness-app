import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api, setSession, getUser } from '../api';

export default function LoginPage() {
  const nav = useNavigate();
  const [email, setEmail]       = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading]   = useState(false);
  const [error, setError]       = useState('');

  useEffect(() => {
    const user = getUser();
    if (user) {
      nav(user.role === 'admin' ? '/admin' : '/dashboard', { replace: true });
    }
  }, [nav]);

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const data = await api.post('/auth/login', { email, password });
      setSession(data.token, data.user);
      nav(data.user.role === 'admin' ? '/admin' : '/dashboard', { replace: true });
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center p-4 bg-bg">
      <div className="bg-surface border border-bdr rounded-2xl p-10 w-full max-w-sm">
        {/* Logo */}
        <div className="flex flex-col items-center gap-3 mb-8">
          <img src="/logo.png" alt="SolidCore AMS" className="w-44 h-auto" />
          <p className="text-xs text-ts">Performance Analytics Platform</p>
        </div>

        <h2 className="text-lg font-semibold text-tp mb-6 text-center">Sign in to your account</h2>

        {error && (
          <div className="bg-red-500/10 border border-red-500/40 rounded-lg px-4 py-3 mb-4 text-red-400 text-sm">
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-xs font-medium text-ts mb-1.5">Email address</label>
            <input
              type="email" required value={email}
              onChange={e => setEmail(e.target.value)}
              placeholder="you@example.com"
            />
          </div>
          <div>
            <label className="block text-xs font-medium text-ts mb-1.5">Password</label>
            <input
              type="password" required value={password}
              onChange={e => setPassword(e.target.value)}
              placeholder="••••••••"
            />
          </div>
          <button
            type="submit" disabled={loading}
            className="w-full bg-accent hover:bg-orange-600 disabled:opacity-60 text-white rounded-xl py-2.5 text-sm font-semibold transition mt-2"
          >
            {loading ? 'Signing in…' : 'Sign In'}
          </button>
        </form>

        <p className="text-center text-xs text-ts mt-6">
          Only registered athletes and admins can sign in.<br />
          Contact your coach to get access.
        </p>
      </div>
    </div>
  );
}
