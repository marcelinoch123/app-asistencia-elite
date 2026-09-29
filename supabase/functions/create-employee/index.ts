import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    if (!supabaseServiceRoleKey) {
      throw new Error("SUPABASE_SERVICE_ROLE_KEY no configurado en variables de entorno");
    }

    // 1. Validar que la llamada provenga de un usuario autenticado con sesión válida
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "No se proporcionó token de autorización" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const {
      data: { user: callerUser },
      error: callerError,
    } = await userClient.auth.getUser();

    if (callerError || !callerUser) {
      return new Response(
        JSON.stringify({ error: "Token de sesión inválido o expirado" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Validar que el usuario que invoca tenga rol de administrador
    const { data: adminRecord, error: adminCheckError } = await userClient
      .from("users")
      .select("role, status")
      .eq("id", callerUser.id)
      .maybeSingle();

    if (adminCheckError || !adminRecord || adminRecord.role !== "admin") {
      return new Response(
        JSON.stringify({ error: "Acceso denegado: Solo administradores pueden crear colaboradores" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 3. Extraer y validar campos del cuerpo de la petición
    const body = await req.json();
    const {
      email,
      password,
      full_name,
      ci,
      role = "employee",
      department = "General",
      phone,
      address,
      client_id,
      employee_type = "field",
    } = body;

    if (!email || !password || !full_name) {
      return new Response(
        JSON.stringify({ error: "Nombre completo, email y contraseña son obligatorios" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (password.length < 8) {
      return new Response(
        JSON.stringify({ error: "La contraseña debe tener un mínimo de 8 caracteres" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 4. Instanciar cliente con Service Role Key para operaciones de administración
    const adminClient = createClient(supabaseUrl, supabaseServiceRoleKey);

    // 5. Crear el usuario en Supabase Auth con confirmación automática de correo
    const { data: createdAuth, error: createAuthError } = await adminClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        full_name,
        ci,
        role,
      },
    });

    if (createAuthError) {
      return new Response(
        JSON.stringify({ error: `Error creando usuario en Auth: ${createAuthError.message}` }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const newUserId = createdAuth.user.id;

    // 6. Registrar en la tabla public.users
    const userData = {
      id: newUserId,
      email,
      name: full_name,
      full_name,
      ci: ci || null,
      role,
      department: department || "General",
      phone: phone || null,
      address: address || null,
      client_id: client_id || null,
      employee_type: employee_type || "field",
      status: "active",
      is_active: true,
      created_at: new Date().toISOString(),
    };

    const { data: insertedUser, error: insertError } = await adminClient
      .from("users")
      .upsert(userData)
      .select()
      .single();

    if (insertError) {
      return new Response(
        JSON.stringify({
          error: `Usuario creado en Auth pero falló registro en tabla: ${insertError.message}`,
          user_id: newUserId,
        }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: "Empleado creado exitosamente",
        user: insertedUser,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message || "Error interno del servidor" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
