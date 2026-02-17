# CEC ECHO Deployment Guide

## Table of Contents
1. Prerequisites
2. Backend Deployment
3. Supabase Setup
4. Frontend Deployment
5. Environment Configuration
6. Production Considerations

## Prerequisites

- Node.js v16+
- Git
- Supabase project
- Cloud/server account (Render, Railway, Heroku, etc.)

## Backend Deployment

### Option 1: Render (Recommended)

1. Create account at https://render.com
2. Push repository to GitHub/GitLab
3. Create Web Service and connect repo
4. Set environment variables (see below)
5. Deploy

### Option 2: Railway

```bash
npm install -g @railway/cli
railway login
railway init
railway up
```

### Option 3: Heroku

```bash
heroku create your-app-name
heroku config:set NODE_ENV=production
git push heroku main
```

## Supabase Setup

1. Create Supabase project
2. Open SQL Editor
3. Run `backend/supabase-schema.sql`
4. Copy:
   - Project URL
   - `anon` key
   - `service_role` key

## Frontend Deployment

### Flutter mobile build

```bash
flutter build apk --release
flutter build appbundle --release
flutter build ios --release
```

### Flutter web build (optional)

```bash
flutter build web
```

## Environment Configuration

Set these variables in backend deployment:

```env
PORT=5000
NODE_ENV=production

SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

JWT_SECRET=your-super-secure-jwt-secret-key-change-in-production
JWT_EXPIRE=7d

FRONTEND_URL=https://your-client-domain.com

STUN_SERVER=stun:stun.l.google.com:19302
TURN_SERVER=turn:your-turn-server.com:3478
TURN_USERNAME=your-turn-username
TURN_CREDENTIALS=your-turn-password

OPENAI_API_KEY=your-openrouter-or-openai-key
```

## Production Considerations

### Security

1. Keep `SUPABASE_SERVICE_ROLE_KEY` server-only.
2. Rotate secrets regularly.
3. Use HTTPS everywhere.
4. Keep strict CORS origin list.
5. Apply request validation and rate limits.

### Performance

1. Add indexes as query volume grows.
2. Monitor DB and API latency.
3. Use caching for repeated reads.

### Monitoring

1. Capture app logs and error alerts.
2. Monitor Supabase query performance.
3. Track uptime and error rate.

## Post-deployment Checklist

1. Test register/login/profile APIs.
2. Test announcements, chat, admin/student dashboards.
3. Test socket and WebRTC signaling flows.
4. Run `node backend/test-connection.js`.
5. Confirm schema and permissions in Supabase.
