import { createClient } from '@supabase/supabase-js'

export const supabaseUrl = (import.meta.env.VITE_SUPABASE_URL || '').trim()
export const supabaseAnonKey = (import.meta.env.VITE_SUPABASE_ANON_KEY || '').trim()
export const isSupabaseConfigured = Boolean(
  supabaseUrl &&
  supabaseAnonKey &&
  !supabaseUrl.includes('YOUR_PROJECT') &&
  !supabaseAnonKey.includes('YOUR_PUBLIC') &&
  !supabaseAnonKey.includes('YOUR_')
)

// Keep the application renderable even when .env.local is missing.
// App.tsx shows a clear setup screen instead of failing with a white page.
export const supabase = createClient(
  isSupabaseConfigured ? supabaseUrl : 'https://placeholder.supabase.co',
  isSupabaseConfigured ? supabaseAnonKey : 'placeholder-anon-key',
)
