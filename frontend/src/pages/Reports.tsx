import React, { useEffect, useState } from 'react'
import { getReports, refreshReports } from '../lib/api'
import { 
  BarChart3, RefreshCw, PieChart as PieChartIcon, 
  TrendingUp, Map, ShieldCheck, AlertTriangle
} from 'lucide-react'
import { 
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip as RechartsTooltip, ResponsiveContainer,
  PieChart, Pie, Cell, AreaChart, Area, Legend
} from 'recharts'
import { motion } from 'framer-motion'

export default function Reports() {
  const [data, setData] = useState<any>(null)
  const [loading, setLoading] = useState(true)
  const [refreshing, setRefreshing] = useState(false)
  const [activeTab, setActiveTab] = useState('compliance')

  const fetchData = async () => {
    setLoading(true)
    try {
      const res = await getReports()
      setData(res)
    } catch (err) {
      console.error(err)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchData()
  }, [])

  const handleRefresh = async () => {
    setRefreshing(true)
    try {
      await refreshReports()
      await fetchData()
    } catch (err) {
      console.error(err)
    } finally {
      setRefreshing(false)
    }
  }

  if (loading && !data) {
    return (
      <div className="flex h-[60vh] items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-indigo-500"></div>
      </div>
    )
  }

  const COLORS = ['#4f46e5', '#0ea5e9', '#10b981', '#f59e0b', '#8b5cf6', '#ec4899', '#f43f5e']

  return (
    <div className="space-y-6 animate-in fade-in duration-500">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-2xl font-bold flex items-center gap-2">
            <BarChart3 className="text-indigo-500" /> Analytics & Reports
          </h1>
          <p className="text-slate-500">Data insights powered by PostgreSQL Materialized Views</p>
        </div>
        <button 
          onClick={handleRefresh}
          disabled={refreshing}
          className="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 hover:bg-slate-50 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-200 px-4 py-2 rounded-lg font-medium shadow-sm transition-colors flex items-center gap-2 disabled:opacity-50"
        >
          <RefreshCw size={18} className={refreshing ? 'animate-spin text-indigo-500' : 'text-slate-400'} /> 
          {refreshing ? 'Refreshing Views...' : 'Refresh Data'}
        </button>
      </div>

      {/* Tabs */}
      <div className="flex overflow-x-auto hide-scrollbar gap-2 pb-2">
        <TabButton active={activeTab === 'compliance'} onClick={() => setActiveTab('compliance')} icon={<ShieldCheck size={16}/>} label="Compliance" />
        <TabButton active={activeTab === 'revenue'} onClick={() => setActiveTab('revenue')} icon={<Map size={16}/>} label="Revenue by State" />
        <TabButton active={activeTab === 'insurance'} onClick={() => setActiveTab('insurance')} icon={<PieChartIcon size={16}/>} label="Insurance Market" />
        <TabButton active={activeTab === 'fines'} onClick={() => setActiveTab('fines')} icon={<AlertTriangle size={16}/>} label="Fines & Defaulters" />
      </div>

      <div className="mt-6">
        
        {/* Compliance Tab */}
        {activeTab === 'compliance' && data?.compliance && (
          <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <div className="bg-white dark:bg-slate-800 rounded-2xl shadow-sm border border-slate-200 dark:border-slate-700 p-6">
              <h2 className="text-lg font-semibold mb-6 flex items-center gap-2"><TrendingUp className="text-emerald-500"/> Compliance Rates by Type</h2>
              <div className="h-[300px]">
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={data.compliance} layout="vertical" margin={{ top: 5, right: 30, left: 20, bottom: 5 }}>
                    <CartesianGrid strokeDasharray="3 3" horizontal={true} vertical={false} stroke="#e2e8f0" />
                    <XAxis type="number" hide />
                    <YAxis dataKey="registration_type" type="category" axisLine={false} tickLine={false} width={100} tick={{ fill: '#64748b' }} />
                    <RechartsTooltip cursor={{fill: 'transparent'}} contentStyle={{ borderRadius: '12px', border: 'none', boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1)' }} />
                    <Bar dataKey="compliant_count" name="Compliant" stackId="a" fill="#10b981" radius={[0, 0, 0, 0]} barSize={30} />
                    <Bar dataKey="non_compliant_count" name="Non-Compliant" stackId="a" fill="#f43f5e" radius={[0, 4, 4, 0]} barSize={30} />
                    <Legend />
                  </BarChart>
                </ResponsiveContainer>
              </div>
            </div>

            <div className="bg-white dark:bg-slate-800 rounded-2xl shadow-sm border border-slate-200 dark:border-slate-700 p-6">
               <h2 className="text-lg font-semibold mb-6 flex items-center gap-2"><PieChartIcon className="text-indigo-500"/> Overall Compliance Summary</h2>
               <div className="overflow-x-auto">
                 <table className="w-full text-left text-sm">
                   <thead className="bg-slate-50 dark:bg-slate-900/50 text-slate-500">
                     <tr>
                       <th className="p-3 font-medium rounded-l-lg">Type</th>
                       <th className="p-3 font-medium">Total</th>
                       <th className="p-3 font-medium text-emerald-600">Compliant</th>
                       <th className="p-3 font-medium text-rose-600">Non-Compliant</th>
                       <th className="p-3 font-medium rounded-r-lg text-right">Compliance %</th>
                     </tr>
                   </thead>
                   <tbody>
                     {data.compliance.map((c: any) => {
                       const total = c.total_vehicles;
                       const pct = total > 0 ? ((c.compliant_count / total) * 100).toFixed(1) : '0.0';
                       return (
                         <tr key={c.registration_type} className="border-b border-slate-100 dark:border-slate-700/50">
                           <td className="p-3 font-medium">{c.registration_type}</td>
                           <td className="p-3">{total}</td>
                           <td className="p-3">{c.compliant_count}</td>
                           <td className="p-3">{c.non_compliant_count}</td>
                           <td className="p-3 text-right">
                             <div className="flex items-center justify-end gap-2">
                               <div className="w-16 h-2 bg-slate-100 dark:bg-slate-700 rounded-full overflow-hidden">
                                 <div className="h-full bg-emerald-500" style={{ width: `${pct}%` }}></div>
                               </div>
                               <span className="font-mono w-10">{pct}%</span>
                             </div>
                           </td>
                         </tr>
                       )
                     })}
                   </tbody>
                 </table>
               </div>
            </div>
          </motion.div>
        )}

        {/* Revenue Tab */}
        {activeTab === 'revenue' && data?.revenue && (
          <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} className="bg-white dark:bg-slate-800 rounded-2xl shadow-sm border border-slate-200 dark:border-slate-700 p-6">
            <h2 className="text-lg font-semibold mb-6 flex items-center gap-2"><Map className="text-violet-500"/> Total Fine Revenue by State</h2>
            <div className="h-[400px] w-full">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={data.revenue} margin={{ top: 20, right: 30, left: 20, bottom: 5 }}>
                  <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#e2e8f0" />
                  <XAxis dataKey="state" axisLine={false} tickLine={false} tick={{ fill: '#64748b' }} />
                  <YAxis axisLine={false} tickLine={false} tick={{ fill: '#64748b' }} tickFormatter={(val) => `₹${val/1000}k`} />
                  <RechartsTooltip 
                    formatter={(value: any) => [`₹${Number(value).toLocaleString()}`, 'Total Collected'] as any}
                    contentStyle={{ borderRadius: '12px', border: 'none', boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1)' }} 
                  />
                  <Bar dataKey="total_collected" fill="url(#colorRevenue)" radius={[6, 6, 0, 0]} barSize={40}>
                    {data.revenue.map((_: any, index: number) => (
                      <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                    ))}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            </div>
          </motion.div>
        )}

        {/* Insurance Tab */}
        {activeTab === 'insurance' && data?.insurance && (
          <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="bg-white dark:bg-slate-800 rounded-2xl shadow-sm border border-slate-200 dark:border-slate-700 p-6 flex flex-col">
              <h2 className="text-lg font-semibold mb-6">Market Share (Policies Issued)</h2>
              <div className="flex-1 h-[300px]">
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie
                      data={data.insurance}
                      cx="50%"
                      cy="50%"
                      innerRadius={80}
                      outerRadius={110}
                      paddingAngle={2}
                      dataKey="policies_issued"
                      nameKey="insurance_company"
                    >
                      {data.insurance.map((_: any, index: number) => (
                        <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                      ))}
                    </Pie>
                    <RechartsTooltip contentStyle={{ borderRadius: '12px', border: 'none', boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1)' }} />
                  </PieChart>
                </ResponsiveContainer>
              </div>
            </div>
            
            <div className="bg-white dark:bg-slate-800 rounded-2xl shadow-sm border border-slate-200 dark:border-slate-700 p-6">
              <h2 className="text-lg font-semibold mb-6">Total Value Insured</h2>
              <div className="space-y-4">
                {data.insurance.map((ins: any, idx: number) => (
                  <div key={ins.insurance_company} className="flex items-center justify-between p-4 rounded-xl border border-slate-100 dark:border-slate-700 bg-slate-50 dark:bg-slate-900/30">
                    <div className="flex items-center gap-3">
                      <div className="w-3 h-3 rounded-full" style={{ backgroundColor: COLORS[idx % COLORS.length] }}></div>
                      <div>
                        <div className="font-bold">{ins.insurance_company}</div>
                        <div className="text-sm text-slate-500">{ins.policies_issued} Policies</div>
                      </div>
                    </div>
                    <div className="text-right">
                      <div className="font-bold text-lg">₹{(ins.total_value_insured / 100000).toFixed(1)}L</div>
                      <div className="text-xs text-slate-500">Value Insured</div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </motion.div>
        )}

        {/* Fines & Defaulters Tab */}
        {activeTab === 'fines' && data?.defaulters && data?.trend && (
          <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            
            <div className="bg-white dark:bg-slate-800 rounded-2xl shadow-sm border border-slate-200 dark:border-slate-700 p-6">
              <h2 className="text-lg font-semibold mb-6 flex items-center gap-2"><TrendingUp className="text-rose-500"/> Fine Issuance Trend</h2>
              <div className="h-[300px]">
                <ResponsiveContainer width="100%" height="100%">
                  <AreaChart data={data.trend} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
                    <defs>
                      <linearGradient id="colorFines" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="5%" stopColor="#f43f5e" stopOpacity={0.3}/>
                        <stop offset="95%" stopColor="#f43f5e" stopOpacity={0}/>
                      </linearGradient>
                    </defs>
                    <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#e2e8f0" />
                    <XAxis dataKey="month" axisLine={false} tickLine={false} tick={{ fill: '#64748b' }} />
                    <YAxis axisLine={false} tickLine={false} tick={{ fill: '#64748b' }} />
                    <RechartsTooltip contentStyle={{ borderRadius: '12px', border: 'none', boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1)' }} />
                    <Area type="monotone" dataKey="total_fines" name="Fines Issued" stroke="#f43f5e" strokeWidth={3} fillOpacity={1} fill="url(#colorFines)" />
                  </AreaChart>
                </ResponsiveContainer>
              </div>
            </div>

            <div className="bg-white dark:bg-slate-800 rounded-2xl shadow-sm border border-slate-200 dark:border-slate-700 p-6">
              <h2 className="text-lg font-semibold mb-6 flex items-center gap-2"><AlertTriangle className="text-amber-500"/> Top Defaulters (Unpaid Fines)</h2>
              <div className="space-y-3">
                {data.defaulters.map((d: any, idx: number) => (
                  <div key={d.vehicle_id} className="flex items-center justify-between p-3 rounded-xl border border-rose-100 dark:border-rose-900/30 bg-rose-50/50 dark:bg-rose-900/10">
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 rounded-full bg-rose-100 text-rose-600 dark:bg-rose-500/20 dark:text-rose-400 flex items-center justify-center font-bold text-sm">
                        #{idx + 1}
                      </div>
                      <div>
                        <div className="font-mono font-bold text-slate-900 dark:text-white">{d.vehicle_id}</div>
                        <div className="text-xs text-slate-500">{d.unpaid_count} pending challans</div>
                      </div>
                    </div>
                    <div className="text-right">
                      <div className="font-bold text-rose-600 dark:text-rose-400 text-lg">₹{d.total_unpaid_amount.toLocaleString()}</div>
                    </div>
                  </div>
                ))}
                {data.defaulters.length === 0 && (
                  <div className="text-center py-10 text-slate-500">No major defaulters found.</div>
                )}
              </div>
            </div>

          </motion.div>
        )}

      </div>
    </div>
  )
}

function TabButton({ active, onClick, icon, label }: { active: boolean, onClick: () => void, icon: React.ReactNode, label: string }) {
  return (
    <button 
      onClick={onClick}
      className={`flex items-center gap-2 px-4 py-2 rounded-full text-sm font-medium transition-all whitespace-nowrap ${
        active 
          ? 'bg-indigo-600 text-white shadow-md shadow-indigo-600/20' 
          : 'bg-white dark:bg-slate-800 text-slate-600 dark:text-slate-300 border border-slate-200 dark:border-slate-700 hover:bg-slate-50 dark:hover:bg-slate-700'
      }`}
    >
      {icon} {label}
    </button>
  )
}
