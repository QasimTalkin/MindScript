-- Create user profiles table linked to Supabase Auth
create table public.profiles (
    id          uuid references auth.users(id) on delete cascade primary key,
    tier        text not null default 'free' check (tier in ('free', 'pro')),
    stripe_customer_id text,
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now()
);

-- Auto-create a profile row when a new user signs up
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer
as $$
begin
    insert into public.profiles (id)
    values (new.id);
    return new;
end;
$$;

create trigger on_auth_user_created
    after insert on auth.users
    for each row execute procedure public.handle_new_user();

-- Row Level Security: users can only see/edit their own profile
alter table public.profiles enable row level security;

create policy "Users can view own profile"
    on public.profiles for select
    using (auth.uid() = id);

create policy "Users can update own profile"
    on public.profiles for update
    using (auth.uid() = id);

-- Service role can update tier (used by Stripe webhook)
create policy "Service role full access"
    on public.profiles for all
    using (auth.role() = 'service_role');
