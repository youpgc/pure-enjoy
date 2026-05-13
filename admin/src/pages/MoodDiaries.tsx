import React from 'react'
import DataTable from '../components/DataTable'
import { supabase } from '../utils/supabase'
import dayjs from 'dayjs'

const MoodDiaries: React.FC = () => {
  const columns = [
    { title: '用户ID', dataIndex: 'user_id', key: 'user_id', width: 200 },
    {
      title: '心情',
      dataIndex: 'mood',
      key: 'mood',
      render: (mood: string) => <span style={{ fontSize: 24 }}>{mood}</span>,
    },
    { title: '标签', dataIndex: 'mood_label', key: 'mood_label' },
    {
      title: '内容',
      dataIndex: 'content',
      key: 'content',
      ellipsis: true,
      width: 300,
    },
    {
      title: '日期',
      dataIndex: 'date',
      key: 'date',
      render: (date: string) => dayjs(date).format('YYYY-MM-DD'),
    },
  ]

  const fetchData = async () => {
    const { data, error } = await supabase
      .from('mood_diaries')
      .select('*')
      .order('date', { ascending: false })
    if (error) throw error
    return data || []
  }

  const deleteItem = async (id: string) => {
    const { error } = await supabase.from('mood_diaries').delete().eq('id', id)
    if (error) throw error
  }

  return (
    <DataTable
      title="心情日记管理"
      tableName="mood_diaries"
      columns={columns}
      fetchData={fetchData}
      onDelete={deleteItem}
    />
  )
}

export default MoodDiaries
