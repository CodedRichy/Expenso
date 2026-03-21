import "jsr:@supabase/functions-js/edge-runtime.d.ts"
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

    const keyId = Deno.env.get('RAZORPAY_KEY_ID')
    const keySecret = Deno.env.get('RAZORPAY_KEY_SECRET')
    if (!keyId || !keySecret) {
      return new Response(JSON.stringify({ error: 'failed-precondition' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    const { amountPaise, receipt } = await req.json()
    if (!amountPaise || isNaN(Number(amountPaise)) || Number(amountPaise) <= 0) {
      return new Response(JSON.stringify({ error: 'invalid-argument' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    const amount = Number(amountPaise)
    
    // Call Razorpay API
    const credentials = btoa(`${keyId}:${keySecret}`)
    const rzpResponse = await fetch('https://api.razorpay.com/v1/orders', {
      method: 'POST',
      headers: {
        'Authorization': `Basic ${credentials}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        amount,
        currency: 'INR',
        receipt: receipt || `expenso_${Date.now()}`,
      })
    })

    if (!rzpResponse.ok) {
      const errText = await rzpResponse.text()
      console.error('Razorpay Error:', errText)
      return new Response(JSON.stringify({ error: 'Razorpay API Error' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    const order = await rzpResponse.json()
    return new Response(JSON.stringify({ orderId: order.id, keyId }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  } catch (error) {
    console.error('createRazorpayOrder Error:', error)
    return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  }
})
