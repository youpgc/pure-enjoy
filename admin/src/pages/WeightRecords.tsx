import React from 'react'
import { Tag } from 'antd'
import DataTable from '../components/DataTable'
import { supabase } from '../utils/supabase'
import dayjs from 'dayjs'

const WeightRecords: React.FC = () => {
  const columns = [
    { title: '用户ID', dataIndex: 'user_id', key: 'user_id', width: 200 },
    {
      title: '体重',
      dataIndex: 'weight',
      key: 'weight',
      render: (weight: number) => <Tag color="blue">{weight} kg</Tag>,
    },
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
      .from('weight_records')
      .select('*')
      .order('date', { ascending: false })
    if (error) throw error
    return data || []
  }

  const deleteItem = async (id: string) => {
    const { error } = await supabase.from('weight_records').delete().eq('id', id)
    if (error) throw error
  }

  return (
    <DataTable
      title="体重记录管理"
      tableName="weight_records"
      columns={columns}
      fetchData={fetchData}
      onDelete={deleteItem}
    />
  )
}

export default WeightRecords
