import React, { useEffect, useState } from 'react'
import { getChallans, payChallan } from '../lib/api'
import { Receipt, Search, MapPin, AlertCircle, CheckCircle2, IndianRupee } from 'lucide-react'
import { motion } from 'framer-motion'

export default function ChallansList() {
  const [query, setQuery] = useState('')
  const [statusFilter, setStatusFilter] = useState('all')
  const [challans, setChallans] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [payingId, setPayingId] = useState<number | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [successMsg, setSuccessMsg] = useState<string | null>(null)

  useEffect(() => {
    fetchData()
  }, [statusFilter])

  const fetchData = async (q: string = query) => {
    setLoading(true)
    setError(null)
    try {
      const res = await getChallans(q, statusFilter)
      setChallans(res.challans || [])
    } catch (err: any) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault()
    fetchData(query)
  }

  const handlePay = async (id: number) => {
    setPayingId(id)
    setError(null)
    setSuccessMsg(null)
    try {
      const res = await payChallan(id)
      setSuccessMsg(res.message)
      // Update local state
      setChallans(challans.map(c => c.challan_id === id ? { ...c, is_paid: true } : c))
    } catch (err: any) {
      setError(err.message || 'Payment failed')
    } finally {
      setPayingId(null)
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-2xl font-bold">Traffic Challans</h1>
          <p className="text-slate-500">Manage and pay traffic violations</p>
        </div>
        <div className="bg-white dark:bg-slate-800 p-1 rounded-lg border border-slate-200 dark:border-slate-700 flex text-sm font-medium">
          <button 
            onClick={() => setStatusFilter('all')} 
            className={`px-4 py-1.5 rounded-md transition-colors ${statusFilter === 'all' ? 'bg-indigo-50 text-indigo-600 dark:bg-indigo-500/20 dark:text-indigo-400' : 'text-slate-500 hover:text-slate-900 dark:hover:text-slate-200'}`}
          >
            All
          </button>
          <button 
            onClick={() => setStatusFilter('unpaid')} 
            className={`px-4 py-1.5 rounded-md transition-colors ${statusFilter === 'unpaid' ? 'bg-indigo-50 text-indigo-600 dark:bg-indigo-500/20 dark:text-indigo-400' : 'text-slate-500 hover:text-slate-900 dark:hover:text-slate-200'}`}
          >
            Unpaid
          </button>
          <button 
            onClick={() => setStatusFilter('paid')} 
            className={`px-4 py-1.5 rounded-md transition-colors ${statusFilter === 'paid' ? 'bg-indigo-50 text-indigo-600 dark:bg-indigo-500/20 dark:text-indigo-400' : 'text-slate-500 hover:text-slate-900 dark:hover:text-slate-200'}`}
          >
            Paid
          </button>
        </div>
      </div>

      {/* Notifications */}
      {error && (
        <div className="bg-rose-50 dark:bg-rose-900/20 text-rose-600 dark:text-rose-400 p-4 rounded-xl border border-rose-200 dark:border-rose-800 flex items-center gap-2 font-medium">
          <AlertCircle size={20} /> {error}
        </div>
      )}
      {successMsg && (
        <div className="bg-emerald-50 dark:bg-emerald-900/20 text-emerald-600 dark:text-emerald-400 p-4 rounded-xl border border-emerald-200 dark:border-emerald-800 flex items-center gap-2 font-medium">
          <CheckCircle2 size={20} /> {successMsg}
        </div>
      )}

      {/* Search Bar */}
      <div className="bg-white dark:bg-slate-800 p-2 rounded-xl shadow-sm border border-slate-200 dark:border-slate-700">
        <form onSubmit={handleSearch} className="flex items-center">
          <div className="pl-3 text-slate-400"><Search size={20} /></div>
          <input 
            type="text" 
            value={query}
            onChange={e => setQuery(e.target.value)}
            placeholder="Search by Vehicle Reg No or Challan ID..."
            className="w-full bg-transparent border-none focus:ring-0 px-4 py-2 text-slate-900 dark:text-white placeholder:text-slate-400"
          />
          <button type="submit" className="bg-indigo-50 text-indigo-600 hover:bg-indigo-100 dark:bg-indigo-500/10 dark:text-indigo-400 dark:hover:bg-indigo-500/20 px-6 py-2 rounded-lg font-medium transition-colors">
            Search
          </button>
        </form>
      </div>

      {/* Grid */}
      {loading ? (
        <div className="flex justify-center p-12">
          <div className="animate-spin rounded-full h-8 w-8 border-t-2 border-b-2 border-indigo-500"></div>
        </div>
      ) : challans.length === 0 ? (
        <div className="text-center py-20 bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 border-dashed">
          <Receipt className="mx-auto h-12 w-12 text-slate-300 dark:text-slate-600 mb-4" />
          <h3 className="text-lg font-medium text-slate-900 dark:text-white">No challans found</h3>
          <p className="text-slate-500">Everything looks clear.</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
          {challans.map((c, i) => (
            <motion.div
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: i * 0.05 }}
              key={c.challan_id}
            >
              <div className={`bg-white dark:bg-slate-800 rounded-2xl p-6 shadow-sm border ${c.is_paid ? 'border-slate-200 dark:border-slate-700' : 'border-rose-200 dark:border-rose-900/30'} flex flex-col h-full relative overflow-hidden`}>
                
                {!c.is_paid && (
                  <div className="absolute top-0 right-0 w-16 h-16 bg-rose-500/10 rounded-bl-full"></div>
                )}

                <div className="flex justify-between items-start mb-4 relative z-10">
                  <div>
                    <div className="text-xs font-mono text-slate-400 mb-1">ID: {c.challan_id}</div>
                    <div className="font-bold text-lg leading-tight mb-2 text-slate-900 dark:text-white">{c.reason}</div>
                    <div className="inline-block bg-slate-100 dark:bg-slate-700 font-mono text-sm px-2 py-0.5 rounded font-bold tracking-wider">
                      {c.vehicle_id}
                    </div>
                  </div>
                  <div className={`text-xl font-bold flex items-center ${c.is_paid ? 'text-slate-400' : 'text-rose-600 dark:text-rose-400'}`}>
                    ₹{Number(c.amount)}
                  </div>
                </div>

                <div className="space-y-2 text-sm text-slate-500 mb-6">
                  <div className="flex items-start gap-2">
                    <MapPin size={16} className="mt-0.5 shrink-0" />
                    <span>{c.location}</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <AlertCircle size={16} />
                    <span>Issued: {new Date(c.challan_date).toLocaleDateString()}</span>
                  </div>
                </div>

                <div className="mt-auto pt-4 border-t border-slate-100 dark:border-slate-700 flex items-center justify-between">
                  {c.is_paid ? (
                    <div className="flex items-center gap-2 text-emerald-600 dark:text-emerald-400 font-medium">
                      <CheckCircle2 size={20} /> Paid
                    </div>
                  ) : (
                    <>
                      <div className="flex items-center gap-2 text-rose-600 dark:text-rose-400 font-medium">
                        <AlertCircle size={20} /> Unpaid
                      </div>
                      <button 
                        onClick={() => handlePay(c.challan_id)}
                        disabled={payingId === c.challan_id}
                        className="bg-slate-900 hover:bg-slate-800 dark:bg-indigo-600 dark:hover:bg-indigo-700 text-white px-4 py-2 rounded-lg text-sm font-medium transition-colors shadow-sm disabled:opacity-50 flex items-center gap-2"
                      >
                        {payingId === c.challan_id ? (
                          <span className="animate-spin w-4 h-4 border-2 border-white/30 border-t-white rounded-full"></span>
                        ) : (
                          <IndianRupee size={16} />
                        )}
                        Pay from Wallet
                      </button>
                    </>
                  )}
                </div>

              </div>
            </motion.div>
          ))}
        </div>
      )}
    </div>
  )
}
