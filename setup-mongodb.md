# Setting up Supabase for Production

This project no longer uses MongoDB. Use Supabase Postgres.

## 1. Create Supabase project

1. Go to https://supabase.com
2. Create a new project
3. Save:
   - Project URL
   - `anon` key
   - `service_role` key

## 2. Create database schema

1. Open Supabase dashboard
2. Go to SQL Editor
3. Run `backend/supabase-schema.sql`
4. Confirm tables exist:
   - `users`
   - `announcements`
   - `messages`
   - `groups`
   - `calls`
   - `study_materials`

## 3. Configure backend environment

Update `backend/.env`:

```env
PORT=5000
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
JWT_SECRET=your-super-secret-jwt-key-change-in-production
JWT_EXPIRE=7d
FRONTEND_URL=https://your-frontend-domain.com
NODE_ENV=production
```

## 4. Validate connections

```bash
cd backend
node test-connection.js
```

Expected:
- Supabase query succeeds
- OpenRouter test succeeds

## 5. Security best practices

1. Keep `SUPABASE_SERVICE_ROLE_KEY` server-side only.
2. Never commit secrets to git.
3. Rotate keys if exposed.
4. Keep Row Level Security (RLS) enabled for client-facing access; backend can use service role.
5. Restrict CORS origins in production.

## 6. Troubleshooting

1. `Could not find table ...`:
   - Run `backend/supabase-schema.sql`.
2. `supabaseUrl is required`:
   - Ensure `.env` loads and `SUPABASE_URL` is set.
3. Permission errors:
   - Verify service role key is correct.
   - Check table/schema names match `supabaseDb.js`.
