import React, { useState, useEffect, useCallback } from 'react';
import {
  Card,
  Table,
  Button,
  Space,
  Tag,
  Modal,
  Form,
  Input,
  Switch,
  Upload,
  message,
  Popconfirm,
  Typography,
  Tooltip,
  Badge,
  Descriptions,
  QRCode,
  Statistic,
  Row,
  Col,
  Divider,
  Alert,
  Progress,
} from 'antd';
import {
  UploadOutlined,
  DownloadOutlined,
  DeleteOutlined,
  EditOutlined,
  PlusOutlined,
  QrcodeOutlined,
  CopyOutlined,
  CheckCircleOutlined,
  CloseCircleOutlined,
  SyncOutlined,
  HistoryOutlined,
  FileOutlined,
} from '@ant-design/icons';
import type { UploadFile, UploadProps } from 'antd/es/upload';
import { supabase } from '../utils/supabase';
import dayjs from 'dayjs';

const { Title, Text, Paragraph } = Typography;
const { TextArea } = Input;

// 版本信息接口
interface AppVersion {
  id: string;
  version: string;
  build_number: number;
  download_url: string;
  file_size: number;
  checksum: string;
  release_notes: string;
  is_force_update: boolean;
  is_active: boolean;
  platform: 'android' | 'ios';
  file_name: string;
  created_by: string;
  created_at: string;
  updated_at: string;
  download_count?: number;
}

// 构建状态接口
interface BuildStatus {
  id: string;
  version: string;
  build_number: number;
  status: 'pending' | 'building' | 'success' | 'failed';
  started_at: string;
  completed_at?: string;
  logs?: string;
  error_message?: string;
}

