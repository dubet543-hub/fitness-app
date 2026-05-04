import {
  Chart as ChartJS,
  CategoryScale, LinearScale, BarElement,
  LineElement, PointElement, ArcElement,
  Title, Tooltip, Legend, Filler,
} from 'chart.js';

ChartJS.register(
  CategoryScale, LinearScale, BarElement,
  LineElement, PointElement, ArcElement,
  Title, Tooltip, Legend, Filler,
);

export const CHART_OPTS = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: { display: false },
    tooltip: {
      backgroundColor: '#1C2333',
      borderColor: '#30363D',
      borderWidth: 1,
      titleColor: '#E6EDF3',
      bodyColor: '#8B949E',
    },
  },
  scales: {
    x: { ticks: { color: '#8B949E', font: { size: 10 } }, grid: { color: '#21262D' } },
    y: { ticks: { color: '#8B949E', font: { size: 10 } }, grid: { color: '#21262D' } },
  },
};

export const DONUT_OPTS = {
  responsive: true,
  maintainAspectRatio: true,
  cutout: '65%',
  plugins: {
    legend: { position: 'bottom', labels: { color: '#8B949E', font: { size: 10 }, boxWidth: 10, padding: 10 } },
    tooltip: { backgroundColor: '#1C2333', borderColor: '#30363D', borderWidth: 1, titleColor: '#E6EDF3', bodyColor: '#8B949E' },
  },
};

export const COLORS = ['#FF6B35','#818CF8','#34D399','#FBBF24','#60A5FA','#F472B6','#A78BFA','#6EE7B7'];
