-- ============================================================
-- Wine Intelligence CRM — Migração inicial (Fase 0)
-- Multi-tenancy: banco compartilhado + tenant_id em toda linha,
-- isolamento garantido por Row-Level Security (RLS).
-- ============================================================

-- ---------- extensões ----------
create extension if not exists "pgcrypto";

-- ---------- enumerações ----------
create type account_kind    as enum ('B2C','B2B');
create type user_role       as enum ('owner','admin','vendedor','leitor');
create type opp_stage_b2c   as enum ('NOVO_CONTATO','QUALIFICACAO','RECOMENDACAO','OFERTA','PEDIDO','POS_VENDA','PERDIDO');
create type opp_stage_b2b   as enum ('PROSPECT','QUALIFICACAO','DIAGNOSTICO','APRESENTACAO','PROPOSTA','NEGOCIACAO','PRIMEIRO_PEDIDO','GESTAO_CONTA','PERDIDO');
create type order_status    as enum ('CONFIRMADO','CANCELADO');
create type payment_status  as enum ('PENDENTE','PAGO');
create type delivery_status as enum ('PENDENTE','EM_ENTREGA','ENTREGUE');
create type rec_status      as enum ('APRESENTADA','ACEITA','IGNORADA','CONVERTIDA');
create type rec_priority    as enum ('BAIXA','MEDIA','ALTA');

-- ============================================================
-- ORGANIZAÇÕES E USUÁRIOS
-- ============================================================
create table organizations (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  plan        text not null default 'trial',          -- trial | essencial | profissional | avancado | corporativo
  trial_ends  timestamptz,
  settings    jsonb not null default '{}',            -- inclui pesos da compatibilidade (DB.w do protótipo)
  created_at  timestamptz not null default now()
);

-- perfil do usuário autenticado; 1 usuário pode pertencer a N organizações
create table org_members (
  org_id      uuid not null references organizations(id) on delete cascade,
  user_id     uuid not null references auth.users(id) on delete cascade,
  role        user_role not null default 'vendedor',
  created_at  timestamptz not null default now(),
  primary key (org_id, user_id)
);

-- helper: organizações do usuário logado
create or replace function current_orgs() returns setof uuid
language sql stable security definer set search_path = public as $$
  select org_id from org_members where user_id = auth.uid();
$$;

-- helper: papel do usuário na organização
create or replace function org_role(_org uuid) returns user_role
language sql stable security definer set search_path = public as $$
  select role from org_members where org_id = _org and user_id = auth.uid();
$$;

-- ============================================================
-- CRM — NÚCLEO
-- ============================================================
create table clients (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references organizations(id) on delete cascade,
  kind        account_kind not null default 'B2C',
  name        text not null,
  doc         text,                                   -- CPF/CNPJ (único por org quando presente)
  nasc        date,
  phone       text,
  email       text,
  source      text,
  owner_id    uuid references auth.users(id),
  seg         text,                                   -- segmento B2B
  pot         text,                                   -- potencial: baixo|medio|alto
  obs         text,
  since       date not null default current_date,
  prefs       jsonb not null default '{}',            -- perfil de consumo/comercial (Mapa de Paladar)
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (org_id, doc),
  unique (org_id, email)
);
create index on clients (org_id, lower(name));

create table client_addresses (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references organizations(id) on delete cascade,
  client_id   uuid not null references clients(id) on delete cascade,
  label       text not null,
  type        text not null default 'entrega',
  rua         text, bairro text, cidade text, uf text, cep text,
  padrao      boolean not null default false
);

-- contatos B2B; identity_id liga a mesma pessoa em contas diferentes (pid do protótipo)
create table contacts (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references organizations(id) on delete cascade,
  client_id   uuid not null references clients(id) on delete cascade,
  identity_id uuid,
  name        text not null,
  role        text,
  phone       text,
  email       text
);

create table client_units (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references organizations(id) on delete cascade,
  client_id   uuid not null references clients(id) on delete cascade,
  name        text not null,
  loc         text, rua text, resp text
);

create table interactions (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references organizations(id) on delete cascade,
  client_id   uuid not null references clients(id) on delete cascade,
  user_id     uuid references auth.users(id),
  type        text not null default 'nota',           -- nota | whatsapp | email | sistema
  content     text not null,
  occurred_at timestamptz not null default now()
);
create index on interactions (org_id, client_id, occurred_at desc);

-- ---------- LGPD ----------
create table consents (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references organizations(id) on delete cascade,
  client_id   uuid not null references clients(id) on delete cascade,
  purpose     text not null,                          -- ex.: 'comunicacao_comercial'
  channel     text,                                   -- whatsapp | email | ...
  granted     boolean not null,
  evidence    jsonb,                                  -- origem, IP, timestamp do aceite
  created_at  timestamptz not null default now()
);

-- ---------- catálogo ----------
create table products (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references organizations(id) on delete cascade,
  name        text not null,
  vintage     int,                                    -- safra
  tipo        text,                                   -- tinto|branco|rose|espumante
  uva         text,
  doc         text, corpo text, acid text, tan text,  -- atributos sensoriais (escala ordinal no app)
  preco       numeric(10,2) not null default 0,       -- varejo B2C
  atac        numeric(10,2),                          -- atacado B2B
  margem      numeric(5,2),
  est         int not null default 0,
  harm        text,                                   -- harmonizações
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);
create index on products (org_id, lower(name));

