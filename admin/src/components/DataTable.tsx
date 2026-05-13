import React, { useState, useEffect } from 'react'
import { Table, Button, Popconfirm, message, Space } from 'antd'
import { DeleteOutlined, ReloadOutlined } from '@ant-design/icons'

interface DataTableProps {
  title: string
  tableName: string
  columns: any[]
  fetchData: () => Promise<any[]>
  onDelete: (id: string) => Promise<void>
}

const DataTable: React.FC<DataTableProps> = ({ title, tableName, columns, fetchData, onDelete }) => {
  const [data, setData] = useState<any[]>([])
  const [loading, setLoading] = useState(false)
  const [pagination, setPagination] = useState({ current: 1, pageSize: 10, total: 0 })

  const loadData = async () => {
    setLoading(true)
    try {
      const result = await fetchData()
      setData(result)
      setPagination({ ...pagination, total: result.length })
    } catch (error) {
      message.error('加载数据失败')
    }
    setLoading(false)
  }

  useEffect(() => {
    loadData()
  }, [])

  const handleDelete = async (id: string) => {
    try {
      await onDelete(id)
      message.success('删除成功')
      loadData()
    } catch (error) {
      message.error('删除失败')
    }
  }

  const actionColumn = {
    title: '操作',
    key: 'action',
    render: (_: any, record: any) => (
      <Popconfirm
        title="确认删除"
        description="删除后无法恢复，是否继续？"
        onConfirm={() => handleDelete(record.id)}
        okText="删除"
        cancelText="取消"
        okButtonProps={{ danger: true }}
      >
        <Button type="link" danger icon={<DeleteOutlined />}>
          删除
        </Button>
      </Popconfirm>
    ),
  }

  return (
    <div>
      <div style={{ marginBottom: 16, display: 'flex', justifyContent: 'space-between' }}>
        <h3>{title}</h3>
        <Button icon={<ReloadOutlined />} onClick={loadData}>
          刷新
        </Button>
      </div>
      <Table
        columns={[...columns, actionColumn]}
        dataSource={data}
        rowKey="id"
        loading={loading}
        pagination={pagination}
        onChange={(p) => setPagination({ ...pagination, current: p.current || 1 })}
        scroll={{ x: true }}
      />
    </div>
  )
}

export default DataTable
