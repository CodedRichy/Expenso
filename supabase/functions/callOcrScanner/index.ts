import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'jsr:@supabase/supabase-js@2'
import { encodeBase64 } from "jsr:@std/encoding/base64"
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

    const { storagePath } = await req.json()
    if (!storagePath) {
      return new Response(JSON.stringify({ error: 'invalid-argument' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    const groqApiKey = Deno.env.get('GROQ_API_KEY')
    if (!groqApiKey) {
      return new Response(JSON.stringify({ error: 'failed-precondition' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    // Initialize Supabase client representing the authenticated user
    const supabaseUrl = Deno.env.get('SUPABASE_URL') || ''
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') || ''
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } }
    })

    // Download image from user's storage bucket
    const { data: fileData, error: downloadError } = await supabase.storage
      .from('receipts')
      .download(storagePath)

    if (downloadError || !fileData) {
      console.error('Download error:', downloadError)
      return new Response(JSON.stringify({ error: 'Failed to download receipt image.' }), { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    // Convert image buffer to base64
    const uint8Array = new Uint8Array(await fileData.arrayBuffer())
    const base64Image = encodeBase64(uint8Array)
    const mimeType = fileData.type || 'image/jpeg'

    // Call Groq Vision Model (llama-3.2-11b-vision-preview)
    const apiResponse = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${groqApiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: 'llama-3.2-11b-vision-preview',
        messages: [
          {
            role: 'user',
            content: [
              { type: 'text', text: 'Extract all the raw text from this receipt exactly as it appears. Do not format it as JSON, just return the raw text block.' },
              { type: 'image_url', image_url: { url: `data:${mimeType};base64,${base64Image}` } }
            ]
          }
        ],
        temperature: 0,
        max_tokens: 1024
      })
    })

    if (!apiResponse.ok) {
      const respText = await apiResponse.text()
      console.error('Groq Vision Error:', respText)
      return new Response(JSON.stringify({ error: `Groq Vision Error: ${apiResponse.status}` }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    const data = await apiResponse.json()
    const extractedText = data.choices?.[0]?.message?.content || ''

    return new Response(JSON.stringify({ text: extractedText }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  } catch (error) {
    console.error('callOcrScanner Error:', error)
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : String(error) }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  }
})
