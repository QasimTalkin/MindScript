-- Track individual transcription events for metering
create table public.usage_events (
    id                  bigserial primary key,
    user_id             uuid references public.profiles(id) on delete cascade not null,
    duration_seconds    float not null check (duration_seconds > 0),
    transcribed_at      timestamptz not null default now()
);

-- Index for efficient monthly usage queries
create index usage_events_user_month_idx
    on public.usage_events (user_id, date_trunc('month', transcribed_at));

-- Row Level Security
alter table public.usage_events enable row level security;

create policy "Users can view own usage"
    on public.usage_events for select
    using (auth.uid() = user_id);

create policy "Users can insert own usage"
    on public.usage_events for insert
    with check (auth.uid() = user_id);

create policy "Service role full access"
    on public.usage_events for all
    using (auth.role() = 'service_role');

-- View: current-month total seconds per user
-- The macOS app queries this to sync usage from the server
create or replace view public.monthly_usage as
    select
        user_id,
        sum(duration_seconds) as total_seconds
    from public.usage_events
    where date_trunc('month', transcribed_at) = date_trunc('month', now())
    group by user_id;

-- Grant read access to authenticated users (filtered by RLS on underlying table)
grant select on public.monthly_usage to authenticated;
