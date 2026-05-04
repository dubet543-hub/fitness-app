import React from 'react';

export default function StatCard({ label, value, sub, children }) {
  return (
    <div className="bg-surface border border-bdr rounded-xl p-5">
      <div className="text-[11px] text-ts uppercase tracking-wider mb-1.5">{label}</div>
      <div className="text-3xl font-bold text-tp leading-none">{children ?? value}</div>
      {sub && <div className="text-xs text-ts mt-1">{sub}</div>}
    </div>
  );
}
