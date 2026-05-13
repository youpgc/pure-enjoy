import React, { useState } from 'react'
import { Layout, Menu, theme } from 'antd'
import {
  DashboardOutlined,
  UserOutlined,
  WalletOutlined,
  SmileOutlined,
  LineChartOutlined,
  BookOutlined,
  ReadOutlined,
} from '@ant-design/icons'
import Dashboard from './pages/Dashboard'
import Users from './pages/Users'
import Expenses from './pages/Expenses'
import MoodDiaries from './pages/MoodDiaries'
import WeightRecords from './pages/WeightRecords'
import Notes from './pages/Notes'
import Novels from './pages/Novels'

const { Header, Sider, Content } = Layout

type PageKey = 'dashboard' | 'users' | 'expenses' | 'mood' | 'weight' | 'notes' | 'novels'

const App: React.FC = () => {
  const [collapsed, setCollapsed] = useState(false)
  const [currentPage, setCurrentPage] = useState<PageKey>('dashboard')
  const {
    token: { colorBgContainer },
  } = theme.useToken()

  const menuItems = [
    { key: 'dashboard', icon: <DashboardOutlined />, label: '数据概览' },
    { key: 'users', icon: <UserOutlined />, label: '用户管理' },
    { type: 'divider' },
    { key: 'expenses', icon: <WalletOutlined />, label: '消费记录' },
    { key: 'mood', icon: <SmileOutlined />, label: '心情日记' },
    { key: 'weight', icon: <LineChartOutlined />, label: '体重记录' },
    { key: 'notes', icon: <BookOutlined />, label: '笔记本' },
    { key: 'novels', icon: <ReadOutlined />, label: '小说书架' },
  ]

  const renderPage = () => {
    switch (currentPage) {
      case 'dashboard':
        return <Dashboard />
      case 'users':
        return <Users />
      case 'expenses':
        return <Expenses />
      case 'mood':
        return <MoodDiaries />
      case 'weight':
        return <WeightRecords />
      case 'notes':
        return <Notes />
      case 'novels':
        return <Novels />
      default:
        return <Dashboard />
    }
  }

  return (
    <Layout style={{ minHeight: '100vh' }}>
      <Sider
        trigger={null}
        collapsible
        collapsed={collapsed}
        theme="light"
        style={{ boxShadow: '2px 0 8px rgba(0,0,0,0.05)' }}
      >
        <div style={{ height: 64, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <h2 style={{ margin: 0, color: '#6C63FF', fontSize: collapsed ? 14 : 20 }}>
            {collapsed ? '纯' : '纯享管理'}
          </h2>
        </div>
        <Menu
          mode="inline"
          selectedKeys={[currentPage]}
          items={menuItems}
          onClick={({ key }) => setCurrentPage(key as PageKey)}
        />
      </Sider>
      <Layout>
        <Header style={{ padding: '0 24px', background: colorBgContainer, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <h1 style={{ margin: 0, fontSize: 18 }}>
            {menuItems.find(item => item.key === currentPage)?.label || '数据概览'}
          </h1>
          <span style={{ color: '#999' }}>纯享App管理后台</span>
        </Header>
        <Content style={{ margin: 24, padding: 24, background: colorBgContainer, borderRadius: 8 }}>
          {renderPage()}
        </Content>
      </Layout>
    </Layout>
  )
}

export default App
