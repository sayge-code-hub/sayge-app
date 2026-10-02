// Invite an @sayge.in employee via Supabase Auth invite email.
// Deploy: supabase functions deploy invite-employee --no-verify-jwt
// (JWT is verified inside; service role is used only after caller checks out.)

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
}

const ALLOWED_DOMAIN = 'sayge.in'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    if (!supabaseUrl || !anonKey || !serviceKey) {
      return json({ error: 'Server misconfigured' }, 500)
    }

    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return json({ error: 'Missing authorization' }, 401)
    }

    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    })
    const {
      data: { user: caller },
      error: callerErr,
    } = await callerClient.auth.getUser()
    if (callerErr || !caller) {
      return json({ error: 'Unauthorized' }, 401)
    }

    const admin = createClient(supabaseUrl, serviceKey)

    const { data: callerProfile, error: profileErr } = await admin
      .from('users')
      .select('id, role_id, roles(code)')
      .eq('id', caller.id)
      .maybeSingle()

    if (profileErr || !callerProfile) {
      return json({ error: 'Caller profile not found' }, 403)
    }

    const roleCode =
      (callerProfile.roles as { code?: string } | null)?.code ?? ''
    if (roleCode !== 'owner' && roleCode !== 'admin') {
      return json({ error: 'Only owners and admins can invite employees' }, 403)
    }

    const body = await req.json()
    const emailRaw = String(body.email ?? '').trim().toLowerCase()
    const fullName = String(body.fullName ?? body.full_name ?? '').trim()
    const roleId = String(body.roleId ?? body.role_id ?? 'role_employee').trim()
    const employeeId = String(body.employeeId ?? body.employee_id ?? '').trim()
    const redirectTo = String(body.redirectTo ?? body.redirect_to ?? '').trim()

    if (!emailRaw.endsWith(`@${ALLOWED_DOMAIN}`)) {
      return json(
        { error: `Only @${ALLOWED_DOMAIN} emails can be invited` },
        400,
      )
    }

    const inviteOptions: {
      data: Record<string, string>
      redirectTo?: string
    } = {
      data: {
        full_name: fullName || emailRaw.split('@')[0],
        name: fullName || emailRaw.split('@')[0],
        role_id: roleId,
      },
    }
    if (redirectTo) {
      inviteOptions.redirectTo = redirectTo
    }

    const { data: invited, error: inviteErr } =
      await admin.auth.admin.inviteUserByEmail(emailRaw, inviteOptions)

    if (inviteErr) {
      return json({ error: inviteErr.message }, 400)
    }

    const userId = invited.user?.id
    if (userId) {
      const patch: Record<string, unknown> = {
        email: emailRaw,
        is_active: true,
      }
      if (fullName) patch.full_name = fullName
      if (roleId) patch.role_id = roleId
      if (employeeId) patch.employee_id = employeeId

      // Profile row is created by on_auth_user_created; update extras.
      await admin.from('users').update(patch).eq('id', userId)
    }

    return json({
      ok: true,
      email: emailRaw,
      userId,
      message: 'Invite email sent. The employee will set their own password.',
    })
  } catch (e) {
    const message = e instanceof Error ? e.message : 'Invite failed'
    return json({ error: message }, 500)
  }
})

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}
