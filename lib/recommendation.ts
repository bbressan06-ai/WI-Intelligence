/**
 * Motor de compatibilidade explicável — migrado da função match() do protótipo,
 * sem alteração de semântica. Puro (sem I/O), roda no servidor e no cliente.
 */
import type { Profile, Product, OrgSettings, MatchResult, MatchLevel } from "./types";

export const DEFAULT_WEIGHTS: OrgSettings["weights"] = {
  tipo: 30, doc: 25, corpo: 20, acid: 10, preco: 15, uva: 10, tan: 10, marg: 15, harm: 15,
};

/** Escala ordinal para distância entre atributos (do protótipo: LV) */
const LV: Record<string, number> = {
  macio: 1, firme: 3, leve: 1, "médio": 2, medio: 2, encorpado: 3,
  baixa: 1, "média": 2, media: 2, alta: 3, seco: 1, demi: 2, suave: 3, doce: 4,
};

const dist = (a?: string, b?: string): number | null =>
  a && b && LV[a] != null && LV[b] != null
    ? 1 - Math.min(Math.abs(LV[a] - LV[b]), 2) / 2
    : null;

const tokens = (s?: string): string[] =>
  String(s || "").toLowerCase().split(/[,;/]+/).map((y) => y.trim()).filter(Boolean);

export const priceFor = (p: Product, kind: "B2C" | "B2B", negotiated?: Record<string, number>): number =>
  negotiated?.[p.id] ?? (kind === "B2B" && p.atac ? p.atac : p.preco);

export function match(
  pf: Profile,
  p: Product,
  kind: "B2C" | "B2B",
  opts: { weights?: OrgSettings["weights"]; unitPrice?: number } = {},
): MatchResult {
  const W = { ...DEFAULT_WEIGHTS, ...(opts.weights || {}) };
  const unitPrice = opts.unitPrice ?? (kind === "B2B" && p.atac ? p.atac : p.preco);
  const ok: string[] = [], bad: string[] = [], miss: string[] = [];
  let got = 0, tot = 0, n = 0;

  const add = (w: number, label: string, has: boolean, frac: number, why: string) => {
    if (!has) { miss.push(label); return; }
    n++; tot += w; got += w * frac;
    (frac >= 0.7 ? ok : bad).push(why);
  };

  add(W.tipo, "tipo de vinho", !!pf.tipo && !!p.tipo, pf.tipo === p.tipo ? 1 : 0,
    pf.tipo === p.tipo ? `tipo ${p.tipo}` : `prefere ${pf.tipo}, este é ${p.tipo}`);

  ([["doc", "doçura"], ["corpo", "corpo"], ["acid", "acidez"], ["tan", "taninos"]] as const)
    .forEach(([f, label]) => {
      const d = dist(pf[f], p[f]);
      add(W[f], label, d != null, d ?? 0, `${label} ${p[f]} (preferência: ${pf[f]})`);
    });

  const a = tokens(pf.uvas), b = tokens(p.uva);
  add(W.uva, "uvas", a.length > 0 && b.length > 0,
    a.some((x) => b.some((y) => y.includes(x) || x.includes(y))) ? 1 : 0,
    `uva: ${p.uva} (preferência: ${pf.uvas})`);

  const preco = pf.preco;
  add(W.preco, "faixa de preço", !!preco && !!unitPrice,
    !preco ? 0 : unitPrice <= preco ? 1 : unitPrice <= preco * 1.2 ? 0.5 : 0,
    `preço R$ ${unitPrice}${preco != null && unitPrice <= preco ? " dentro" : " acima"} da faixa`);

  if (kind === "B2B") {
    const marg = pf.marg;
    add(W.marg, "margem desejada", !!marg && p.margem != null,
      marg != null && p.margem >= marg ? 1 : marg != null && p.margem >= marg - 5 ? 0.5 : 0,
      `margem ${p.margem}% (desejada: ${marg}%)`);
    const g = tokens(pf.gastro), h = tokens(p.harm);
    add(W.harm, "harmonização", g.length > 0 && h.length > 0,
      g.some((x) => h.some((y) => y.includes(x) || x.includes(y))) ? 1 : 0,
      `harmoniza com ${p.harm} (carta: ${pf.gastro})`);
    if (pf.giro === "alto" && p.est < 30) bad.push(`estoque de ${p.est} unidades pode não sustentar giro alto`);
  }

  const all = Object.entries(W)
    .filter(([k]) => kind === "B2B" || !["marg", "harm"].includes(k))
    .reduce((x, [, w]) => x + w, 0);

  const score = tot ? (got / tot) * 100 : 0;

  const rejected = pf.rej?.includes(p.id);
  if (rejected) bad.push("o cliente já rejeitou este produto");
  if (pf.aprov?.includes(p.id)) ok.push("o cliente já aprovou este produto");

  const level: MatchLevel = rejected
    ? "baixa"
    : n < 3 || tot / all < 0.5
      ? null
      : score >= 75 ? "alta" : score >= 50 ? "média" : "baixa";

  return { n, score, level, ok, bad, miss };
}

export function ranked(
  pf: Profile,
  products: Product[],
  kind: "B2C" | "B2B",
  opts?: { weights?: OrgSettings["weights"]; unitPrice?: (p: Product) => number },
) {
  return products
    .map((p) => ({ p, m: match(pf, p, kind, { weights: opts?.weights, unitPrice: opts?.unitPrice?.(p) }) }))
    .sort((a, b) => (b.m.level ? b.m.score : -1) - (a.m.level ? a.m.score : -1));
}
