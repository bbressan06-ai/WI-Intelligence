// Tipos do domínio Wine Intelligence — espelham o schema SQL (0001_init.sql)

export type AccountKind = "B2C" | "B2B";
export type UserRole = "owner" | "admin" | "vendedor" | "leitor";
export type RecPriority = "Baixa" | "Média" | "Alta";
export type MatchLevel = "alta" | "média" | "baixa" | null;

export interface Organization {
  id: string;
  name: string;
  plan: "trial" | "essencial" | "profissional" | "avancado" | "corporativo";
  trial_ends: string | null;
  settings: OrgSettings;
}

/** Pesos da compatibilidade — antes DB.w no protótipo, agora por organização */
export interface OrgSettings {
  weights: {
    tipo: number; doc: number; corpo: number; acid: number;
    preco: number; uva: number; tan: number;
    marg: number; harm: number; // B2B
  };
}

export interface Profile {
  tipo?: string;
  doc?: string;   // doçura
  corpo?: string;
  acid?: string;  // acidez
  tan?: string;   // taninos
  preco?: number;
  uvas?: string;
  arom?: string;
  ocas?: string;
  gastro?: string;
  marg?: number;
  giro?: "baixo" | "médio" | "alto";
  aprov?: string[]; // product ids
  rej?: string[];
}

export interface Product {
  id: string;
  org_id: string;
  name: string;
  vintage: number | null;
  tipo: string;
  uva: string;
  doc: string; corpo: string; acid: string; tan: string;
  preco: number;
  atac?: number;
  margem?: number;
  est: number;
  harm?: string;
  active: boolean;
}

export interface Client {
  id: string;
  org_id: string;
  kind: AccountKind;
  name: string;
  doc?: string;
  nasc?: string;
  phone?: string;
  email?: string;
  source?: string;
  owner_id?: string;
  seg?: string;
  pot?: "Baixo" | "Médio" | "Alto";
  obs?: string;
  since: string;
  prefs: Profile;
}

export interface MatchExplanation {
  ok: string[];   // por que combina
  bad: string[];  // por que pode não combinar
  miss: string[]; // critérios sem dados
}

export interface MatchResult extends MatchExplanation {
  n: number;        // nº de critérios avaliados
  score: number;    // 0–100
  level: MatchLevel;
}
