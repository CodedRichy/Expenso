import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'jsr:@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'unauthenticated' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    const { action, ...args } = await req.json()
    if (!action) {
      return new Response(JSON.stringify({ error: 'Missing action' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    // Initialize Supabase admin client
    const supabaseUrl = Deno.env.get('SUPABASE_URL') || ''
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || ''
    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey)

    // User client to get UID and verify identity
    const supabaseUser = createClient(supabaseUrl, Deno.env.get('SUPABASE_ANON_KEY') || '', {
      global: { headers: { Authorization: authHeader } }
    })
    const { data: { user }, error: authError } = await supabaseUser.auth.getUser()
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Invalid token' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    // AUTH CHECK: Verify if the user is an admin
    const adminPhones = (Deno.env.get('ADMIN_PHONES') || '').split(',')
    const adminEmails = (Deno.env.get('ADMIN_EMAILS') || '').split(',')
    const isAdmin = adminPhones.includes(user.phone || '') || adminEmails.includes(user.email || '')
    
    if (!isAdmin) {
      return new Response(JSON.stringify({ error: 'Forbidden: Admin access required' }), { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    // ACTION DISPATCHER
    let result: any = null

    switch (action) {
      case 'fetchUsers':
        const { data: users, error: uErr } = await supabaseAdmin
          .from('users')
          .select('*, group_members(count), fcm_tokens(*)')
        if (uErr) throw uErr
        
        // Post-processing to match legacy format
        result = { 
          users: users.map(u => ({
            uid: u.id,
            displayName: u.display_name,
            phoneNumber: u.phone,
            photoURL: u.avatar_url,
            isBeta: u.is_beta,
            isBanned: u.is_banned,
            joinedAt: u.created_at ? new Date(u.created_at).getTime() : null,
            lastSeen: u.last_seen ? new Date(u.last_seen).getTime() : null,
            _groups: u.group_members?.[0]?.count || 0,
            _devices: u.fcm_tokens || []
          }))
        }
        break

      case 'fetchGroups':
        const { data: groups, error: gErr } = await supabaseAdmin
          .from('groups')
          .select('*, group_members(count)')
        if (gErr) throw gErr
        
        result = {
          groups: groups.map(g => ({
            gid: g.id,
            groupName: g.name,
            creatorId: g.creator_id,
            cycleStatus: g.status,
            currencyCode: g.currency_code,
            members: g.group_members?.[0]?.count || 0,
            createdAt: g.created_at ? new Date(g.created_at).getTime() : null
          }))
        }
        break

      case 'fetchAnalytics':
        const [
          { count: totalUsers },
          { count: totalGroups },
          { data: expenses }
        ] = await Promise.all([
          supabaseAdmin.from('users').select('*', { count: 'exact', head: true }),
          supabaseAdmin.from('groups').select('*', { count: 'exact', head: true }),
          supabaseAdmin.from('expenses').select('amount_minor')
        ])
        
        const totalVolume = expenses?.reduce((sum, e) => sum + (e.amount_minor || 0), 0) || 0
        const now = new Date()
        const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000).toISOString()
        
        const { count: activeUsers } = await supabaseAdmin
          .from('users')
          .select('*', { count: 'exact', head: true })
          .gte('last_seen', thirtyDaysAgo)

        result = {
          totalUsers,
          totalGroups,
          totalVolume,
          activeUsers,
          dau: 0, // Simplified for now
          mau: activeUsers,
          uptime: 99.9,
          latency: 45
        }
        break

      case 'manageUser':
        const { uid, updates } = args
        if (!uid) throw new Error('UID required')
        
        // Map updates to DB format
        const dbUpdates: any = {}
        if (updates.displayName !== undefined) dbUpdates.display_name = updates.displayName
        if (updates.isBeta !== undefined) dbUpdates.is_beta = updates.isBeta
        if (updates.isBanned !== undefined) dbUpdates.is_banned = updates.isBanned
        
        const { error: updErr } = await supabaseAdmin
          .from('users')
          .update(dbUpdates)
          .eq('id', uid)
        if (updErr) throw updErr
        
        result = { success: true }
        break

      case 'deleteGroup':
        const { groupId } = args
        if (!groupId) throw new Error('GroupId required')
        
        const { error: delGErr } = await supabaseAdmin
          .from('groups')
          .delete()
          .eq('id', groupId)
        if (delGErr) throw delGErr
        
        result = { success: true }
        break

      default:
        return new Response(JSON.stringify({ error: `Action ${action} not supported` }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    return new Response(JSON.stringify(result), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  } catch (error) {
    console.error('admin-api Error:', error)
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : String(error) }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  }
})
