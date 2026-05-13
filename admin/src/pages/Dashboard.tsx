import React, { useEffect, useState } from 'react'
import { Row, Col, Card, Statistic, Spin } from 'antd'
import {
  UserOutlined,
  WalletOutlined,
  SmileOutlined,
  LineChartOutlined,
  BookOutlined,
  ReadOutlined,
} from '@ant-design/icons'
import { supabase } from '../utils/supabase'
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, PieChart, Pie, Cell } from 'recharts'

const Dashboard: React.FC = () => {
  const [loading, setLoading] = useState(true)
  const [stats, setStats] = useState({
    users: 0,
    expenses: 0,
    moodDiaries: 0,
    weightRecords: 0,
    notes: 0,
    novels: 0,
  })
  const [userTrend, setUserTrend] = useState<{ date: string; count: number }[]>([])

  useEffect(() => {
    fetchStats()
  }, [])

  const fetchStats = async () => {
    setLoading(true)
    try {
      // 并行获取所有统计数据
      const [
        { count: users },
        { count: expenses },
        { count: moodDiaries },
        { count: weightRecords },
        { count: notes },
        { count: novels },
      ] = await Promise.all([
        supabase.from('users').select('*', { count: 'exact', head: true }),
        supabase.from('expenses').select('*', { count: 'exact', head: true }),
        supabase.from('mood_diaries').select('*', { count: 'exact', head: true }),
        supabase.from('weight_records').select('*', { count: 'exact', head: true }),
        supabase.from('notes').select('*', { count: 'exact', head: true }),
        supabase.from('novels').select('*', { count: 'exact', head: true }),
      ])

      setStats({
        users: users || 0,
        expenses: expenses || 0,
        moodDiaries: moodDiaries || 0,
        weightRecords: weightRecords || 0,
        notes: notes || 0,
        novels: novels || 0,
      })

      // 获取用户注册趋势（最近7天）
      const sevenDaysAgo = new Date()
      sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7)
      
      const { data: userData } = await supabase
        .from('users')
        .select('created_at')
        .gte('created_at', sevenDaysAgo.toISOString())
        .order('created_at')

      if (userData) {
        const trendMap = new Map<string, number>()
        for (let i = 0; i < 7; i++) {
          const d = new Date()
          d.setDate(d.getDate() - i)
          trendMap.set(d.toISOString().split('T')[0], 0)
        }
        
        userData.forEach((user: any) => {
          const date = user.created_at.split('T')[0]
          trendMap.set(date, (trendMap.get(date) || 0) + 1)
        })
        
        const trend = Array.from(trendMap.entries())
          .map(([date, count]) => ({ date: date.slice(5), count }))
          .reverse()
        
        setUserTrend(trend)
      }
    } catch (error) {
      console.error('获取统计数据失败:', error)
    }
    setLoading(false)
  }

  const COLORS = ['#6C63FF', '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7']

  if (loading) {
    return (
      <div style={{ textAlign: 'center', padding: 100 }}>
        <Spin size="large" />
      </div>
    )
  }

  return (
    <div>
      <Row gutter={[16, 16]}>
        <Col xs={24} sm={12} lg={8} xl={4}>
          <Card>
            <Statistic
              title="注册用户"
              value={stats.users}
              prefix={<UserOutlined />}
              valueStyle={{ color: '#6C63FF' }}
            />
          </Card>
        </Col>
        <Col xs={24} sm={12} lg={8} xl={4}>
          <Card>
            <Statistic
              title="消费记录"
              value={stats.expenses}
              prefix={<WalletOutlined />}
              valueStyle={{ color: '#FF6B6B' }}
            />
          </Card>
        </Col>
        <Col xs={24} sm={12} lg={8} xl={4}>
          <Card>
            <Statistic
              title="心情日记"
              value={stats.moodDiaries}
              prefix={<SmileOutlined />}
              valueStyle={{ color: '#4ECDC4' }}
            />
          </Card>
        </Col>
        <Col xs={24} sm={12} lg={8} xl={4}>
          <Card>
            <Statistic
              title="体重记录"
              value={stats.weightRecords}
              prefix={<LineChartOutlined />}
              valueStyle={{ color: '#45B7D1' }}
            />
          </Card>
        </Col>
        <Col xs={24} sm={12} lg={8} xl={4}>
          <Card>
            <Statistic
              title="笔记数量"
              value={stats.notes}
              prefix={<BookOutlined />}
              valueStyle={{ color: '#96CEB4' }}
            />
          </Card>
        </Col>
        <Col xs={24} sm={12} lg={8} xl={4}>
          <Card>
            <Statistic
              title="小说书架"
              value={stats.novels}
              prefix={<ReadOutlined />}
              valueStyle={{ color: '#FFEAA7' }}
            />
          </Card>
        </Col>
      </Row>

      <Row gutter={[16, 16]} style={{ marginTop: 24 }}>
        <Col xs={24} lg={12}>
          <Card title="用户增长趋势（最近7天）">
            <ResponsiveContainer width="100%" height={300}>
              <LineChart data={userTrend}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="date" />
                <YAxis />
                <Tooltip />
                <Line type="monotone" dataKey="count" stroke="#6C63FF" strokeWidth={2} />
              </LineChart>
            </ResponsiveContainer>
          </Card>
        </Col>
        <Col xs={24} lg={12}>
          <Card title="数据分布">
            <ResponsiveContainer width="100%" height={300}>
              <PieChart>
                <Pie
                  data={[
                    { name: '消费', value: stats.expenses },
                    { name: '心情', value: stats.moodDiaries },
                    { name: '体重', value: stats.weightRecords },
                    { name: '笔记', value: stats.notes },
                    { name: '小说', value: stats.novels },
                  ]}
                  cx="50%"
                  cy="50%"
                  innerRadius={60}
                  outerRadius={100}
                  paddingAngle={5}
                  dataKey="value"
                >
                  {COLORS.map((color, index) => (
                    <Cell key={`cell-${index}`} fill={color} />
                  ))}
                </Pie>
                <Tooltip />
              </PieChart>
            </ResponsiveContainer>
          </Card>
        </Col>
      </Row>
    </div>
  )
}

export default Dashboard
