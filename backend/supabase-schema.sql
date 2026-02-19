create extension if not exists pgcrypto;

create table if not exists public.users (
  id uuid primary key default gen_random_uuid(),
  username text not null unique,
  email text not null unique,
  password text not null,
  first_name text not null,
  last_name text not null,
  role text not null default 'student' check (role in ('student', 'faculty', 'admin')),
  department text not null default '',
  registration_number text not null default '' unique,
  is_active boolean not null default true,
  last_login timestamptz,
  profile_picture text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  content text not null,
  author uuid not null references public.users(id) on delete cascade,
  category text not null default 'general',
  priority text not null default 'medium',
  target_audience text[] not null default array['all']::text[],
  department text not null default '',
  attachments jsonb not null default '[]'::jsonb,
  is_published boolean not null default false,
  published_at timestamptz,
  expires_at timestamptz,
  viewers uuid[] not null default '{}'::uuid[],
  likes uuid[] not null default '{}'::uuid[],
  comments jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text not null default '',
  creator uuid not null references public.users(id) on delete cascade,
  members jsonb not null default '[]'::jsonb,
  admins uuid[] not null default '{}'::uuid[],
  is_private boolean not null default false,
  avatar text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists uq_groups_cec_assemble_singleton
  on public.groups ((lower(name)))
  where lower(name) = 'cec assemble';

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  sender uuid not null references public.users(id) on delete cascade,
  receiver uuid references public.users(id) on delete cascade,
  group_id uuid references public.groups(id) on delete cascade,
  content text not null,
  message_type text not null default 'text',
  file_url text,
  file_name text,
  file_size bigint,
  is_read boolean not null default false,
  is_deleted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.calls (
  id uuid primary key default gen_random_uuid(),
  caller uuid not null references public.users(id) on delete cascade,
  callee uuid references public.users(id) on delete cascade,
  group_id uuid references public.groups(id) on delete cascade,
  call_type text not null default 'audio',
  meeting_id text,
  status text not null default 'initiated',
  start_time timestamptz,
  end_time timestamptz,
  duration integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.study_materials (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null default '',
  course_code text not null,
  subject_name text not null default '',
  department text not null default '',
  semester text not null default '',
  material_type text not null default 'notes',
  resource_url text not null default '',
  tags text[] not null default '{}'::text[],
  is_published boolean not null default true,
  uploaded_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_users_updated_at on public.users;
create trigger trg_users_updated_at before update on public.users
for each row execute function public.set_updated_at();

drop trigger if exists trg_announcements_updated_at on public.announcements;
create trigger trg_announcements_updated_at before update on public.announcements
for each row execute function public.set_updated_at();

drop trigger if exists trg_groups_updated_at on public.groups;
create trigger trg_groups_updated_at before update on public.groups
for each row execute function public.set_updated_at();

drop trigger if exists trg_messages_updated_at on public.messages;
create trigger trg_messages_updated_at before update on public.messages
for each row execute function public.set_updated_at();

drop trigger if exists trg_calls_updated_at on public.calls;
create trigger trg_calls_updated_at before update on public.calls
for each row execute function public.set_updated_at();

drop trigger if exists trg_study_materials_updated_at on public.study_materials;
create trigger trg_study_materials_updated_at before update on public.study_materials
for each row execute function public.set_updated_at();
