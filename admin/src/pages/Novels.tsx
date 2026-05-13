import React from 'react'
import { Tag, Progress } from 'antd'
import DataTable from '../components/DataTable'
import { supabase } from '../utils/supabase'
import dayjs from 'dayjs'

const Novels: React.FC = () => {
  const columns = [
    { title: '用户ID', dataIndex: 'user_id', key: 'user_id', width: 200 },
    { title: '书名', dataIndex: 'title', key: 'title' },
    { title: '作者', dataIndex: 'author', key: 'author' },
    { title: '来源', dataIndex: 'source', key: 'source' },
    {
      title: '进度',
      dataIndex: 'progress',
      key: 'progress',
      render: (progress: number) => (
        <Progress percent={Math.round(progress * 100)} size="small" />
      ),
    },
    {
      title: '最后阅读',
      dataIndex: 'last_read_at',
      key: 'last_read_at',
      render: (date: string | null) =>
        date ? dayjs(date).format('YYYY-MM-DD HH:mm') : <Tag color="default">未读</Tag>,
    },
  ]

  const fetchData = async () => {
    const { data, error } = await supabase
      .from('novels')
      .select('*')
      .order('added_at', { ascending: false })
    if (error) throw error
    return data || []
  }

  const deleteItem = async (id: string) => {
    const { error } = await supabase.from('novels').delete().eq('id', id)
    if (error) throw error
  }

  return (
    <DataTable
      title="小说书架管理"
      tableName="novels"
      columns={columns}
      fetchData={fetchData}
      onDelete={deleteItem}
    />
  )
}

export default Novels
