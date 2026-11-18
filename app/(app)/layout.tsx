import { redirect } from "next/navigation";
import { createClient, getUser } from "@/lib/supabase/server";

/** Layout autenticado: valida sessão, carrega organizações do usuário e renderiza o shell. */
export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const user = await getUser();
  if (!user) redirect("/login");

  const supabase = await createClient();
  const { data: memberships } = await supabase
    .from("org_members")
    .select("role, organizations(id, name)")
    .eq("user_id", user.id);

  const orgs = (memberships ?? []).map((m: any) => ({
    id: m.organizations.id,
    name: m.organizations.name,
    role: m.role,
  }));
  if (orgs.length === 0) {
    return <main style={{ padding: 48 }}><h1>Sem organização</h1><p className="sub">Sua conta ainda não foi vinculada a uma vinícola. Contate o suporte.</p></main>;
  }

  return (
    <div style={{ display: "flex", minHeight: "100vh" }}>
      <nav>{/* Sidebar com NAV + seletor de organização — implementar em components/nav */}</nav>
      <main style={{ flex: 1, padding: "32px 48px", maxWidth: 1120 }}>{children}</main>
    </div>
  );
}
