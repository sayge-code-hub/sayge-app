// Invite / manage employee auth invites (any email domain).
// Deploy: supabase functions deploy invite-employee --no-verify-jwt
// (JWT is verified inside; service role is used only after caller checks out.)
//
// Body.action:
//   invite (default) — inviteUserByEmail
//   list             — pending invites (must_set_password / invited & unconfirmed)
//   resend           — re-invite by email
//   revoke           — deleteUser if never accepted, else users.is_active = false

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
}

function isValidEmail(email: string): boolean {
  return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)
}

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

    const body = await req.json().catch(() => ({}))
    const action = String(body.action ?? 'invite').trim().toLowerCase()

    if (action === 'list') {
      return await listPendingInvites(admin)
    }

    if (action === 'resend') {
      return await resendInvite(admin, body)
    }

    if (action === 'revoke') {
      return await revokeInvite(admin, body)
    }

    if (action !== 'invite') {
      return json({ error: `Unknown action: ${action}` }, 400)
    }

    return await inviteUser(admin, body)
  } catch (e) {
    const message = e instanceof Error ? e.message : 'Invite failed'
    return json({ error: message }, 500)
  }
})

async function listPendingInvites(
  admin: ReturnType<typeof createClient>,
) {
  const pending: Array<{
    id: string
    email: string
    fullName: string
    invitedAt: string | null
    createdAt: string | null
  }> = []

  let page = 1
  const perPage = 200
  for (;;) {
    const { data, error } = await admin.auth.admin.listUsers({
      page,
      perPage,
    })
    if (error) {
      return json({ error: error.message }, 400)
    }
    const users = data?.users ?? []
    for (const user of users) {
      if (!isPendingInvite(user)) continue
      const email = (user.email ?? '').toLowerCase()
      if (!isValidEmail(email)) continue
      const meta = (user.user_metadata ?? {}) as Record<string, unknown>
      const fullName = String(meta.full_name ?? meta.name ?? '').trim()
      pending.push({
        id: user.id,
        email,
        fullName,
        invitedAt: user.invited_at ?? null,
        createdAt: user.created_at ?? null,
      })
    }
    if (users.length < perPage) break
    page += 1
    if (page > 50) break
  }

  pending.sort((a, b) =>
    (b.invitedAt ?? b.createdAt ?? '').localeCompare(
      a.invitedAt ?? a.createdAt ?? '',
    ),
  )

  return json({ ok: true, invites: pending })
}

function isPendingInvite(user: {
  email_confirmed_at?: string | null
  invited_at?: string | null
  user_metadata?: Record<string, unknown> | null
}): boolean {
  const meta = (user.user_metadata ?? {}) as Record<string, unknown>
  const mustSet =
    meta.must_set_password === true ||
    meta.must_set_password === 'true' ||
    meta.must_set_password === 1
  const unconfirmed = !user.email_confirmed_at
  const invited = Boolean(user.invited_at)
  return mustSet || (invited && unconfirmed)
}

