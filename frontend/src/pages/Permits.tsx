import React, { useEffect, useState } from 'react'
import { getPermits } from '../lib/api'
import { MapPin, Search, Calendar, CheckCircle2, AlertCircle } from 'lucide-react'
import { motion } from 'framer-motion'

export default function Permits() {
  const [query, setQuery] = useState('')
  const [permits, setPermits] = useState<any[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => { fetchData() }, [])

  const fetchData = async (q: string = '') => {
    setLoading(true)
    try {
      const res = await getPermits(q)
      setPermits(res.permits || [])
    } catch (err) { console.error(err) }
    finally { setLoading(false) }
  }

  const handleSearch = (e: React.FormEvent) => { e.preventDefault(); fetchData(query) }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Route Permits</h1>
        <p className="text-slate-500">Manage vehicle route permits</p>
      </div>

      <div className="bg-white dark:bg-slate-800 p-2 rounded-xl shadow-sm border border-slate-200 dark:border-slate-700">
        <form onSubmit={handleSearch} className="flex items-center">
          <div className="pl-3 text-slate-400"><Search size={20} /></div>
          <input type="text" value={query} onChange={e => setQuery(e.target.value)}
            placeholder="Search by Permit ID or Vehicle..."
            className="w-full bg-transparent border-none focus:ring-0 px-4 py-2 text-slate-900 dark:text-white placeholder:text-slate-400" />
          <button type="submit" className="bg-indigo-50 text-indigo-600 hover:bg-indigo-100 dark:bg-indigo-500/10 dark:text-indigo-400 dark:hover:bg-indigo-500/20 px-6 py-2 rounded-lg font-medium transition-colors">Search</button>
        </form>
      </div>

      {loading ? (
        <div className="flex justify-center p-12"><div className="animate-spin rounded-full h-8 w-8 border-t-2 border-b-2 border-indigo-500"></div></div>
      ) : permits.length === 0 ? (
        <div className="text-center py-20 bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 border-dashed">
          <MapPin className="mx-auto h-12 w-12 text-slate-300 dark:text-slate-600 mb-4" />
          <h3 className="text-lg font-medium">No permits found</h3>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
          {permits.map((p, i) => {
            const isActive = p.permit_status === 'Active'
            return (
              <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.05 }} key={p.permit_id || i}>
                <div className={`bg-white dark:bg-slate-800 rounded-2xl p-6 shadow-sm border h-full ${isActive ? 'border-slate-200 dark:border-slate-700' : 'border-amber-200 dark:border-amber-900/30'}`}>
                  <div className="flex justify-between items-start mb-4">
                    <div className="flex items-center gap-3">
                      <div className={`p-2.5 rounded-xl ${isActive ? 'bg-indigo-50 dark:bg-indigo-500/10' : 'bg-amber-50 dark:bg-amber-500/10'}`}>
                        <MapPin size={22} className={isActive ? 'text-indigo-600 dark:text-indigo-400' : 'text-amber-600 dark:text-amber-400'} />
                      </div>
                      <div>
                        <div className="font-bold text-slate-900 dark:text-white">{p.permit_type || 'Route Permit'}</div>
                        <div className="text-xs font-mono text-slate-500">{p.permit_id}</div>
                      </div>
                    </div>
                    {isActive ? (
                      <span className="flex items-center gap-1 text-emerald-600 bg-emerald-50 dark:bg-emerald-500/10 dark:text-emerald-400 px-2 py-1 rounded text-xs font-bold">
                        <CheckCircle2 size={12}/> Active
                      </span>
                    ) : (
                      <span className="flex items-center gap-1 text-amber-600 bg-amber-50 dark:bg-amber-500/10 dark:text-amber-400 px-2 py-1 rounded text-xs font-bold">
                        <AlertCircle size={12}/> Expired
                      </span>
                    )}
                  </div>

                  <div className="space-y-3 text-sm">
                    <div className="bg-slate-50 dark:bg-slate-900/30 rounded-xl p-4 flex justify-between items-center">
                      <div>
                        <div className="text-xs text-slate-400 mb-1">Vehicle</div>
                        <div className="font-mono font-bold text-lg">{p.vehicle_id || 'N/A'}</div>
                      </div>
                      <div className="text-right">
                        <div className="text-xs text-slate-400 mb-1">Model</div>
                        <div className="font-bold text-slate-900 dark:text-white">{p.model_name || 'N/A'}</div>
                      </div>
                    </div>
                    
                    <div className="bg-slate-50 dark:bg-slate-900/30 rounded-xl p-4 text-center">
                      <div className="text-xs text-slate-400 mb-1">Issuing RTO</div>
                      <div className="font-medium text-slate-900 dark:text-white">{p.issuing_rto_id || 'N/A'}</div>
                    </div>

                    <div className="grid grid-cols-2 gap-3">
                      <div>
                        <div className="text-slate-400 text-xs flex items-center gap-1"><Calendar size={12}/> Issued</div>
                        <div className="font-medium">{p.issue_date ? new Date(p.issue_date).toLocaleDateString() : 'N/A'}</div>
                      </div>
                      <div>
                        <div className="text-slate-400 text-xs flex items-center gap-1"><Calendar size={12}/> Valid Till</div>
                        <div className="font-medium">{p.expiry_date ? new Date(p.expiry_date).toLocaleDateString() : 'N/A'}</div>
                      </div>
                    </div>
                  </div>
                </div>
              </motion.div>
            )
          })}
        </div>
      )}
    </div>
  )
}
