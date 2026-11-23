-- Run this whole file once in Supabase > SQL Editor.
create table if not exists admins (user_id uuid primary key references auth.users on delete cascade);
create or replace function is_admin() returns boolean language sql stable security definer set search_path=public as
$$ select exists (select 1 from admins where user_id = auth.uid()) $$;

create table if not exists products (
  id uuid primary key default gen_random_uuid(),
  name text not null, category text not null,
  price int not null check (price > 0),
  description text default '', images text[] default '{}',
  in_stock boolean default true, created_at timestamptz default now());

create sequence if not exists order_seq start 1001;
create table if not exists orders (
  id uuid primary key default gen_random_uuid(),
  order_no text unique not null default ('FE' || nextval('order_seq')),
  user_id uuid references auth.users,
  name text not null, phone text not null, address text not null, state text, pincode text not null,
  payment_method text not null check (payment_method in ('UPI','COD')),
  subtotal int not null default 0, delivery_fee int not null default 0, total int not null default 0,
  payment_status text not null,
  delivery_status text not null default 'Placed',
  upi_ref text unique check (upi_ref ~ '^[0-9]{12}$'),   -- Phase 2
  created_at timestamptz default now());
create table if not exists order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders on delete cascade,
  product_id uuid references products, name text not null,
  price int not null, qty int not null check (qty between 1 and 50));

alter table admins enable row level security;
alter table products enable row level security;
alter table orders enable row level security;
alter table order_items enable row level security;

create policy "products read" on products for select using (true);
create policy "products admin write" on products for all using (is_admin()) with check (is_admin());
create policy "orders read own or admin" on orders for select using (user_id = auth.uid() or is_admin());
create policy "orders admin update" on orders for update using (is_admin());
create policy "items read own or admin" on order_items for select using (
  exists (select 1 from orders o where o.id = order_id and (o.user_id = auth.uid() or is_admin())));
-- No direct insert policy on orders: orders are created only by place_order() below.

-- Prices, delivery fee and totals are calculated HERE, never in the browser.
-- Delivery: Rs. 100 normally, Rs. 200 when total quantity is MORE THAN 5.
create or replace function place_order(p_items jsonb, p_name text, p_phone text, p_address text,
  p_state text, p_pincode text, p_method text) returns jsonb
language plpgsql security definer set search_path=public as $$
declare it jsonb; pr products; q int; sub int := 0; tq int := 0; fee int; oid uuid := gen_random_uuid(); ono text;
begin
  if p_method not in ('UPI','COD') then raise exception 'Choose UPI or Cash on Delivery'; end if;
  if p_phone !~ '^[6-9][0-9]{9}$' then raise exception 'Enter a valid 10-digit phone number'; end if;
  if p_pincode !~ '^[0-9]{6}$' then raise exception 'Enter a valid 6-digit pincode'; end if;
  if length(trim(coalesce(p_name,''))) < 2 or length(trim(coalesce(p_address,''))) < 8 then
    raise exception 'Name and full address are required'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'Cart is empty'; end if;
  insert into orders(id,user_id,name,phone,address,state,pincode,payment_method,payment_status)
  values (oid, auth.uid(), trim(p_name), p_phone, trim(p_address), p_state, p_pincode, p_method,
          case when p_method='COD' then 'Cash pending' else 'Awaiting payment' end)
  returning order_no into ono;
  for it in select * from jsonb_array_elements(p_items) loop
    select * into pr from products where id = (it->>'id')::uuid and in_stock;
    if not found then raise exception 'A product in your cart is no longer available'; end if;
    q := (it->>'qty')::int;
    if q < 1 or q > 50 then raise exception 'Invalid quantity'; end if;
    insert into order_items(order_id,product_id,name,price,qty) values (oid,pr.id,pr.name,pr.price,q);
    sub := sub + pr.price * q; tq := tq + q;
  end loop;
  fee := case when tq > 5 then 200 else 100 end;
  update orders set subtotal=sub, delivery_fee=fee, total=sub+fee where id=oid;
  return jsonb_build_object('order_no',ono,'total',sub+fee,'delivery_fee',fee,'payment_method',p_method);
end $$;

-- Guests track an order with Order ID + phone.
create or replace function track_order(p_order_no text, p_phone text) returns jsonb
language sql security definer set search_path=public as $$
  select jsonb_build_object('order_no',o.order_no,'total',o.total,'payment_method',o.payment_method,
    'payment_status',o.payment_status,'delivery_status',o.delivery_status,'created_at',o.created_at,
    'items',(select jsonb_agg(jsonb_build_object('name',i.name,'qty',i.qty)) from order_items i where i.order_id=o.id))
  from orders o where o.order_no = upper(trim(p_order_no)) and o.phone = p_phone $$;
grant execute on function place_order, track_order to anon, authenticated;

insert into storage.buckets (id,name,public) values ('product-images','product-images',true) on conflict do nothing;
create policy "images public read" on storage.objects for select using (bucket_id='product-images');
create policy "images admin write" on storage.objects for all using (bucket_id='product-images' and is_admin())
  with check (bucket_id='product-images' and is_admin());

-- Sample products (delete later from the admin panel in Phase 3).
insert into products(name,category,price,description) values
 ('Blush Peony Headband','Baby headbands',499,'Soft handmade floral headband. [Sample description]'),
 ('Daisy Dream Headband','Baby headbands',449,'Handmade daisy headband. [Sample description]'),
 ('Rose Hair Clip Set','Hair clips',249,'Set of handmade rose clips. [Sample description]'),
 ('Jasmine Bun Crown','Floral crowns',599,'Handmade jasmine style crown. [Sample description]');
