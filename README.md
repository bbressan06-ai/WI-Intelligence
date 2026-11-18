# Wine Intelligence CRM

CRM de inteligência comercial para o mercado vitivinícola (B2C + B2B).
**CRM mostra o que aconteceu. Wine Intelligence ajuda a decidir o que fazer.**

## Estado do projeto

- **Protótipo original**: HTML único (`localStorage`) — a lógica de negócio dele está sendo migrada para cá. A UI pode ser consultada no arquivo de protótipo para fidelidade visual.
- **Fase atual**: Fase 0 — fundação (estrutura, schema, auth, migração de telas).

## Stack

| Camada | Tecnologia |
|---|---|
| Frontend + backend | Next.js 15 (React 19, TypeScript, Server Actions) |
| Banco | PostgreSQL (Supabase) com **RLS para multi-tenancy** |
| Auth | Supabase Auth (link mágico; Google opcional) |
| Hospedagem | Vercel + Supabase |
| Pagamentos (Fase 1) | Mercado Pago (Pix/boleto) ou Stripe |
| E-mail (Fase 2) | Resend |
| WhatsApp (Fase 2) | Cloud API via BSP oficial |

## Estrutura

```
app/
  layout.tsx            # raiz (fonte, metadata)
  globals.css           # design tokens do protótipo (cores minimalistas)
  login/page.tsx        # auth: link mágico
  (app)/
    layout.tsx          # shell autenticado + seleção de organização
    page.tsx            # Visão geral (KPIs)
lib/
  types.ts              # tipos do domínio (espelham o schema SQL)
  recommendation.ts     # motor de compatibilidade explicável (match/ranked)
  supabase/{client,server}.ts
supabase/migrations/
  0001_init.sql         # schema completo + RLS + triggers
components/
  nav.ts                # navegação (espelha o NAV do protótipo)
```

## Regras de arquitetura (não negociáveis)

1. **Multi-tenancy**: toda tabela de negócio tem `org_id`; RLS no Postgres garante
   isolamento — mesmo SQL direto não atravessa organizações.
2. **Regras no servidor**: cálculo de estoque, preços e permissões nunca dependem do cliente.
3. **Explicabilidade**: toda recomendação (Mapa de Paladar, ações) mantém `ok/bad/miss`
   — é o diferencial do produto, não pode virar caixa-preta.
4. **LGPD**: consentimento em tabela própria (`consents`); exportação/exclusão do titular
   como direitos de primeira classe.
5. **Preservar o protótipo**: o motor `match()` foi migrado sem alteração de semântica
   (`lib/recommendation.ts`). Mudanças de regra só com justificativa.

## Setup local

```bash
# 1. Dependências
npm install

# 2. Supabase: crie um projeto em supabase.com e copie as chaves
cp .env.example .env.local   # preencha NEXT_PUBLIC_SUPABASE_URL e ANON_KEY

# 3. Schema (requer Supabase CLI)
npx supabase link --project-ref SEU_REF
npx supabase db push

# 4. Rodar
npm run dev   # http://localhost:3000
```

Para o primeiro acesso: crie um usuário em Supabase → Auth, depois insira
`organizations` + `org_members` (role `owner`) pelo painel SQL.

## Roadmap

- **Fase 0 (atual)** — fundação: schema, RLS, auth, migração das telas do protótipo.
- **Fase 1** — MVP comercial: convites de equipe, papéis, importador CSV, billing
  (Essencial R$149 / Profissional R$299 / Avançado R$599, trial 7 dias).
- **Fase 2** — integrações: WhatsApp Cloud API (inbox, vínculo cliente/oportunidade,
  detecção de conversas sem retorno), e-mail, calendário.
- **Fase 3** — diferenciais: News automático, relatórios avançados, IA sobre histórico real.

## Migrações pendentes do protótipo (checklist de telas)

- [ ] Visão geral com KPIs + recomendações de ação (`recs()`)
- [ ] Clientes/contas + Customer 360 + duplicados/mescla
- [ ] Mapa de Paladar (questionário + ranking)
- [ ] Funis B2C/B2B + propostas + pedidos (preços negociados, baixa de estoque via trigger)
- [ ] Catálogo com importação CSV
- [ ] WhatsApp (inbox real via BSP)
- [ ] Relatórios + Configurações (pesos por organização)
