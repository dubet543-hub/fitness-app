import React from 'react';

const styles = {
  green:  'bg-green-500/15 text-green-400',
  yellow: 'bg-yellow-500/15 text-yellow-400',
  red:    'bg-red-500/15 text-red-400',
  blue:   'bg-blue-500/15 text-blue-400',
  gray:   'bg-gray-500/15 text-gray-400',
};

export function acwrColor(v) {
  if (v == null || v === 0) return 'gray';
  if (v < 0.8)  return 'blue';
  if (v <= 1.3) return 'green';
  if (v <= 1.5) return 'yellow';
  return 'red';
}

export function acwrLabel(v) {
  if (v == null || v === 0) return 'No data';
  if (v < 0.8)  return 'Low';
  if (v <= 1.3) return 'Optimal';
  if (v <= 1.5) return 'Caution';
  return 'High Risk';
}

export function readinessColor(v) {
  if (v == null) return 'gray';
  return v >= 70 ? 'green' : v >= 40 ? 'yellow' : 'red';
}

export default function Badge({ color = 'gray', children }) {
  return (
    <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-[11px] font-semibold ${styles[color]}`}>
      {children}
    </span>
  );
}
