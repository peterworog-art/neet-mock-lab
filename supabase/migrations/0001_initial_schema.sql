-- NEET Mock Lab: initial Supabase schema
create extension if not exists pgcrypto;

create type public.paper_status as enum ('uploaded','processing','needs_review','ready','failed');
create type public.attempt_mode as enum ('full_mock','practice');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  storage_limit_bytes bigint not null default 524288000,
  created_at timestamptz not null default now()
);

create table public.papers (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  subject text not null default 'Mixed PCB',
  exam_year int,
  status public.paper_status not null default 'uploaded',
  source_pdf_path text,
  source_bytes bigint not null default 0 check (source_bytes >= 0 and source_bytes <= 52428800),
  question_count int not null default 0 check (question_count >= 0),
  current_version int not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.paper_versions (
  id uuid primary key default gen_random_uuid(),
  paper_id uuid not null references public.papers(id) on delete cascade,
  version_number int not null,
  question_pdf_path text,
  answer_pdf_path text,
  extracted_text jsonb not null default '{}'::jsonb,
  processing_notes jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  unique (paper_id, version_number)
);

create table public.questions (
  id uuid primary key default gen_random_uuid(),
  paper_version_id uuid not null references public.paper_versions(id) on delete cascade,
  question_number int not null,
  subject text not null default 'Unclassified',
  topic text,
  question_text text not null,
  options jsonb not null default '[]'::jsonb,
  correct_options int[] not null default '{}',
  answer_confidence numeric(4,3),
  answer_source text,
  explanation text,
  source_page int,
  source_region jsonb,
  review_status text not null default 'needs_review' check (review_status in ('needs_review','verified','rejected')),
  created_at timestamptz not null default now(),
  unique (paper_version_id, question_number)
);

create table public.attempts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  paper_id uuid not null references public.papers(id) on delete restrict,
  paper_version_id uuid not null references public.paper_versions(id) on delete restrict,
  mode public.attempt_mode not null,
  duration_seconds int not null default 10800,
  elapsed_seconds int not null default 0,
  started_at timestamptz not null default now(),
  submitted_at timestamptz,
  status text not null default 'in_progress' check (status in ('in_progress','submitted','expired')),
  score numeric(8,2),
  correct_count int,
  incorrect_count int,
  unanswered_count int,
  created_at timestamptz not null default now()
);

create table public.attempt_answers (
  attempt_id uuid not null references public.attempts(id) on delete cascade,
  question_id uuid not null references public.questions(id) on delete restrict,
  selected_options int[] not null default '{}',
  marked_for_review boolean not null default false,
  visited boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (attempt_id, question_id)
);

create table public.collections (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now()
);

create table public.collection_questions (
  collection_id uuid not null references public.collections(id) on delete cascade,
  question_id uuid not null references public.questions(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (collection_id, question_id)
);

create table public.ai_usage_daily (
  owner_id uuid not null references auth.users(id) on delete cascade,
  usage_date date not null default (now() at time zone 'utc')::date,
  explanation_count int not null default 0 check (explanation_count >= 0),
  primary key (owner_id, usage_date)
);

create index papers_owner_updated_idx on public.papers(owner_id, updated_at desc);
create index questions_version_number_idx on public.questions(paper_version_id, question_number);
create index attempts_owner_created_idx on public.attempts(owner_id, created_at desc);

alter table public.profiles enable row level security;
alter table public.papers enable row level security;
alter table public.paper_versions enable row level security;
alter table public.questions enable row level security;
alter table public.attempts enable row level security;
alter table public.attempt_answers enable row level security;
alter table public.collections enable row level security;
alter table public.collection_questions enable row level security;
alter table public.ai_usage_daily enable row level security;

create policy "profile owner read/update" on public.profiles for all using (auth.uid() = id) with check (auth.uid() = id);
create policy "paper owner access" on public.papers for all using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
create policy "paper version owner access" on public.paper_versions for all using (exists (select 1 from public.papers p where p.id = paper_id and p.owner_id = auth.uid())) with check (exists (select 1 from public.papers p where p.id = paper_id and p.owner_id = auth.uid()));
create policy "question owner access" on public.questions for all using (exists (select 1 from public.paper_versions v join public.papers p on p.id = v.paper_id where v.id = paper_version_id and p.owner_id = auth.uid())) with check (exists (select 1 from public.paper_versions v join public.papers p on p.id = v.paper_id where v.id = paper_version_id and p.owner_id = auth.uid()));
create policy "attempt owner access" on public.attempts for all using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
create policy "attempt answer owner access" on public.attempt_answers for all using (exists (select 1 from public.attempts a where a.id = attempt_id and a.owner_id = auth.uid())) with check (exists (select 1 from public.attempts a where a.id = attempt_id and a.owner_id = auth.uid()));
create policy "collection owner access" on public.collections for all using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
create policy "collection question owner access" on public.collection_questions for all using (exists (select 1 from public.collections c where c.id = collection_id and c.owner_id = auth.uid()));
create policy "ai usage owner access" on public.ai_usage_daily for all using (auth.uid() = owner_id) with check (auth.uid() = owner_id);

-- Create profile rows automatically for new accounts.
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name) values (new.id, coalesce(new.raw_user_meta_data->>'name', new.email));
  return new;
end; $$;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();