-- ---------- pipeline ----------
create table opportunities (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references organizations(id) on delete cascade,
  client_id   uuid not null references clients(id) on delete cascade,
  kind        account_kind not null default 'B2C',
  stage       text not null,                          -- validado no app conforme kind
  value       numeric(12,2) not null default 0,
  owner_id    uuid references auth.users(id),
  prev_date   date,
  next_action text,
  obs         text,
  diag        jsonb,                                  -- diagnóstico B2B
  opened_at   timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table activities (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references organizations(id) on delete cascade,
  client_id   uuid not null references clients(id) on delete cascade,
  opp_id      uuid references opportunities(id) on delete set null,
  type        text not null,                          -- ligacao|whatsapp|email|reuniao|...
  due_date    date not null,
  due_time    text,
  owner_id    uuid references auth.users(id),
  description text not null,
  done        boolean not null default false,
  done_at     timestamptz
);

create table orders (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references organizations(id) on delete cascade,
  client_id   uuid not null references clients(id) on delete cascade,
  opp_id      uuid references opportunities(id) on delete set null,
  order_date  date not null default current_date,
  disc        numeric(5,2) not null default 0,
  cond        text,
  status      order_status not null default 'CONFIRMADO',
  payment     payment_status not null default 'PENDENTE',
  delivery    delivery_status not null default 'PENDENTE',
  created_by  uuid references auth.users(id),
  created_at  timestamptz not null default now()
);

create table order_items (
  id          uuid primary key default gen_random_uuid(),
  order_id    uuid not null references orders(id) on delete cascade,
  org_id      uuid not null references organizations(id) on delete cascade,
  product_id  uuid references products(id),
  name        text not null,                          -- snapshot do nome
  qty         int not null check (qty > 0),
  unit_price  numeric(10,2) not null check (unit_price >= 0)
);

create table negotiated_prices (                        -- preços negociados por conta (np)
  org_id      uuid not null references organizations(id) on delete cascade,
  client_id   uuid not null references clients(id) on delete cascade,
  product_id  uuid not null references products(id) on delete cascade,
  price       numeric(10,2) not null check (price > 0),
  primary key (client_id, product_id)
);

-- ---------- integrações (fase 2; estrutura desde já) ----------
create table wa_conversations (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references organizations(id) on delete cascade,
  client_id   uuid not null references clients(id),
  wa_phone    text not null,
  last_msg_at timestamptz,
  status      text not null default 'aberta'          -- aberta | sem_retorno | arquivada
);
create table wa_messages (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references organizations(id) on delete cascade,
  conv_id     uuid not null references wa_conversations(id) on delete cascade,
  direction   text not null check (direction in ('in','out')),
  body        text not null,
  wa_msg_id   text unique,
  sent_at     timestamptz not null default now()
);

-- ---------- auditoria ----------
create table audit_log (
  id          bigserial primary key,
  org_id      uuid,
  user_id     uuid,
  action      text not null,                          -- insert|update|delete
  table_name  text not null,
  row_id      text,
  changes     jsonb,
  created_at  timestamptz not null default now()
);

-- ============================================================
-- ROW-LEVEL SECURITY — nenhuma tabela é legível fora da org
-- ============================================================
alter table organizations       enable row level security;
alter table org_members         enable row level security;
-- (repetir o enable para todas as tabelas de negócio)
alter table clients             enable row level security;
alter table client_addresses    enable row level security;
alter table contacts            enable row level security;
alter table client_units        enable row level security;
alter table interactions        enable row level security;
alter table consents            enable row level security;
alter table products            enable row level security;
alter table opportunities       enable row level security;
alter table activities          enable row level security;
alter table orders              enable row level security;
alter table order_items         enable row level security;
alter table negotiated_prices   enable row level security;
alter table wa_conversations    enable row level security;
alter table wa_messages         enable row level security;
alter table audit_log           enable row level security;

-- organização: membros leem; owner/admin atualizam
create policy org_read   on organizations for select using (id in (select current_orgs()));
create policy org_update on organizations for update using (org_role(id) in ('owner','admin'));

create policy member_read   on org_members for select using (user_id = auth.uid() or org_id in (select current_orgs()));
create policy member_admin  on org_members for all    using (org_role(org_id) in ('owner','admin'));

-- padrão genérico: SELECT/INSERT/UPDATE/DELETE restritos à própria organização.
-- (gerado por loop via DO block para não repetir 16x)
do $$
declare t text;
begin
  foreach t in array array[
    'clients','client_addresses','contacts','client_units','interactions','consents',
    'products','opportunities','activities','orders','order_items','negotiated_prices',
    'wa_conversations','wa_messages'
  ] loop
    execute format($f$
      create policy tenant_isolation on %I
      using      (org_id in (select current_orgs()))
      with check (org_id in (select current_orgs()));
    $f$, t);
  end loop;
end $$;

-- trigger: updated_at automático
create or replace function touch_updated_at() returns trigger
language plpgsql as $$
begin new.updated_at = now(); return new; end $$;
create trigger clients_touch before update on clients      for each row execute function touch_updated_at();
create trigger opps_touch     before update on opportunities for each row execute function touch_updated_at();

-- baixa de estoque ao inserir item de pedido (regra do protótipo, agora atômica)
create or replace function decrement_stock() returns trigger
language plpgsql security definer as $$
begin
  if new.product_id is not null then
    update products set est = est - new.qty
    where id = new.product_id and est >= new.qty;
    if not found then
      raise exception 'Estoque insuficiente para o produto %', new.product_id;
    end if;
  end if;
  return new;
end $$;
create trigger order_items_stock before insert on order_items
  for each row execute function decrement_stock();
