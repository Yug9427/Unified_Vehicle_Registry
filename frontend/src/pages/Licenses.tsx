import React, { useEffect, useState } from 'react'
import { getLicenses } from '../lib/api'
import { FileCheck, Search, Calendar } from 'lucide-react'
import { motion } from 'framer-motion'

export default function Licenses() {
  const [query, setQuery] = useState('')
  const [licenses, setLicenses] = useState<any[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => { fetchData() }, [])

  const fetchData = async (q: string = '') => {
    setLoading(true)
    try {
      const res = await getLicenses(q)
      setLicenses(res.licenses || [])
    } catch (err) { console.error(err) }
    finally { setLoading(false) }
  }

  const handleSearch = (e: React.FormEvent) => { e.preventDefault(); fetchData(query) }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Driving Licenses</h1>
        <p className="text-slate-500">View and manage issued driving licenses</p>
      </div>

      <div className="bg-white dark:bg-slate-800 p-2 rounded-xl shadow-sm border border-slate-200 dark:border-slate-700">
        <form onSubmit={handleSearch} className="flex items-center">
          <div className="pl-3 text-slate-400"><Search size={20} /></div>
          <input type="text" value={query} onChange={e => setQuery(e.target.value)}
            placeholder="Search by License Number, Owner Name, or ID..."
            className="w-full bg-transparent border-none focus:ring-0 px-4 py-2 text-slate-900 dark:text-white placeholder:text-slate-400" />
          <button type="submit" className="bg-indigo-50 text-indigo-600 hover:bg-indigo-100 dark:bg-indigo-500/10 dark:text-indigo-400 dark:hover:bg-indigo-500/20 px-6 py-2 rounded-lg font-medium transition-colors">Search</button>
        </form>
      </div>

      {loading ? (
        <div className="flex justify-center p-12"><div className="animate-spin rounded-full h-8 w-8 border-t-2 border-b-2 border-indigo-500"></div></div>
      ) : licenses.length === 0 ? (
        <div className="text-center py-20 bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 border-dashed">
          <FileCheck className="mx-auto h-12 w-12 text-slate-300 dark:text-slate-600 mb-4" />
          <h3 className="text-lg font-medium">No licenses found</h3>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
          {licenses.map((lic, i) => {
            const isExpired = lic.expiry_date && new Date(lic.expiry_date) < new Date()
            const isSuspended = lic.status === 'Suspended'
            return (
              <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.05 }} key={lic.license_no}>
                <div className={`bg-white dark:bg-slate-800 rounded-2xl p-6 shadow-sm border relative overflow-hidden h-full ${
                  isSuspended ? 'border-rose-200 dark:border-rose-900/30' : isExpired ? 'border-amber-200 dark:border-amber-900/30' : 'border-slate-200 dark:border-slate-700'
                }`}>
                  <div className={`absolute top-0 left-0 w-1.5 h-full ${isSuspended ? 'bg-rose-500' : isExpired ? 'bg-amber-500' : 'bg-emerald-500'}`}></div>
                  
                  <div className="pl-3">
                    <div className="flex justify-between items-start mb-3">
                      <div>
                        <div className="text-xs text-slate-400 uppercase tracking-wider font-semibold">{lic.vehicle_class} License</div>
                        <div className="font-mono text-lg font-bold mt-1">{lic.license_no}</div>
                      </div>
                      <span className={`text-xs font-bold uppercase px-2 py-1 rounded border ${
                        isSuspended ? 'bg-rose-50 text-rose-600 border-rose-200 dark:bg-rose-500/10 dark:text-rose-400 dark:border-rose-500/30' :
                        isExpired ? 'bg-amber-50 text-amber-600 border-amber-200 dark:bg-amber-500/10 dark:text-amber-400 dark:border-amber-500/30' :
                        'bg-emerald-50 text-emerald-600 border-emerald-200 dark:bg-emerald-500/10 dark:text-emerald-400 dark:border-emerald-500/30'
                      }`}>
                        {isSuspended ? 'Suspended' : isExpired ? 'Expired' : 'Active'}
                      </span>
                    </div>

                    <div className="text-sm font-medium text-slate-800 dark:text-slate-200 mb-1">{lic.owner_name || 'N/A'}</div>
                    <div className="text-xs text-slate-500 font-mono mb-4">{lic.user_id || ''}</div>

                    <div className="grid grid-cols-2 gap-3 text-sm">
                      <div>
                        <div className="text-slate-400 text-xs flex items-center gap-1"><Calendar size={12}/> Issued</div>
                        <div className="font-medium">{lic.issue_date ? new Date(lic.issue_date).toLocaleDateString() : 'N/A'}</div>
                      </div>
                      <div>
                        <div className="text-slate-400 text-xs flex items-center gap-1"><Calendar size={12}/> Valid Till</div>
                        <div className="font-medium">{lic.expiry_date ? new Date(lic.expiry_date).toLocaleDateString() : 'N/A'}</div>
                      </div>
                      <div className="col-span-2">
                        <div className="text-slate-400 text-xs">License Type</div>
                        <div className="font-medium">{lic.license_type || 'N/A'}</div>
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
