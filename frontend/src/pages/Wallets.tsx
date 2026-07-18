import React, { useEffect, useState } from 'react'
import { getWallets } from '../lib/api'
import { Wallet, Search, CheckCircle2, AlertCircle } from 'lucide-react'
import { Link } from 'react-router-dom'
import { motion } from 'framer-motion'

export default function WalletsList() {
  const [query, setQuery] = useState('')
  const [wallets, setWallets] = useState<any[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => { fetchData() }, [])

  const fetchData = async (q: string = '') => {
    setLoading(true)
    try {
      const res = await getWallets(q)
      setWallets(res.wallets || [])
    } catch (err) { console.error(err) }
    finally { setLoading(false) }
  }

  const handleSearch = (e: React.FormEvent) => { e.preventDefault(); fetchData(query) }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">E-Wallets</h1>
        <p className="text-slate-500">Manage user wallet balances and transactions</p>
      </div>

      <div className="bg-white dark:bg-slate-800 p-2 rounded-xl shadow-sm border border-slate-200 dark:border-slate-700">
        <form onSubmit={handleSearch} className="flex items-center">
          <div className="pl-3 text-slate-400"><Search size={20} /></div>
          <input type="text" value={query} onChange={e => setQuery(e.target.value)}
            placeholder="Search by Wallet ID or Owner..."
            className="w-full bg-transparent border-none focus:ring-0 px-4 py-2 text-slate-900 dark:text-white placeholder:text-slate-400" />
          <button type="submit" className="bg-indigo-50 text-indigo-600 hover:bg-indigo-100 dark:bg-indigo-500/10 dark:text-indigo-400 dark:hover:bg-indigo-500/20 px-6 py-2 rounded-lg font-medium transition-colors">Search</button>
        </form>
      </div>

      {loading ? (
        <div className="flex justify-center p-12"><div className="animate-spin rounded-full h-8 w-8 border-t-2 border-b-2 border-indigo-500"></div></div>
      ) : wallets.length === 0 ? (
        <div className="text-center py-20 bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 border-dashed">
          <Wallet className="mx-auto h-12 w-12 text-slate-300 dark:text-slate-600 mb-4" />
          <h3 className="text-lg font-medium">No wallets found</h3>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
          {wallets.map((w, i) => {
            const isActive = w.status === 'Active'
            return (
              <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.05 }} key={w.wallet_id || i}>
                <Link to={`/wallets/${w.wallet_id}`} className="block h-full group">
                  <div className="bg-gradient-to-br from-indigo-600 to-violet-700 rounded-2xl p-6 shadow-sm text-white h-full flex flex-col relative overflow-hidden group-hover:shadow-lg group-hover:shadow-indigo-500/20 transition-all">
                    <div className="absolute top-0 right-0 w-32 h-32 bg-white/5 rounded-full blur-2xl transform translate-x-10 -translate-y-10"></div>
                    
                    <div className="flex justify-between items-start mb-4 relative z-10">
                      <div>
                        <div className="text-indigo-200 text-xs font-mono">WID: {w.wallet_id}</div>
                        <div className="font-bold text-lg mt-1">{w.owner_name || w.user_name || 'Unknown'}</div>
                      </div>
                      {w.status === 'Active' ? (
                        <span className="bg-emerald-500/20 text-emerald-100 border border-emerald-500/30 px-2 py-1 rounded text-xs flex items-center gap-1">
                          <CheckCircle2 size={12}/> Active
                        </span>
                      ) : w.status === 'Blocked' ? (
                        <span className="bg-rose-500/20 text-rose-100 border border-rose-500/30 px-2 py-1 rounded text-xs flex items-center gap-1">
                          <AlertCircle size={12}/> Blocked
                        </span>
                      ) : (
                        <span className="bg-slate-500/20 text-slate-200 border border-slate-400/30 px-2 py-1 rounded text-xs flex items-center gap-1">
                          <AlertCircle size={12}/> Closed
                        </span>
                      )}
                    </div>

                    <div className="mt-auto relative z-10">
                      <div className="text-indigo-200 text-xs mb-1">Balance</div>
                      <div className="text-3xl font-bold tracking-tight">₹{Number(w.balance || 0).toLocaleString()}</div>
                    </div>
                  </div>
                </Link>
              </motion.div>
            )
          })}
        </div>
      )}
    </div>
  )
}
