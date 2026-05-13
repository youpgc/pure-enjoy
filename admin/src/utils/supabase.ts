import { createClient } from '@supabase/supabase-js'

// Supabase配置
const SUPABASE_URL = 'https://mhdrbjpqmzswswoazwjg.supabase.co'
const SUPABASE_ANON_KEY = 'sb_publishable_wFx9tlxImVfEpRN4NMkS1g_QOm64aj6'

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)

// 数据表类型
export interface Expense {
  id: string
  user_id: string
  amount: number
  category: string
  note: string | null
  date: string
  created_at: string
}

export interface MoodDiary {
  id: string
  user_id: string
  mood: string
  mood_label: string | null
  content: string | null
  date: string
  created_at: string
}

export interface WeightRecord {
  id: string
  user_id: string
  weight: number
  note: string | null
  date: string
  created_at: string
}

export interface Note {
  id: string
  user_id: string
  title: string
  content: string | null
  category: string | null
  created_at: string
  updated_at: string
  pinned: boolean
}

export interface Novel {
  id: string
  user_id: string
  title: string
  author: string
  cover_url: string | null
  description: string | null
  source: string
  source_id: string
  added_at: string
  last_read_at: string | null
  last_chapter_index: number
  progress: number
}

export interface User {
  id: string
  email: string | null
  created_at: string
  last_sign_in_at: string | null
}
