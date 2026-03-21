import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { encodeBase64 } from "jsr:@std/encoding/base64"
import { createClient } from 'jsr:@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

async function generateKey(id: string, masterKey: string): Promise<string> {
  const enc = new TextEncoder()
  const key = await crypto.subtle.importKey(
    'raw',
    enc.encode(masterKey),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  )
  const signature = await crypto.subtle.sign('HMAC', key, enc.encode(id))
  return encodeBase64(new Uint8Array(signature))
}

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
      return new Response(JSON.stringify({ error: 'invalid-argument: groupId missing' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    const masterKey = Deno.env.get('DATA_ENCRYPTION_MASTER_KEY')
    if (!masterKey) {
      return new Response(JSON.stringify({ error: 'failed-precondition: MASTER_KEY not set' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    // Verify token
    const supabaseUrl = Deno.env.get('SUPABASE_URL') || ''
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') || ''
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } }
    })
    
    // Ensure user is in group
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'invalid-token' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    const { data: membership, error: memberError } = await supabase
      .from('group_members')
      .select('user_id')
      .eq('group_id', groupId)
      .eq('user_id', user.id)
      .maybeSingle()

    if (memberError || !membership) {
      return new Response(JSON.stringify({ error: 'permission-denied: Not in group' }), { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    const key = await generateKey(groupId, masterKey)

    return new Response(JSON.stringify({ key }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  } catch (error) {
    console.error('getGroupEncryptionKey Error:', error)
    return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  }
})
