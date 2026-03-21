import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'jsr:@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'unauthenticated' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    const { groupId } = await req.json()
    if (!groupId) {
      return new Response(JSON.stringify({ error: 'invalid-argument: groupId is required.' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    // Initialize Supabase admin client to bypass RLS for complex transaction-like flow
    const supabaseUrl = Deno.env.get('SUPABASE_URL') || ''
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || ''
    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey)

    // User client to get UID
    const supabaseUser = createClient(supabaseUrl, Deno.env.get('SUPABASE_ANON_KEY') || '', {
      global: { headers: { Authorization: authHeader } }
    })
    const { data: { user }, error: authError } = await supabaseUser.auth.getUser()
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'invalid-token' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    // 1. Get Group
    const { data: group, error: groupError } = await supabaseAdmin
      .from('groups')
      .select('*')
      .eq('id', groupId)
      .single()

    if (groupError || !group) {
      return new Response(JSON.stringify({ error: 'not-found: Group not found.' }), { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    if (group.creator_id !== user.id) {
      return new Response(JSON.stringify({ error: 'permission-denied: Only the group creator can settle.' }), { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    // 2. Find active cycle
    const { data: activeCycle, error: activeCycleError } = await supabaseAdmin
      .from('cycles')
      .select('*')
      .eq('group_id', groupId)
      .eq('status', 'settling')
      .single()

    // Note: If the app expects it to be 'settling' but it might still just be 'active', adapt logic
    // The legacy Node code checked groupData.cycleStatus === 'settling'
    if (activeCycleError || !activeCycle) {
      return new Response(JSON.stringify({ error: 'failed-precondition: Group is not in settling status.' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    const nowIso = new Date().toISOString()
    const startDate = activeCycle.start_date || nowIso // simplified date logic from Node

    // 3. Close old cycle
    await supabaseAdmin
      .from('cycles')
      .update({ status: 'closed', end_date: nowIso })
      .eq('id', activeCycle.id)

    // 4. Create new cycle
    const { data: newCycle, error: insertError } = await supabaseAdmin
      .from('cycles')
      .insert({
        group_id: groupId,
        status: 'active',
        start_date: nowIso
      })
      .select()
      .single()

    if (insertError || !newCycle) {
      console.error('Failed to create new cycle:', insertError)
      return new Response(JSON.stringify({ error: 'internal: Failed to create new cycle.' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    // 5. Delete pending payment attempts
    await supabaseAdmin
      .from('payment_attempts')
      .delete()
      .eq('group_id', groupId)
      .eq('cycle_id', activeCycle.id)

    // 6. Update group status line / amount if needed (reset to 0)
    await supabaseAdmin
      .from('groups')
      .update({ amount: 0, status_line: 'Settled completely' })
      .eq('id', groupId)

    return new Response(JSON.stringify({ success: true, newCycleId: newCycle.id }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  } catch (error) {
    console.error('settleAndRestart Error:', error)
    return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  }
})
