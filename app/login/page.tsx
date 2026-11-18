"use client";

import { useState } from "react";
import { supabase } from "@/lib/supabase/client";
import { useRouter } from "next/navigation";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [sent, setSent] = useState(false);
  const router = useRouter();

  async function signIn(e: React.FormEvent) {
    e.preventDefault();
    const { error } = await supabase.auth.signInWithOtp({ email });
    if (!error) setSent(true);
  }

  return (
    <main style={{ display: "grid", placeItems: "center", minHeight: "100vh" }}>
      <div className="card" style={{ width: 380 }}>
        <h1>Wine Intelligence</h1>
        {sent ? (
          <p className="sub">Enviamos um link de acesso para {email}. Verifique sua caixa de entrada.</p>
        ) : (
          <form onSubmit={signIn}>
            <p className="sub" style={{ marginBottom: 16 }}>Entre com seu e-mail (link mágico).</p>
            <input
              type="email" required placeholder="seu@email.com" value={email}
              onChange={(e) => setEmail(e.target.value)}
            />
            <button className="primary" style={{ width: "100%", marginTop: 12 }}>Entrar</button>
          </form>
        )}
        <p className="tag" style={{ marginTop: 16 }}>
          Sem conta? Peça ao administrador da sua vinícola um convite.
        </p>
      </div>
    </main>
  );
}
