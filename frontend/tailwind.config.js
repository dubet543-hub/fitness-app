/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,jsx}'],
  theme: {
    extend: {
      // Colour tokens are CSS variables (src/index.css) so a section can
      // re-theme itself — the admin console overrides them in admin.css.
      colors: {
        bg:      'rgb(var(--c-bg) / <alpha-value>)',
        surface: 'rgb(var(--c-surface) / <alpha-value>)',
        card:    'rgb(var(--c-card) / <alpha-value>)',
        accent:  'rgb(var(--c-accent) / <alpha-value>)',
        bdr:     'rgb(var(--c-bdr) / <alpha-value>)',
        tp:      'rgb(var(--c-tp) / <alpha-value>)',
        ts:      'rgb(var(--c-ts) / <alpha-value>)',
      },
    },
  },
  plugins: [],
};