async function inviteUser(
  admin: ReturnType<typeof createClient>,
  body: Record<string, unknown>,
) {
  const emailRaw = String(body.email ?? '').trim().toLowerCase()
  const fullName = String(body.fullName ?? body.full_name ?? '').trim()
  const roleId = String(body.roleId ?? body.role_id ?? 'role_employee').trim()
  const employeeId = String(body.employeeId ?? body.employee_id ?? '').trim()
  const cafeId = String(body.cafeId ?? body.cafe_id ?? '').trim()
  const redirectTo = String(body.redirectTo ?? body.redirect_to ?? '').trim()

  if (!isValidEmail(emailRaw)) {
    return json({ error: 'Enter a valid email address' }, 400)
  }

  const inviteOptions: {
    data: Record<string, string>
    redirectTo?: string
  } = {
    data: {
      full_name: fullName || emailRaw.split('@')[0],
      name: fullName || emailRaw.split('@')[0],
      role_id: roleId,
      must_set_password: 'true',
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
    if (cafeId) patch.cafe_id = cafeId

    // Profile row is created by on_auth_user_created; update extras.
    // Retry briefly — the trigger may race the first update.
    let patchErr: { message?: string } | null = null
    for (let attempt = 0; attempt < 3; attempt++) {
      const { error } = await admin.from('users').update(patch).eq('id', userId)
      if (!error) {
        patchErr = null
        break
      }
      patchErr = error
      await new Promise((r) => setTimeout(r, 200 * (attempt + 1)))
    }
    if (patchErr) {
      return json(
        {
          error:
            `Invite email sent, but the user profile could not be updated: ${patchErr.message ?? 'unknown error'}`,
        },
        500,
      )
    }

    const { data: profile } = await admin
      .from('users')
      .select('id')
      .eq('id', userId)
      .maybeSingle()
    if (!profile) {
      return json(
        {
          error:
            'Invite email sent, but no app profile was created. Check lock_signup_provisioning.sql.',
        },
        500,
      )
    }
  }

  return json({
    ok: true,
    email: emailRaw,
    userId,
    message: 'Invite email sent. The employee will set their own password.',
  })
}

async function resendInvite(
  admin: ReturnType<typeof createClient>,
  body: Record<string, unknown>,
) {
  const emailRaw = String(body.email ?? '').trim().toLowerCase()
  if (!isValidEmail(emailRaw)) {
    return json({ error: 'Enter a valid email address' }, 400)
  }

  const redirectTo = String(body.redirectTo ?? body.redirect_to ?? '').trim()

  // Prefer generateLink for existing pending users (re-inviteUserByEmail fails).
  const linkOptions: {
    type: 'invite'
    email: string
    options?: { redirectTo?: string; data?: Record<string, string> }
  } = {
    type: 'invite',
    email: emailRaw,
    options: {
      data: { must_set_password: 'true' },
    },
  }
  if (redirectTo) {
    linkOptions.options = {
      ...linkOptions.options,
      redirectTo,
    }
  }

  const { data: linkData, error: linkErr } =
    await admin.auth.admin.generateLink(linkOptions)

  if (linkErr) {
    // User may not exist yet — fall back to a fresh invite.
    if (/not found|does not exist/i.test(linkErr.message)) {
      return await inviteUser(admin, body)
    }
    return json({ error: linkErr.message }, 400)
  }

  // generateLink sends the invite email when type is invite.
  const userId = linkData.user?.id
  return json({
    ok: true,
    email: emailRaw,
    userId,
    message: 'Invite email resent.',
  })
}

async function revokeInvite(
  admin: ReturnType<typeof createClient>,
  body: Record<string, unknown>,
) {
  const emailRaw = String(body.email ?? '').trim().toLowerCase()
  const userIdBody = String(body.userId ?? body.user_id ?? '').trim()

  let userId = userIdBody
  let authUser: {
    id: string
    email?: string
    email_confirmed_at?: string | null
    invited_at?: string | null
    user_metadata?: Record<string, unknown> | null
  } | null = null

  if (userId) {
    const { data, error } = await admin.auth.admin.getUserById(userId)
    if (error || !data.user) {
      return json({ error: error?.message ?? 'User not found' }, 404)
    }
    authUser = data.user
  } else if (emailRaw) {
    // Scan for matching email (listUsers has no email filter in all versions).
    let page = 1
    const perPage = 200
    for (;;) {
      const { data, error } = await admin.auth.admin.listUsers({
        page,
        perPage,
      })
      if (error) return json({ error: error.message }, 400)
      const found = (data?.users ?? []).find(
        (u) => (u.email ?? '').toLowerCase() === emailRaw,
      )
      if (found) {
        authUser = found
        userId = found.id
        break
      }
      if ((data?.users ?? []).length < perPage) break
      page += 1
      if (page > 50) break
    }
    if (!authUser) {
      return json({ error: 'User not found' }, 404)
    }
  } else {
    return json({ error: 'email or userId is required' }, 400)
  }

  const neverAccepted = isPendingInvite(authUser)

  if (neverAccepted) {
    const { error: delErr } = await admin.auth.admin.deleteUser(userId)
    if (delErr) {
      return json({ error: delErr.message }, 400)
    }
    // Best-effort cleanup of profile row if it remains.
    await admin.from('users').delete().eq('id', userId)
    return json({
      ok: true,
      revoked: true,
      deleted: true,
      userId,
      email: authUser.email ?? emailRaw,
    })
  }

  const { error: patchErr } = await admin
    .from('users')
    .update({ is_active: false })
    .eq('id', userId)
  if (patchErr) {
    return json({ error: patchErr.message }, 400)
  }

  return json({
    ok: true,
    revoked: true,
    deleted: false,
    deactivated: true,
    userId,
    email: authUser.email ?? emailRaw,
  })
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}
