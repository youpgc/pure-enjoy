import React from 'react'
import { Tag } from 'antd'
import DataTable from '../components/DataTable'
import { supabase } from '../utils/supabase'
import dayjs from 'dayjs'

const Users: React.FC = () => {
  const columns = [
    { title: 'ID', dataIndex: 'id', key: 'id', width: 280 },
    { title: '邮箱', dataIndex: 'email', key: 'email' },
    {
      title: '注册时间',
      dataIndex: 'created_at',
      key: 'created_at',
      render: (date: string) => dayjs(date).format('YYYY-MM-DD HH:mm'),
    },
    {
      title: '最后登录',
      dataIndex: 'last_sign_in_at',
      key: 'last_sign_in_at',
      render: (date: string | null) =>
        date ? dayjs(date).format('YYYY-MM-DD HH:mm') : <Tag color="default">从未</Tag>,
    },
  ]

  const fetchUsers = async () => {
    const { data, error } = await supabase
      .from('users')
      .select('*')
      .order('created_at', { ascending: false })
    if (error) throw error
    return data || []
  }

  const deleteUser = async (id: string) => {
    const { error } = await supabase.from('users').delete().eq('id', id)
    if (error) throw error
  }

  return (
    <DataTable
      title="用户管理"
      tableName="users"
      columns={columns}
      fetchData={fetchUsers}
      onDelete={deleteUser}
    />
  )
}

export default Users
