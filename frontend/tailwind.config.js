/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,jsx}'],
  theme: {
    extend: {
      colors: {
        bg:      '#0D1117',
        surface: '#161B22',
        card:    '#1C2333',
        accent:  '#FF6B35',
        bdr:     '#30363D',
        tp:      '#E6EDF3',
        ts:      '#8B949E',
      },
    },
  },
  plugins: [],
};
