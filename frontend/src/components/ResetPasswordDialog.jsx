import React, { useEffect, useRef, useState } from 'react';
import { api } from '../api';
import { Avatar, Button, Field, Icon, useToast } from './ui';

// Avoids visually ambiguous characters (0/O, 1/l/I) since this gets read
// aloud or typed from a screenshot by whoever relays it to the athlete.
const CHARS = 'ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
function genPassword(len = 10) {
  let s = '';
  for (let i = 0; i < len; i++) s += CHARS[Math.floor(Math.random() * CHARS.length)];
  return s;
}

// Admin can't recover an athlete's forgotten password (it's hashed), only
// set a new one — this sets it and hands the coach a copyable value to
// relay to the athlete.
export default function ResetPasswordDialog({ athlete, onClose }) {
  const [password, setPassword] = useState(genPassword());
  const [showPw, setShowPw] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [done, setDone] = useState(false);
  const toast = useToast();
  const closeRef = useRef(null);

  useEffect(() => {
    const prev = document.activeElement;
    closeRef.current?.focus();
    const onKey = e => { if (e.key === 'Escape') onClose(); };
    document.addEventListener('keydown', onKey);
    return () => { document.removeEventListener('keydown', onKey); prev?.focus?.(); };
  }, []);

  async function save() {
    if (password.length < 6) { setError('Use at least 6 characters.'); return; }
    setBusy(true); setError('');
    try {
      await api.post(`/admin/athletes/${athlete._id}/reset-password`, { password });
      setDone(true);
    } catch (e) {
      setError(e?.message || 'Could not reset the password. Please try again.');
    } finally {
      setBusy(false);
    }
  }

  async function copy() {
    try { await navigator.clipboard.writeText(password); toast('Password copied.'); }
    catch { /* clipboard unavailable — they can still select the text */ }
  }

  return (
    <div className="fixed inset-0 z-50 bg-black/60 flex items-end sm:items-center justify-center sm:p-6" onMouseDown={e => { if (e.target === e.currentTarget) onClose(); }}>
      <div role="dialog" aria-modal="true" aria-labelledby="resetpw-title"
           className="w-full sm:max-w-md bg-surface border border-bdr rounded-t-2xl sm:rounded-xl shadow-2xl max-h-[92dvh] overflow-y-auto">
        <div className="flex items-start gap-3 px-5 pt-5 pb-4 border-b border-bdr">
          <Avatar name={athlete.name} size="w-10 h-10 text-sm" />
          <div className="min-w-0 flex-1">
            <h2 id="resetpw-title" className="display text-[22px] leading-tight text-tp">Reset password</h2>
            <div className="text-sm text-ts truncate">{athlete.name} · {athlete.email}</div>
          </div>
          <button ref={closeRef} onClick={onClose} aria-label="Close" className="w-11 h-11 -mr-2 -mt-1 rounded-lg flex items-center justify-center text-ts hover:text-tp hover:bg-card">
            <Icon name="x" className="w-5 h-5" />
          </button>
        </div>

        {done ? (
          <>
            <div className="px-5 py-5 space-y-3">
              <div className="flex items-center gap-2 text-sm text-[rgb(var(--c-success))]"><Icon name="check" className="w-4 h-4" /> Password reset.</div>
              <div className="rounded-lg border border-bdr bg-bg px-4 py-3 flex items-center justify-between gap-3">
                <span className="num text-lg text-tp select-all">{password}</span>
                <Button variant="ghost" onClick={copy}>Copy</Button>
              </div>
              <p className="text-xs text-ts">Share this with {athlete.name} now — it isn't shown again. They can change it from the app once signed in.</p>
            </div>
            <div className="flex justify-end px-5 py-4 border-t border-bdr">
              <Button variant="primary" onClick={onClose}>Done</Button>
            </div>
          </>
        ) : (
          <>
            <div className="px-5 py-5 space-y-4">
              <p className="text-sm text-ts">
                This sets a new password for {athlete.name}'s account. Their old password stops working immediately.
              </p>
              <Field label="New password" htmlFor="resetpw-value">
                <div className="relative">
                  <input id="resetpw-value" type={showPw ? 'text' : 'password'} className="h-11 !pr-20"
                         value={password} onChange={e => setPassword(e.target.value)} />
                  <div className="absolute right-0.5 top-1/2 -translate-y-1/2 flex">
                    <button type="button" onClick={() => setShowPw(v => !v)} aria-label={showPw ? 'Hide password' : 'Show password'}
                            className="w-11 h-11 flex items-center justify-center text-ts hover:text-tp">
                      <Icon name={showPw ? 'eyeOff' : 'eye'} />
                    </button>
                  </div>
                </div>
                <button type="button" onClick={() => setPassword(genPassword())} className="text-xs text-accent hover:underline mt-1">
                  Generate a new one
                </button>
              </Field>
              {error && <div role="alert" className="text-sm text-[rgb(var(--c-danger))]">{error}</div>}
            </div>
            <div className="flex gap-2 justify-end px-5 py-4 border-t border-bdr">
              <Button onClick={onClose}>Cancel</Button>
              <Button variant="primary" onClick={save} disabled={busy}>{busy ? 'Saving…' : 'Reset password'}</Button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
