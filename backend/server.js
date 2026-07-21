require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const helmet = require('helmet');
const path = require('path');

const app = express();

// ── Middleware ─────────────────────────────────────────────────────────────────
app.use(helmet({ contentSecurityPolicy: false }));
app.use(cors({
  // Trim whitespace and drop empties/trailing slashes so a stray space or "/"
  // in CORS_ORIGINS doesn't silently break cross-origin requests.
  origin: (process.env.CORS_ORIGINS || 'http://localhost:3000')
    .split(',')
    .map((o) => o.replace(/\s+/g, '').replace(/\/$/, '')) // strip ALL whitespace (incl. pasted newlines) + trailing slash
    .filter(Boolean),
  credentials: true,
}));
app.use(express.json());

// Lightweight API request log — helps confirm device connectivity / sync.
app.use('/api', (req, res, next) => {
  const ip = req.headers['x-forwarded-for'] || req.socket.remoteAddress;
  res.on('finish', () => {
    console.log(`[api] ${new Date().toLocaleTimeString()} ${req.method} ${req.originalUrl} → ${res.statusCode} (${ip})`);
  });
  next();
});

app.use(express.static(path.join(__dirname, 'public')));

// ── Routes ─────────────────────────────────────────────────────────────────────
app.use('/api/auth', require('./routes/auth'));
app.use('/api/sessions', require('./routes/sessions'));
app.use('/api/body-composition', require('./routes/bodyComposition'));
app.use('/api/admin', require('./routes/admin'));

// Public legal pages (hosted URLs for the app stores) — before the SPA catch-all
app.use('/', require('./routes/legal'));

// SPA catch-all — serve React's index.html for any non-API route
app.get('*', (_, res) => res.sendFile(path.join(__dirname, 'public', 'index.html')));

// ── Global error handler ───────────────────────────────────────────────────────
app.use((err, req, res, _next) => {
  console.error(err);
  res.status(err.status || 500).json({ error: err.message || 'Internal server error' });
});

// ── Start ──────────────────────────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;

mongoose.connect(process.env.MONGODB_URI)
  .then(async () => {
    console.log('✓ MongoDB connected');
    await seedAdmin();

    const server = app.listen(PORT, '::', () => console.log(`✓ Server running → port ${PORT} (dual-stack IPv4 + IPv6, reachable on your LAN)`));

    // Friendly message instead of an unhandled 'error' crash when the port is taken.
    server.on('error', (err) => {
      if (err.code === 'EADDRINUSE') {
        console.error(`✗ Port ${PORT} is already in use — another instance is still running. Free it with: lsof -ti:${PORT} | xargs kill`);
        process.exit(1);
      }
      throw err;
    });

    // Release the port on shutdown/restart so stale instances don't pile up.
    // SIGUSR2 is what nodemon sends on restart; SIGINT/SIGTERM cover Ctrl+C and kill.
    const shutdown = (signal) => () => {
      console.log(`\n${signal} received — shutting down gracefully`);
      server.close(() => {
        mongoose.connection.close(false).finally(() => process.exit(0));
      });
    };
    process.once('SIGINT', shutdown('SIGINT'));
    process.once('SIGTERM', shutdown('SIGTERM'));
    process.once('SIGUSR2', () => {
      server.close(() => {
        mongoose.connection.close(false).finally(() => process.kill(process.pid, 'SIGUSR2'));
      });
    });
  })
  .catch(err => {
    console.error('✗ MongoDB connection failed:', err.message);
    process.exit(1);
  });

async function seedAdmin() {
  const User = require('./models/User');
  const exists = await User.findOne({ role: 'admin' });
  if (!exists) {
    await User.create({
      name: 'Admin',
      email: process.env.ADMIN_EMAIL || 'admin@solidcore.com',
      password: process.env.ADMIN_PASSWORD || 'SolidCore@2024',
      role: 'admin',
    });
    console.log(`✓ Admin seeded → ${process.env.ADMIN_EMAIL || 'admin@solidcore.com'}`);
  }
}
