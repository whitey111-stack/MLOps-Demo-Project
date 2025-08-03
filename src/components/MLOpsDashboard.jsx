import React, { useState, useEffect } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Progress } from '@/components/ui/progress';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { 
  Activity, 
  Cpu, 
  Database, 
  GitBranch, 
  Zap, 
  TrendingUp, 
  AlertTriangle,
  CheckCircle,
  Clock,
  DollarSign,
  Server,
  Users
} from 'lucide-react';
import { 
  LineChart, 
  Line, 
  AreaChart, 
  Area, 
  XAxis, 
  YAxis, 
  CartesianGrid, 
  Tooltip, 
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
  BarChart,
  Bar
} from 'recharts';

const MLOpsDashboard = () => {
  const [activeTab, setActiveTab] = useState('overview');
  const [modelStats, setModelStats] = useState({
    totalModels: 5,
    activeModels: 4,
    totalRequests: 1245678,
    avgLatency: 156,
    errorRate: 0.02,
    gpuUtilization: 78
  });

  // Mock data for charts
  const performanceData = [
    { time: '00:00', latency: 120, throughput: 450, gpuTemp: 65 },
    { time: '04:00', latency: 135, throughput: 520, gpuTemp: 68 },
    { time: '08:00', latency: 178, throughput: 680, gpuTemp: 72 },
    { time: '12:00', latency: 165, throughput: 590, gpuTemp: 70 },
    { time: '16:00', latency: 142, throughput: 720, gpuTemp: 74 },
    { time: '20:00', latency: 128, throughput: 480, gpuTemp: 66 },
  ];

  const modelDistribution = [
    { name: 'LLaMA-7B', value: 35, color: '#8884d8' },
    { name: 'LLaMA-13B', value: 25, color: '#82ca9d' },
    { name: 'Stable Diffusion', value: 20, color: '#ffc658' },
    { name: 'Code LLaMA', value: 15, color: '#ff7300' },
    { name: 'Other', value: 5, color: '#0088fe' },
  ];

  const deploymentHistory = [
    { date: '2024-01-01', successful: 12, failed: 1, rollbacks: 0 },
    { date: '2024-01-15', successful: 18, failed: 2, rollbacks: 1 },
    { date: '2024-02-01', successful: 22, failed: 1, rollbacks: 0 },
    { date: '2024-02-15', successful: 15, failed: 3, rollbacks: 2 },
    { date: '2024-03-01', successful: 28, failed: 1, rollbacks: 0 },
  ];

  const alerts = [
    { id: 1, type: 'warning', title: 'High GPU Memory Usage', description: 'GPU memory at 89% on node gpu-worker-3', time: '5 min ago' },
    { id: 2, type: 'info', title: 'Model Deployment Complete', description: 'LLaMA-13B successfully deployed to production', time: '1 hour ago' },
    { id: 3, type: 'error', title: 'Service Degradation', description: 'Stable Diffusion service experiencing high latency', time: '2 hours ago' },
  ];

  const models = [
    { name: 'LLaMA-7B', status: 'healthy', replicas: '3/3', latency: '142ms', requests: '12.5k/min', gpuUsage: '67%' },
    { name: 'LLaMA-13B', status: 'healthy', replicas: '2/2', latency: '198ms', requests: '8.2k/min', gpuUsage: '84%' },
    { name: 'Stable Diffusion XL', status: 'warning', replicas: '2/3', latency: '2.1s', requests: '1.8k/min', gpuUsage: '92%' },
    { name: 'Code LLaMA', status: 'healthy', replicas: '1/1', latency: '156ms', requests: '3.4k/min', gpuUsage: '45%' },
  ];

  const infrastructureNodes = [
    { name: 'gpu-worker-1', type: 'H100', status: 'healthy', cpu: '45%', memory: '67%', gpu: '78%' },
    { name: 'gpu-worker-2', type: 'H100', status: 'healthy', cpu: '52%', memory: '71%', gpu: '82%' },
    { name: 'gpu-worker-3', type: 'H100', status: 'warning', cpu: '78%', memory: '89%', gpu: '94%' },
    { name: 'cpu-worker-1', type: 'CPU', status: 'healthy', cpu: '34%', memory: '45%', gpu: 'N/A' },
  ];

  const getStatusIcon = (status) => {
    switch (status) {
      case 'healthy':
        return <CheckCircle className="h-4 w-4 text-green-500" />;
      case 'warning':
        return <AlertTriangle className="h-4 w-4 text-yellow-500" />;
      case 'error':
        return <AlertTriangle className="h-4 w-4 text-red-500" />;
      default:
        return <Clock className="h-4 w-4 text-gray-500" />;
    }
  };

  const getStatusBadge = (status) => {
    const variants = {
      healthy: 'default',
      warning: 'secondary',
      error: 'destructive'
    };
    return <Badge variant={variants[status] || 'outline'}>{status}</Badge>;
  };

  return (
    <div className="min-h-screen bg-gray-50 p-6">
      <div className="max-w-7xl mx-auto">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-gray-900 mb-2">MLOps Dashboard</h1>
          <p className="text-gray-600">AI Model Deployment & Infrastructure Monitoring</p>
        </div>

        {/* Quick Stats */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Active Models</CardTitle>
              <Server className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{modelStats.activeModels}/{modelStats.totalModels}</div>
              <p className="text-xs text-muted-foreground">80% uptime this month</p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Avg Latency</CardTitle>
              <Zap className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{modelStats.avgLatency}ms</div>
              <p className="text-xs text-muted-foreground">-12% from last week</p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">GPU Utilization</CardTitle>
              <Cpu className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{modelStats.gpuUtilization}%</div>
              <Progress value={modelStats.gpuUtilization} className="mt-2" />
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Cost/Hour</CardTitle>
              <DollarSign className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">$32.77</div>
              <p className="text-xs text-muted-foreground">H100 GPU instances</p>
            </CardContent>
          </Card>
        </div>

        <Tabs value={activeTab} onValueChange={setActiveTab} className="space-y-6">
          <TabsList className="grid w-full grid-cols-5">
            <TabsTrigger value="overview">Overview</TabsTrigger>
            <TabsTrigger value="models">Models</TabsTrigger>
            <TabsTrigger value="performance">Performance</TabsTrigger>
            <TabsTrigger value="deployments">Deployments</TabsTrigger>
            <TabsTrigger value="infrastructure">Infrastructure</TabsTrigger>
          </TabsList>

          <TabsContent value="overview" className="space-y-6">
            {/* Alerts */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <AlertTriangle className="h-5 w-5" />
                  Recent Alerts
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-3">
                {alerts.map((alert) => (
                  <Alert key={alert.id} variant={alert.type === 'error' ? 'destructive' : 'default'}>
                    <AlertTitle className="text-sm">{alert.title}</AlertTitle>
                    <AlertDescription className="text-xs">
                      {alert.description} • {alert.time}
                    </AlertDescription>
                  </Alert>
                ))}
              </CardContent>
            </Card>

            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              {/* Performance Overview */}
              <Card>
                <CardHeader>
                  <CardTitle>Performance Metrics</CardTitle>
                  <CardDescription>24-hour performance overview</CardDescription>
                </CardHeader>
                <CardContent>
                  <ResponsiveContainer width="100%" height={300}>
                    <LineChart data={performanceData}>
                      <CartesianGrid strokeDasharray="3 3" />
                      <XAxis dataKey="time" />
                      <YAxis />
                      <Tooltip />
                      <Line type="monotone" dataKey="latency" stroke="#8884d8" name="Latency (ms)" />
                      <Line type="monotone" dataKey="throughput" stroke="#82ca9d" name="Throughput (req/min)" />
                    </LineChart>
                  </ResponsiveContainer>
                </CardContent>
              </Card>

              {/* Model Distribution */}
              <Card>
                <CardHeader>
                  <CardTitle>Model Usage Distribution</CardTitle>
                  <CardDescription>Request distribution by model type</CardDescription>
                </CardHeader>
                <CardContent>
                  <ResponsiveContainer width="100%" height={300}>
                    <PieChart>
                      <Pie
                        data={modelDistribution}
                        cx="50%"
                        cy="50%"
                        outerRadius={80}
                        dataKey="value"
                        label={({ name, value }) => `${name}: ${value}%`}
                      >
                        {modelDistribution.map((entry, index) => (
                          <Cell key={`cell-${index}`} fill={entry.color} />
                        ))}
                      </Pie>
                      <Tooltip />
                    </PieChart>
                  </ResponsiveContainer>
                </CardContent>
              </Card>
            </div>
          </TabsContent>

          <TabsContent value="models" className="space-y-6">
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center justify-between">
                  <span className="flex items-center gap-2">
                    <Database className="h-5 w-5" />
                    Deployed Models
                  </span>
                  <Button size="sm">Deploy New Model</Button>
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  {models.map((model, index) => (
                    <div key={index} className="flex items-center justify-between p-4 border rounded-lg">
                      <div className="flex items-center gap-4">
                        {getStatusIcon(model.status)}
                        <div>
                          <h3 className="font-semibold">{model.name}</h3>
                          <div className="flex items-center gap-4 text-sm text-gray-600 mt-1">
                            <span>Replicas: {model.replicas}</span>
                            <span>Latency: {model.latency}</span>
                            <span>Requests: {model.requests}</span>
                          </div>
                        </div>
                      </div>
                      <div className="flex items-center gap-3">
                        <div className="text-right">
                          <div className="text-sm font-medium">GPU: {model.gpuUsage}</div>
                          {getStatusBadge(model.status)}
                        </div>
                        <Button variant="outline" size="sm">Manage</Button>
                      </div>
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>
          </TabsContent>

          <TabsContent value="performance" className="space-y-6">
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              <Card>
                <CardHeader>
                  <CardTitle>GPU Temperature</CardTitle>
                  <CardDescription>Temperature monitoring across GPU cluster</CardDescription>
                </CardHeader>
                <CardContent>
                  <ResponsiveContainer width="100%" height={300}>
                    <AreaChart data={performanceData}>
                      <CartesianGrid strokeDasharray="3 3" />
                      <XAxis dataKey="time" />
                      <YAxis />
                      <Tooltip />
                      <Area type="monotone" dataKey="gpuTemp" stroke="#ff7300" fill="#ff7300" fillOpacity={0.6} />
                    </AreaChart>
                  </ResponsiveContainer>
                </CardContent>
              </Card>

              <Card>
                <CardHeader>
                  <CardTitle>Throughput vs Latency</CardTitle>
                  <CardDescription>Performance correlation analysis</CardDescription>
                </CardHeader>
                <CardContent>
                  <ResponsiveContainer width="100%" height={300}>
                    <BarChart data={performanceData}>
                      <CartesianGrid strokeDasharray="3 3" />
                      <XAxis dataKey="time" />
                      <YAxis />
                      <Tooltip />
                      <Bar dataKey="throughput" fill="#8884d8" />
                    </BarChart>
                  </ResponsiveContainer>
                </CardContent>
              </Card>
            </div>
          </TabsContent>

          <TabsContent value="deployments" className="space-y-6">
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <GitBranch className="h-5 w-5" />
                  Deployment History
                </CardTitle>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={400}>
                  <BarChart data={deploymentHistory}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="date" />
                    <YAxis />
                    <Tooltip />
                    <Bar dataKey="successful" stackId="a" fill="#82ca9d" name="Successful" />
                    <Bar dataKey="failed" stackId="a" fill="#ff7300" name="Failed" />
                    <Bar dataKey="rollbacks" stackId="a" fill="#ff0000" name="Rollbacks" />
                  </BarChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>
          </TabsContent>

          <TabsContent value="infrastructure" className="space-y-6">
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <Server className="h-5 w-5" />
                  Cluster Nodes
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  {infrastructureNodes.map((node, index) => (
                    <div key={index} className="flex items-center justify-between p-4 border rounded-lg">
                      <div className="flex items-center gap-4">
                        {getStatusIcon(node.status)}
                        <div>
                          <h3 className="font-semibold">{node.name}</h3>
                          <p className="text-sm text-gray-600">{node.type} Node</p>
                        </div>
                      </div>
                      <div className="flex items-center gap-6">
                        <div className="text-right">
                          <p className="text-sm">CPU: {node.cpu}</p>
                          <Progress value={parseInt(node.cpu)} className="w-20 h-2" />
                        </div>
                        <div className="text-right">
                          <p className="text-sm">Memory: {node.memory}</p>
                          <Progress value={parseInt(node.memory)} className="w-20 h-2" />
                        </div>
                        {node.gpu !== 'N/A' && (
                          <div className="text-right">
                            <p className="text-sm">GPU: {node.gpu}</p>
                            <Progress value={parseInt(node.gpu)} className="w-20 h-2" />
                          </div>
                        )}
                        {getStatusBadge(node.status)}
                      </div>
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>
          </TabsContent>
        </Tabs>
      </div>
    </div>
  );
};

export default MLOpsDashboard;