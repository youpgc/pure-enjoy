import React from 'react'
import { Tag } from 'antd'
import DataTable from '../components/DataTable'
import { supabase } from '../utils/supabase'
import dayjs from 'dayjs'

const Notes: React.FC = () => {
  const columns = [
    { title: '用户ID', dataIndex: 'user_id', key: 'user_id', width: 200 },
    { title: '标题', dataIndex: 'title', key: 'title' },
    {
      title: '内容',
      dataIndex: 'content',
      key: 'content',
      ellipsis: true,
      width: 300,
    },
    { title: '分类', dataIndex: 'category', key: 'category' },
    {
      title: '置顶',
      dataIndex: 'pinned',
      key: 'pinned',
      render: (pinned: boolean) => pinned ? <Tag color="gold">置顶</Tag> : null,
    },
    {
      title: '更新时间',
      dataIndex: 'updated_at',
      key: 'updated_at',
      render: (date: string) => dayjs(date).format('YYYY-MM-DD HH:mm'),
    },
  ]

  const fetchData = async () => {
    const { data, error } = await supabase
      .from('notes')
      .select('*')
      .order('updated_at', { ascending: false })
    if (error) throw error
    return data || []
  }

  const deleteItem = async (id: string) => {
    const { error } = await supabase.from('notes').delete().eq('id', id)
    if (error) throw error
  }

  return (
    <DataTable
      title="笔记本管理"
      tableName="notes"
      columns={columns}
      fetchData={fetchData}
      onDelete={deleteItem}
    />
  )
}

export default Notes
