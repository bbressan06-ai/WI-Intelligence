# Checklist de deploy — Wine Intelligence CRM
# Execute na ordem. Itens marcados [VOCÊ] exigem suas contas;
# [G4] posso fazer com você pelo navegador do painel.

## 1. Supabase (banco + auth)
- [VOCÊ] Criar conta em https://supabase.com (plano gratuito)
- [VOCÊ/G4] Criar projeto: nome `wine-intelligence`, região **São Paulo (sa-east-1)**, salvar senha do banco
- [G4] Aplicar o schema: SQL Editor → colar `supabase/migrations/0001_init.sql` → Run
- [G4] Auth → Providers → habilitar **Email** (magic link)
- [G4] Auth → URL Configuration → Site URL = URL de produção da Vercel + `http://localhost:3000`
- [G4] Copiar as chaves: Project Settings → API → `URL`, `anon key`, `service_role key`

## 2. GitHub (código)
- [VOCÊ] Criar repositório `wine-intelligence-crm` (privado)
- [VOCÊ] Subir a pasta `wine-intelligence-crm/` para o repo

## 3. Vercel (hospedagem)
- [VOCÊ] Criar conta em https://vercel.com (pode ser com login GitHub, plano Hobby)
- [G4] Importar o repositório → Framework detectado: Next.js
- [G4] Variáveis de ambiente (Production + Preview):
  - `NEXT_PUBLIC_SUPABASE_URL`
  - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
  - `SUPABASE_SERVICE_ROLE_KEY` (marcar como sensível)
- [G4] Deploy → validar build verde

## 4. Pós-deploy
- [G4] Voltar ao Supabase: Site URL = domínio final da Vercel
- [G4] Criar o primeiro usuário (Auth → Add user) + inserir `organizations` e `org_members` (role `owner`)
- [G4] Testar login no app (link mágico) e criar 1 cliente de teste
- [VOCÊ] (Opcional) Domínio próprio na Vercel

## Variáveis do app (.env.local na Vercel)
NEXT_PUBLIC_SUPABASE_URL=https://SEU-PROJETO.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=...
SUPABASE_SERVICE_ROLE_KEY=...
