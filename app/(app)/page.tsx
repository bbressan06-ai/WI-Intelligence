import { getUser } from "@/lib/supabase/server";
import { redirect } from "next/navigation";

/** Visão geral (home) — migrar os KPIs do protótipo V.home para queries no Postgres. */
export default async function HomePage() {
  const user = await getUser();
  if (!user) redirect("/login");

  return (
    <>
      <div className="row" style={{ marginBottom: 32 }}>
        <div><h1>Visão geral</h1><div className="sub">O que fazer agora</div></div>
      </div>
      <div className="card">
        <p className="empty">
          KPIs (receita, pedidos, clientes ativos 90d, oportunidades abertas, atividades atrasadas)
          e lista de próximas ações — migração do protótipo V.home + recs() para queries SQL.
        </p>
      </div>
    </>
  );
}
