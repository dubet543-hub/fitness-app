# Deploying the SolidCore backend

The app talks to this backend. In development it points at your Mac
(`http://Apples-MacBook-Air.local:3000`), which only works on your home Wi-Fi.
For a real App Store app the backend must live on a **public HTTPS URL**.

MongoDB is already cloud-hosted (Atlas), so only this Node/Express server needs
deploying.

## Option A — Render (recommended, free tier)

1. Push this repo to GitHub (the `backend/` folder).
2. Go to https://render.com → **New → Web Service** → connect the repo.
3. Set **Root Directory** to `backend`.
   - Build command: `npm install`
   - Start command: `node server.js`
   - (Or Render will auto-detect `render.yaml`.)
4. Add the environment variables (from your `.env`):
   - `MONGODB_URI` – your Atlas connection string
   - `JWT_SECRET` – a long random string
   - `JWT_EXPIRES_IN` – `7d`
   - `ADMIN_EMAIL`, `ADMIN_PASSWORD` – seeds the admin on first boot
   - `CORS_ORIGINS` – your Render URL, e.g. `https://solidcore-backend.onrender.com`
5. Deploy. You'll get a URL like `https://solidcore-backend.onrender.com`.

## Option B — Railway / Fly.io
Same idea. A `Procfile` (`web: node server.js`) is included for Railway/Heroku-style
platforms.

## After deploying — point the app at it

Update **both** files in the Flutter project to the new HTTPS URL, then rebuild:

- `/.env`               → `API_BASE_URL=https://YOUR-BACKEND-URL/api`
- `/assets/config.json` → `{ "API_BASE_URL": "https://YOUR-BACKEND-URL/api" }`

Then: `flutter build ipa` (iOS) / `flutter build appbundle` (Android).

## Security checklist before going live
- [ ] Set a strong `JWT_SECRET` (not the dev value).
- [ ] Change the default `ADMIN_PASSWORD`.
- [ ] In MongoDB Atlas → Network Access, allow the host's IPs (or 0.0.0.0/0 if the
      platform has dynamic IPs) and use a DB user with least privilege.
- [ ] Set `CORS_ORIGINS` to only your admin web origin(s).
- [ ] Remove the temporary `[api]` request logger in `server.js` if you don't want
      request logs in production.
