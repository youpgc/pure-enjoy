import React from 'react'
import { Tag } from 'antd'
import DataTable from '../components/DataTable'
import { supabase } from '../utils/supabase'
import dayjs from 'dayjs'

const Expenses: React.FC = () => {
  const columns = [
    { title: '用户ID', dataIndex: 'user_id', key: 'user_id', width: 200 },
    {
      title: '金额',
      dataIndex: 'amount',
      key: 'amount',
      render: (amount: number) => <Tag color="red">¥{amount.toFixed(2)}</Tag>,
    },
    { title: '分类', dataIndex: 'category', key: 'category' },
    { title: '备注', dataIndex: 'note', key: 'note' },
    {
      title: '日期',
      dataIndex: 'date',
      key: 'date',
      render: (date: string) => dayjs(date).format('YYYY-MM-DD'),
    },
  ]

  const fetchData = async () => {
    const { data, error } = await supabase
      .from('expenses')
      .select('*')
      .order('date', { ascending: false })
    if (error) throw error
    return data || []
  }

  const deleteItem = async (id: string) => {
    const { error } = await supabase.from('expenses').delete().eq('id', id)
    if (error) throw error
  }

  return (
    <DataTable
      title="消费记录管理"
      tableName="expenses"
      columns={columns}
      fetchData={fetchData}
      onDelete={deleteItem}
    />
  )
}

export default Expenses
