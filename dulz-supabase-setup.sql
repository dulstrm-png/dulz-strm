-- DULZ STRM: Supabase setup
-- Jalankan seluruh SQL ini di Supabase SQL Editor.
-- Setelah itu masukkan URL project + publishable/anon key ke DULZ_CONFIG di HTML.
-- Ganti KODE_ADMIN_ANDA dengan kode rahasia milik Anda.

create extension if not exists pgcrypto;

create table if not exists public.orders (
  order_id text primary key,
  order_text text not null default 'Pesanan',
  status text not null default 'pending' check (status in ('pending','confirmed')),
  apk_url text,
  confirmed_at timestamptz
);

alter table public.orders enable row level security;

grant select, insert on public.orders to anon;
grant select, insert, update on public.orders to authenticated;

drop policy if exists "orders_public_insert" on public.orders;
create policy "orders_public_insert"
on public.orders for insert
to anon, authenticated
with check (
  status = 'pending'
  and apk_url is null
);

drop policy if exists "orders_public_select" on public.orders;
create policy "orders_public_select"
on public.orders for select
to anon, authenticated
using (true);

-- Jangan beri UPDATE langsung ke browser.
revoke update, delete on public.orders from anon;
revoke delete on public.orders from authenticated;

create or replace function public.admin_confirm_order(
  p_order_id text,
  p_apk_url text,
  p_admin_code text
)
returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  -- GANTI string di bawah dengan kode admin Anda.
  if p_admin_code <> 'KODE_ADMIN_ANDA' then
    return false;
  end if;

  if p_apk_url !~* '^https://'
     and p_apk_url !~* '^http://'
  then
    return false;
  end if;

  update public.orders
  set status='confirmed',
      apk_url=p_apk_url,
      confirmed_at=now()
  where order_id=p_order_id;

  return found;
end;
$$;

revoke all on function public.admin_confirm_order(text,text,text) from public;
grant execute on function public.admin_confirm_order(text,text,text) to anon, authenticated;

-- Aktifkan realtime untuk tabel orders.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname='supabase_realtime'
      and schemaname='public'
      and tablename='orders'
  ) then
    alter publication supabase_realtime add table public.orders;
  end if;
end $$;
