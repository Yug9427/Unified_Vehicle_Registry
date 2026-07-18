import { useEffect, useState } from 'react'
import { getDashboardStats } from '../lib/api'
import { 
  Car, Users, Receipt, ShieldCheck, TrendingUp, AlertCircle 
} from 'lucide-react'
import { 
  PieChart, Pie, Cell, Tooltip as RechartsTooltip, ResponsiveContainer, 
  AreaChart, Area, XAxis, YAxis, CartesianGrid
} from 'recharts'
import { motion } from 'framer-motion'

export default function Dashboard() {
  const [data, setData] = useState<any>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    getDashboardStats()
      .then(res => {
        setData(res)
        setLoading(false)
      })
      .catch(err => {
        console.error("Dashboard error:", err)
        setError(err.message)
        setLoading(false)
      })
  }, [])

  if (loading) {
    return (
      <div className="flex h-[60vh] items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-indigo-500"></div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="bg-red-50 dark:bg-red-900/20 text-red-600 dark:text-red-400 p-4 rounded-xl border border-red-200 dark:border-red-800">
        <div className="flex items-center gap-2 font-bold mb-2"><AlertCircle /> Error loading dashboard</div>
        <p>{error}</p>
      </div>
    )
  }

  const { stats, fuel_distribution } = data
  const COLORS = ['#4f46e5', '#0ea5e9', '#10b981', '#f59e0b', '#8b5cf6']

  // Mock trend data since backend only provides static stats in dashboard
  const trendData = [
    { name: 'Jan', value: 4000 },
    { name: 'Feb', value: 3000 },
    { name: 'Mar', value: 2000 },
    { name: 'Apr', value: 2780 },
    { name: 'May', value: 1890 },
    { name: 'Jun', value: 2390 },
    { name: 'Jul', value: 3490 },
  ]

  return (
    <div className="space-y-6 animate-in fade-in duration-500">
      <div className="flex items-center justify-between">
        <h1 className="text-3xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-slate-900 to-slate-500 dark:from-white dark:to-slate-400">
          Overview
        </h1>
        <div className="text-sm text-slate-500 dark:text-slate-400 bg-white dark:bg-slate-800 px-4 py-2 rounded-full border border-slate-200 dark:border-slate-700 shadow-sm">
          Last updated: Just now
        </div>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <StatCard 
          title="Total Vehicles" 
          value={stats?.total_vehicles || 0} 
          icon={<Car size={24} className="text-blue-500" />}
          gradient="from-blue-500/20 to-blue-500/5"
          trend="+12% this month"
        />
        <StatCard 
          title="Registered Owners" 
          value={stats?.total_users || 0} 
          icon={<Users size={24} className="text-indigo-500" />}
          gradient="from-indigo-500/20 to-indigo-500/5"
          trend="+5% this month"
        />
        <StatCard 
          title="Unpaid Challans" 
          value={`₹${(stats?.unpaid_challans_amount || 0).toLocaleString()}`} 
          icon={<Receipt size={24} className="text-rose-500" />}
          gradient="from-rose-500/20 to-rose-500/5"
          trend="-2% this week"
        />
        <StatCard 
          title="Active Insurance" 
          value={`${stats?.active_insurance || 0}`} 
          icon={<ShieldCheck size={24} className="text-emerald-500" />}
          gradient="from-emerald-500/20 to-emerald-500/5"
          subtitle={`out of ${stats?.total_vehicles || 0} vehicles`}
        />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Chart 1: Registration Trend */}
        <motion.div 
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2 }}
          className="lg:col-span-2 bg-white dark:bg-slate-800 rounded-2xl shadow-sm border border-slate-200 dark:border-slate-700 p-6"
        >
          <div className="flex items-center justify-between mb-6">
            <h2 className="text-lg font-semibold flex items-center gap-2">
              <TrendingUp className="text-indigo-500" size={20} /> Registration Trends
            </h2>
          </div>
          <div className="h-[300px] w-full">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={trendData} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
                <defs>
                  <linearGradient id="colorValue" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#4f46e5" stopOpacity={0.3}/>
                    <stop offset="95%" stopColor="#4f46e5" stopOpacity={0}/>
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#e2e8f0" />
                <XAxis dataKey="name" axisLine={false} tickLine={false} tick={{ fill: '#64748b' }} />
                <YAxis axisLine={false} tickLine={false} tick={{ fill: '#64748b' }} />
                <RechartsTooltip 
                  contentStyle={{ borderRadius: '12px', border: 'none', boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1)' }}
                />
                <Area type="monotone" dataKey="value" stroke="#4f46e5" strokeWidth={3} fillOpacity={1} fill="url(#colorValue)" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </motion.div>

        {/* Chart 2: Fuel Distribution */}
        <motion.div 
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.3 }}
          className="bg-white dark:bg-slate-800 rounded-2xl shadow-sm border border-slate-200 dark:border-slate-700 p-6 flex flex-col"
        >
          <h2 className="text-lg font-semibold mb-2">Fuel Type Distribution</h2>
          <p className="text-sm text-slate-500 mb-6">Breakdown of registered vehicles by primary fuel source.</p>
          
          <div className="flex-1 flex flex-col items-center justify-center">
            <div className="h-[200px] w-full">
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie
                    data={fuel_distribution}
                    cx="50%"
                    cy="50%"
                    innerRadius={60}
                    outerRadius={80}
                    paddingAngle={5}
                    dataKey="count"
                    nameKey="fuel_type"
                  >
                    {fuel_distribution?.map((_: any, index: number) => (
                      <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                    ))}
                  </Pie>
                  <RechartsTooltip 
                    contentStyle={{ borderRadius: '12px', border: 'none', boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1)' }}
                  />
                </PieChart>
              </ResponsiveContainer>
            </div>
            
            <div className="w-full mt-4 space-y-2">
              {fuel_distribution?.map((entry: any, index: number) => (
                <div key={entry.fuel_type} className="flex items-center justify-between text-sm">
                  <div className="flex items-center gap-2">
                    <div className="w-3 h-3 rounded-full" style={{ backgroundColor: COLORS[index % COLORS.length] }}></div>
                    <span className="font-medium">{entry.fuel_type}</span>
                  </div>
                  <span className="text-slate-500">{entry.count} vehicles</span>
                </div>
              ))}
            </div>
          </div>
        </motion.div>
      </div>
    </div>
  )
}

function StatCard({ title, value, icon, gradient, trend, subtitle }: any) {
  return (
    <motion.div 
      whileHover={{ y: -4, boxShadow: '0 10px 15px -3px rgb(0 0 0 / 0.1), 0 4px 6px -4px rgb(0 0 0 / 0.1)' }}
      className={`bg-gradient-to-br ${gradient} bg-white dark:bg-slate-800 p-6 rounded-2xl shadow-sm border border-slate-200 dark:border-slate-700/50 relative overflow-hidden`}
    >
      <div className="flex items-center justify-between mb-4 relative z-10">
        <h3 className="text-slate-500 dark:text-slate-400 font-medium text-sm">{title}</h3>
        <div className="p-2 bg-white dark:bg-slate-700 rounded-xl shadow-sm">
          {icon}
        </div>
      </div>
      <div className="relative z-10">
        <div className="text-3xl font-bold text-slate-900 dark:text-white mb-1">{value}</div>
        {trend && <div className="text-xs font-medium text-emerald-600 dark:text-emerald-400">{trend}</div>}
        {subtitle && <div className="text-xs font-medium text-slate-500 dark:text-slate-400">{subtitle}</div>}
      </div>
    </motion.div>
  )
}