const VersionManagement: React.FC = () => {
  // 状态
  const [versions, setVersions] = useState<AppVersion[]>([]);
  const [buildStatuses, setBuildStatuses] = useState<BuildStatus[]>([]);
  const [loading, setLoading] = useState(false);
  const [modalVisible, setModalVisible] = useState(false);
  const [qrModalVisible, setQrModalVisible] = useState(false);
  const [detailModalVisible, setDetailModalVisible] = useState(false);
  const [uploadModalVisible, setUploadModalVisible] = useState(false);
  const [selectedVersion, setSelectedVersion] = useState<AppVersion | null>(null);
  const [selectedBuild, setSelectedBuild] = useState<BuildStatus | null>(null);
  const [form] = Form.useForm();
  const [uploadForm] = Form.useForm();
  const [fileList, setFileList] = useState<UploadFile[]>([]);
  const [uploading, setUploading] = useState(false);
  const [activeTab, setActiveTab] = useState<'versions' | 'builds'>('versions');

  // 获取版本列表
  const fetchVersions = useCallback(async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('app_versions')
        .select('*')
        .order('build_number', { ascending: false });

      if (error) throw error;
      setVersions(data || []);
    } catch (error: any) {
      message.error('获取版本列表失败: ' + error.message);
    } finally {
      setLoading(false);
    }
  }, []);

  // 获取构建状态列表
  const fetchBuildStatuses = useCallback(async () => {
    try {
      const { data, error } = await supabase
        .from('build_statuses')
        .select('*')
        .order('started_at', { ascending: false })
        .limit(20);

      if (error) throw error;
      setBuildStatuses(data || []);
    } catch (error: any) {
      console.error('获取构建状态失败:', error);
    }
  }, []);

  // 初始加载
  useEffect(() => {
    fetchVersions();
    fetchBuildStatuses();

    // 订阅实时更新
    const versionSubscription = supabase
      .channel('app_versions_changes')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'app_versions' },
        () => fetchVersions()
      )
      .subscribe();

    const buildSubscription = supabase
      .channel('build_statuses_changes')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'build_statuses' },
        () => fetchBuildStatuses()
      )
      .subscribe();

    return () => {
      versionSubscription.unsubscribe();
      buildSubscription.unsubscribe();
    };
  }, [fetchVersions, fetchBuildStatuses]);

  // 创建/编辑版本
  const handleSaveVersion = async (values: any) => {
    try {
      const versionData = {
        ...values,
        updated_at: new Date().toISOString(),
      };

      if (selectedVersion) {
        // 更新
        const { error } = await supabase
          .from('app_versions')
          .update(versionData)
          .eq('id', selectedVersion.id);

        if (error) throw error;
        message.success('版本更新成功');
      } else {
        // 创建
        const { error } = await supabase
          .from('app_versions')
          .insert([{ ...versionData, created_at: new Date().toISOString() }]);

        if (error) throw error;
        message.success('版本创建成功');
      }

      setModalVisible(false);
      form.resetFields();
      fetchVersions();
    } catch (error: any) {
      message.error('保存失败: ' + error.message);
    }
  };

  // 删除版本
  const handleDeleteVersion = async (id: string) => {
    try {
      const { error } = await supabase
        .from('app_versions')
        .delete()
        .eq('id', id);

      if (error) throw error;
      message.success('版本删除成功');
      fetchVersions();
    } catch (error: any) {
      message.error('删除失败: ' + error.message);
    }
  };

  // 切换版本激活状态
  const handleToggleActive = async (version: AppVersion) => {
    try {
      const { error } = await supabase
        .from('app_versions')
        .update({ is_active: !version.is_active })
        .eq('id', version.id);

      if (error) throw error;
      message.success('状态更新成功');
      fetchVersions();
    } catch (error: any) {
      message.error('更新失败: ' + error.message);
    }
  };

  // 手动上传 APK
  const handleUploadAPK = async (values: any) => {
    if (fileList.length === 0) {
      message.error('请选择 APK 文件');
      return;
    }

    setUploading(true);
    try {
      const file = fileList[0].originFileObj;
      if (!file) {
        message.error('文件对象不存在');
        return;
      }

      const version = values.version;
      const buildNumber = values.build_number;
      const fileName = `pure-enjoy-v${version}+${buildNumber}.apk`;

      // 上传文件到 Supabase Storage
      const { data: uploadData, error: uploadError } = await supabase.storage
        .from('apk-releases')
        .upload(fileName, file, {
          cacheControl: '3600',
          upsert: true,
        });

      if (uploadError) throw uploadError;

      // 获取公开 URL
      const { data: urlData } = supabase.storage
        .from('apk-releases')
        .getPublicUrl(fileName);

      // 创建版本记录
      const { error: insertError } = await supabase.from('app_versions').insert([
        {
          version: version,
          build_number: buildNumber,
          download_url: urlData.publicUrl,
          file_size: file.size,
          checksum: '', // 可以添加 SHA256 计算
          release_notes: values.release_notes || '',
          is_force_update: values.is_force_update || false,
          is_active: true,
          platform: 'android',
          file_name: fileName,
          created_by: 'admin-manual',
        },
      ]);

      if (insertError) throw insertError;

      message.success('APK 上传成功');
      setUploadModalVisible(false);
      uploadForm.resetFields();
      setFileList([]);
      fetchVersions();
    } catch (error: any) {
      message.error('上传失败: ' + error.message);
    } finally {
      setUploading(false);
    }
  };

  // 复制下载链接
  const handleCopyLink = (url: string) => {
    navigator.clipboard.writeText(url);
    message.success('下载链接已复制');
  };

  // 显示二维码
  const handleShowQRCode = (version: AppVersion) => {
    setSelectedVersion(version);
    setQrModalVisible(true);
  };

  // 显示详情
  const handleShowDetail = (version: AppVersion) => {
    setSelectedVersion(version);
    setDetailModalVisible(true);
  };

  // 显示构建日志
  const handleShowBuildLogs = (build: BuildStatus) => {
    setSelectedBuild(build);
    Modal.info({
      title: `构建日志 - ${build.version}+${build.build_number}`,
      width: 800,
      content: (
        <div
          style={{
            background: '#1e1e1e',
            color: '#d4d4d4',
            padding: 16,
            borderRadius: 4,
            maxHeight: 400,
            overflow: 'auto',
            fontFamily: 'monospace',
            fontSize: 12,
            whiteSpace: 'pre-wrap',
          }}
        >
          {build.logs || '暂无日志'}
          {build.error_message && (
            <div style={{ color: '#f48771', marginTop: 16 }}>
              错误: {build.error_message}
            </div>
          )}
        </div>
      ),
    });
  };

  // 上传配置
  const uploadProps: UploadProps = {
    onRemove: () => {
      setFileList([]);
    },
    beforeUpload: (file) => {
      if (!file.name.endsWith('.apk')) {
        message.error('只能上传 APK 文件');
        return Upload.LIST_IGNORE;
      }
      setFileList([file as UploadFile]);
      return false;
    },
    fileList,
    maxCount: 1,
    accept: '.apk',
  };

  // 格式化文件大小
  const formatFileSize = (bytes: number) => {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  };

  // 获取构建状态标签
  const getBuildStatusTag = (status: string) => {
    switch (status) {
      case 'pending':
        return <Tag icon={<SyncOutlined spin />}>等待中</Tag>;
      case 'building':
        return <Tag color="processing" icon={<SyncOutlined spin />}>构建中</Tag>;
      case 'success':
        return <Tag color="success" icon={<CheckCircleOutlined />}>成功</Tag>;
      case 'failed':
        return <Tag color="error" icon={<CloseCircleOutlined />}>失败</Tag>;
      default:
        return <Tag>未知</Tag>;
    }
  };

  // 版本列表列定义
  const versionColumns = [
    {
      title: '版本号',
      dataIndex: 'version',
      key: 'version',
      render: (version: string, record: AppVersion) => (
        <Space>
          <Text strong>{version}</Text>
          <Text type="secondary">({record.build_number})</Text>
          {record.is_active && <Badge status="success" />}
        </Space>
      ),
    },
    {
      title: '平台',
      dataIndex: 'platform',
      key: 'platform',
      render: (platform: string) => (
        <Tag color={platform === 'android' ? 'green' : 'blue'}>
          {platform === 'android' ? 'Android' : 'iOS'}
        </Tag>
      ),
    },
    {
      title: '文件信息',
      key: 'file_info',
      render: (_: any, record: AppVersion) => (
        <Space direction="vertical" size={0}>
          <Text type="secondary">{formatFileSize(record.file_size)}</Text>
          <Text type="secondary" copyable={{ text: record.checksum }}>
            {record.checksum?.slice(0, 8)}...
          </Text>
        </Space>
      ),
    },
    {
      title: '强制更新',
      dataIndex: 'is_force_update',
      key: 'is_force_update',
      render: (isForce: boolean) =>
        isForce ? <Tag color="red">是</Tag> : <Tag>否</Tag>,
    },
    {
      title: '状态',
      dataIndex: 'is_active',
      key: 'is_active',
      render: (isActive: boolean, record: AppVersion) => (
        <Switch
          checked={isActive}
          onChange={() => handleToggleActive(record)}
          checkedChildren="启用"
          unCheckedChildren="禁用"
        />
      ),
    },
    {
      title: '创建时间',
      dataIndex: 'created_at',
      key: 'created_at',
      render: (date: string) => dayjs(date).format('YYYY-MM-DD HH:mm'),
    },
    {
      title: '操作',
      key: 'action',
      render: (_: any, record: AppVersion) => (
        <Space>
          <Tooltip title="查看详情">
            <Button
              icon={<FileOutlined />}
              size="small"
              onClick={() => handleShowDetail(record)}
            />
          </Tooltip>
          <Tooltip title="下载二维码">
            <Button
              icon={<QrcodeOutlined />}
              size="small"
              onClick={() => handleShowQRCode(record)}
            />
          </Tooltip>
          <Tooltip title="复制下载链接">
            <Button
              icon={<CopyOutlined />}
              size="small"
              onClick={() => handleCopyLink(record.download_url)}
            />
          </Tooltip>
          <Tooltip title="编辑">
            <Button
              icon={<EditOutlined />}
              size="small"
              onClick={() => {
                setSelectedVersion(record);
                form.setFieldsValue(record);
                setModalVisible(true);
              }}
            />
          </Tooltip>
          <Popconfirm
            title="确定删除此版本?"
            onConfirm={() => handleDeleteVersion(record.id)}
            okText="确定"
            cancelText="取消"
          >
            <Button icon={<DeleteOutlined />} size="small" danger />
          </Popconfirm>
        </Space>
      ),
    },
  ];

  // 构建状态列定义
  const buildColumns = [
    {
      title: '版本',
      key: 'version',
      render: (_: any, record: BuildStatus) => (
        <Text strong>
          {record.version} ({record.build_number})
        </Text>
      ),
    },
    {
      title: '状态',
      dataIndex: 'status',
      key: 'status',
      render: (status: string) => getBuildStatusTag(status),
    },
    {
      title: '开始时间',
      dataIndex: 'started_at',
      key: 'started_at',
      render: (date: string) => dayjs(date).format('YYYY-MM-DD HH:mm:ss'),
    },
    {
      title: '耗时',
      key: 'duration',
      render: (_: any, record: BuildStatus) => {
        if (!record.completed_at) return '-';
        const duration = dayjs(record.completed_at).diff(
          dayjs(record.started_at),
          'second'
        );
        return `${Math.floor(duration / 60)}分 ${duration % 60}秒`;
      },
    },
    {
      title: '操作',
      key: 'action',
      render: (_: any, record: BuildStatus) => (
        <Button size="small" onClick={() => handleShowBuildLogs(record)}>
          查看日志
        </Button>
      ),
    },
  ];

  return (
    <div style={{ padding: 24 }}>
      <Title level={2}>版本管理</Title>

      {/* 统计卡片 */}
      <Row gutter={16} style={{ marginBottom: 24 }}>
        <Col span={6}>
          <Card>
            <Statistic
              title="总版本数"
              value={versions.length}
              prefix={<HistoryOutlined />}
            />
          </Card>
        </Col>
        <Col span={6}>
          <Card>
            <Statistic
              title="活跃版本"
              value={versions.filter((v) => v.is_active).length}
              valueStyle={{ color: '#3f8600' }}
              prefix={<CheckCircleOutlined />}
            />
          </Card>
        </Col>
        <Col span={6}>
          <Card>
            <Statistic
              title="最新版本"
              value={versions[0]?.version || '-'}
              prefix={<TagOutlined />}
            />
          </Card>
        </Col>
        <Col span={6}>
          <Card>
            <Statistic
              title="待处理构建"
              value={
                buildStatuses.filter(
                  (b) => b.status === 'pending' || b.status === 'building'
                ).length
              }
              valueStyle={{ color: '#1890ff' }}
              prefix={<SyncOutlined spin />}
            />
          </Card>
        </Col>
      </Row>

      {/* 操作按钮 */}
      <Card style={{ marginBottom: 24 }}>
        <Space>
          <Button
            type="primary"
            icon={<PlusOutlined />}
            onClick={() => {
              setSelectedVersion(null);
              form.resetFields();
              setModalVisible(true);
            }}
          >
            手动添加版本
          </Button>
          <Button
            icon={<UploadOutlined />}
            onClick={() => {
              setUploadModalVisible(true);
              uploadForm.resetFields();
              setFileList([]);
            }}
          >
            上传 APK
          </Button>
          <Button icon={<SyncOutlined />} onClick={fetchVersions}>
            刷新
          </Button>
        </Space>
      </Card>

      {/* 版本列表 */}
      <Card
        tabList={[
          { key: 'versions', tab: '版本列表' },
          { key: 'builds', tab: '构建状态' },
        ]}
        activeTabKey={activeTab}
        onTabChange={(key) => setActiveTab(key as 'versions' | 'builds')}
      >
        {activeTab === 'versions' ? (
          <Table
            columns={versionColumns}
            dataSource={versions}
            rowKey="id"
            loading={loading}
            pagination={{ pageSize: 10 }}
          />
        ) : (
          <Table
            columns={buildColumns}
            dataSource={buildStatuses}
            rowKey="id"
            loading={loading}
            pagination={{ pageSize: 10 }}
          />
        )}
      </Card>

      {/* 编辑/创建版本模态框 */}
      <Modal
        title={selectedVersion ? '编辑版本' : '添加版本'}
        open={modalVisible}
        onOk={() => form.submit()}
        onCancel={() => {
          setModalVisible(false);
          form.resetFields();
        }}
        width={600}
      >
        <Form
          form={form}
          layout="vertical"
          onFinish={handleSaveVersion}
          initialValues={{ platform: 'android', is_active: true }}
        >
          <Form.Item
            name="version"
            label="版本号"
            rules={[{ required: true, message: '请输入版本号' }]}
          >
            <Input placeholder="如: 1.0.0" />
          </Form.Item>

          <Form.Item
            name="build_number"
            label="构建号"
            rules={[{ required: true, message: '请输入构建号' }]}
          >
            <Input type="number" placeholder="如: 1" />
          </Form.Item>

          <Form.Item
            name="download_url"
            label="下载链接"
            rules={[{ required: true, message: '请输入下载链接' }]}
          >
            <Input placeholder="https://..." />
          </Form.Item>

          <Form.Item
            name="platform"
            label="平台"
            rules={[{ required: true }]}
          >
            <Input.Group compact>
              <Button type="primary">Android</Button>
            </Input.Group>
          </Form.Item>

          <Form.Item name="release_notes" label="更新说明">
            <TextArea rows={4} placeholder="输入更新说明..." />
          </Form.Item>

          <Form.Item name="is_force_update" valuePropName="checked">
            <Switch checkedChildren="强制更新" unCheckedChildren="非强制" />
          </Form.Item>

          <Form.Item name="is_active" valuePropName="checked">
            <Switch checkedChildren="启用" unCheckedChildren="禁用" />
          </Form.Item>
        </Form>
      </Modal>

      {/* 上传 APK 模态框 */}
      <Modal
        title="上传 APK"
        open={uploadModalVisible}
        onOk={() => uploadForm.submit()}
        onCancel={() => {
          setUploadModalVisible(false);
          uploadForm.resetFields();
          setFileList([]);
        }}
        confirmLoading={uploading}
        width={600}
      >
        <Form
          form={uploadForm}
          layout="vertical"
          onFinish={handleUploadAPK}
          initialValues={{ is_force_update: false }}
        >
          <Form.Item
            name="version"
            label="版本号"
            rules={[{ required: true, message: '请输入版本号' }]}
          >
            <Input placeholder="如: 1.0.0" />
          </Form.Item>

          <Form.Item
            name="build_number"
            label="构建号"
            rules={[{ required: true, message: '请输入构建号' }]}
          >
            <Input type="number" placeholder="如: 1" />
          </Form.Item>

          <Form.Item label="APK 文件" required>
            <Upload {...uploadProps}>
              <Button icon={<UploadOutlined />}>选择 APK 文件</Button>
            </Upload>
            {fileList.length > 0 && (
              <Text type="secondary" style={{ marginTop: 8, display: 'block' }}>
                已选择: {fileList[0].name} (
                {formatFileSize(fileList[0].size || 0)})
              </Text>
            )}
          </Form.Item>

          <Form.Item name="release_notes" label="更新说明">
            <TextArea rows={4} placeholder="输入更新说明..." />
          </Form.Item>

          <Form.Item name="is_force_update" valuePropName="checked">
            <Switch checkedChildren="强制更新" unCheckedChildren="非强制" />
          </Form.Item>
        </Form>
      </Modal>

      {/* 二维码模态框 */}
      <Modal
        title="下载二维码"
        open={qrModalVisible}
        onCancel={() => setQrModalVisible(false)}
        footer={[
          <Button key="close" onClick={() => setQrModalVisible(false)}>
            关闭
          </Button>,
          <Button
            key="copy"
            type="primary"
            icon={<CopyOutlined />}
            onClick={() =>
              selectedVersion && handleCopyLink(selectedVersion.download_url)
            }
          >
            复制链接
          </Button>,
        ]}
        centered
      >
        {selectedVersion && (
          <div style={{ textAlign: 'center', padding: 24 }}>
            <QRCode
              value={selectedVersion.download_url}
              size={200}
              style={{ marginBottom: 16 }}
            />
            <Paragraph>
              <Text strong>
                {selectedVersion.version} ({selectedVersion.build_number})
              </Text>
            </Paragraph>
            <Paragraph type="secondary" copyable>
              {selectedVersion.download_url}
            </Paragraph>
          </div>
        )}
      </Modal>

      {/* 详情模态框 */}
      <Modal
        title="版本详情"
        open={detailModalVisible}
        onCancel={() => setDetailModalVisible(false)}
        footer={[
          <Button key="close" onClick={() => setDetailModalVisible(false)}>
            关闭
          </Button>,
        ]}
        width={700}
      >
        {selectedVersion && (
          <Descriptions bordered column={2}>
            <Descriptions.Item label="版本号">
              {selectedVersion.version}
            </Descriptions.Item>
            <Descriptions.Item label="构建号">
              {selectedVersion.build_number}
            </Descriptions.Item>
            <Descriptions.Item label="平台">
              <Tag
                color={selectedVersion.platform === 'android' ? 'green' : 'blue'}
              >
                {selectedVersion.platform === 'android' ? 'Android' : 'iOS'}
              </Tag>
            </Descriptions.Item>
            <Descriptions.Item label="状态">
              {selectedVersion.is_active ? (
                <Tag color="success">启用</Tag>
              ) : (
                <Tag>禁用</Tag>
              )}
            </Descriptions.Item>
            <Descriptions.Item label="强制更新">
              {selectedVersion.is_force_update ? (
                <Tag color="red">是</Tag>
              ) : (
                <Tag>否</Tag>
              )}
            </Descriptions.Item>
            <Descriptions.Item label="文件大小">
              {formatFileSize(selectedVersion.file_size)}
            </Descriptions.Item>
            <Descriptions.Item label="文件名" span={2}>
              {selectedVersion.file_name}
            </Descriptions.Item>
            <Descriptions.Item label="下载链接" span={2}>
              <Text copyable>{selectedVersion.download_url}</Text>
            </Descriptions.Item>
            <Descriptions.Item label="SHA256 校验" span={2}>
              <Text copyable>{selectedVersion.checksum}</Text>
            </Descriptions.Item>
            <Descriptions.Item label="创建者">
              {selectedVersion.created_by}
            </Descriptions.Item>
            <Descriptions.Item label="创建时间">
              {dayjs(selectedVersion.created_at).format('YYYY-MM-DD HH:mm:ss')}
            </Descriptions.Item>
            <Descriptions.Item label="更新时间">
              {dayjs(selectedVersion.updated_at).format('YYYY-MM-DD HH:mm:ss')}
            </Descriptions.Item>
            <Descriptions.Item label="更新说明" span={2}>
              <div
                style={{
                  whiteSpace: 'pre-wrap',
                  background: '#f5f5f5',
                  padding: 12,
                  borderRadius: 4,
                }}
              >
                {selectedVersion.release_notes || '无'}
              </div>
            </Descriptions.Item>
          </Descriptions>
        )}
      </Modal>
    </div>
  );
};

// 添加缺失的导入
import { TagOutlined } from '@ant-design/icons';

export default VersionManagement;
