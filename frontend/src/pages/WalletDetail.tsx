import React, { useEffect, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { getWalletDetail, addWalletFunds } from '../lib/api'
import { Wallet, ArrowLeft, ArrowUpCircle, ArrowDownCircle, CheckCircle2, AlertCircle, Plus } from 'lucide-react'
import { motion } from 'framer-motion'

export default function WalletDetail() {
  const { id } = useParams()
  const [wallet, setWallet] = useState<any>(null)
  const [transactions, setTransactions] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [amount, setAmount] = useState('')
  const [adding, setAdding] = useState(false)
  const [msg, setMsg] = useState<string | null>(null)
  const [err, setErr] = useState<string | null>(null)

  const fetchData = async () => {
    setLoading(true)
    try {
      const res = await getWalletDetail(Number(id))
      setWallet(res.wallet)
      setTransactions(res.transactions || [])
    } catch (e) { console.error(e) }
    finally { setLoading(false) }
  }

  useEffect(() => { if (id) fetchData() }, [id])

  const handleAddFunds = async (e: React.FormEvent) => {
    e.preventDefault()
    setAdding(true); setMsg(null); setErr(null)
    try {
      const res = await addWalletFunds(Number(id), parseFloat(amount))
      setMsg(res.message)
      setAmount('')
      fetchData()
    } catch (e: any) { setErr(e.message) }
    finally { setAdding(false) }
  }

  if (loading) {
    return <div className="flex h-[50vh] items-center justify-center"><div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-indigo-500"></div></div>
  }

  if (!wallet) {
    return <div className="text-center py-20"><h2 className="text-2xl font-bold">Wallet not found</h2><Link to="/wallets" className="text-indigo-600 mt-4 inline-block hover:underline">Return to list</Link></div>
  }

  return (
    <div className="space-y-6 max-w-4xl mx-auto pb-20">
      <Link to="/wallets" className="inline-flex items-center text-slate-500 hover:text-slate-900 dark:hover:text-white transition-colors">
        <ArrowLeft size={16} className="mr-2" /> Back to Wallets
      </Link>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* Wallet Card */}
        <div className="bg-gradient-to-br from-indigo-600 to-violet-700 rounded-3xl p-8 text-white relative overflow-hidden">
          <div className="absolute top-0 right-0 w-32 h-32 bg-white/10 rounded-full blur-3xl transform translate-x-10 -translate-y-10"></div>
          <div className="relative z-10">
            <div className="flex justify-between items-start mb-6">
              <Wallet size={28} className="text-indigo-200" />
              {wallet.status === 'Active' ? (
                <span className="bg-emerald-500/20 text-emerald-100 border border-emerald-500/30 px-2 py-1 rounded text-xs flex items-center gap-1"><CheckCircle2 size={12}/> Active</span>
              ) : (
                <span className="bg-rose-500/20 text-rose-100 border border-rose-500/30 px-2 py-1 rounded text-xs flex items-center gap-1"><AlertCircle size={12}/> Blocked</span>
              )}
            </div>
            <div className="text-indigo-200 text-sm mb-1">Current Balance</div>
            <div className="text-4xl font-bold tracking-tight mb-4">₹{Number(wallet.balance || 0).toLocaleString()}</div>
            <div className="text-indigo-200 text-xs font-mono">WID: {wallet.wallet_id}</div>
            <div className="text-white text-sm mt-1 font-medium">{wallet.owner_name || wallet.user_name || ''}</div>
          </div>
        </div>

        {/* Add Funds Form */}
        <div className="md:col-span-2 bg-white dark:bg-slate-800 rounded-3xl p-8 shadow-sm border border-slate-200 dark:border-slate-700">
          <h2 className="text-xl font-bold mb-6 flex items-center gap-2"><Plus className="text-indigo-500" size={20}/> Add Funds</h2>
          
          {msg && <div className="bg-emerald-50 text-emerald-600 p-3 rounded-xl border border-emerald-200 mb-4 flex items-center gap-2 text-sm font-medium"><CheckCircle2 size={16}/> {msg}</div>}
          {err && <div className="bg-rose-50 text-rose-600 p-3 rounded-xl border border-rose-200 mb-4 flex items-center gap-2 text-sm font-medium"><AlertCircle size={16}/> {err}</div>}

          <form onSubmit={handleAddFunds} className="flex gap-4">
            <div className="flex-1">
              <label className="text-sm font-medium text-slate-700 dark:text-slate-300 block mb-2">Amount (₹)</label>
              <input type="number" min="1" step="0.01" required value={amount} onChange={e => setAmount(e.target.value)}
                className="w-full px-4 py-3 rounded-xl border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 focus:ring-2 focus:ring-indigo-500 outline-none text-lg font-mono"
                placeholder="e.g. 5000" />
            </div>
            <div className="flex items-end">
              <button type="submit" disabled={adding}
                className="bg-indigo-600 hover:bg-indigo-700 text-white px-8 py-3 rounded-xl font-medium shadow-sm transition-colors flex items-center gap-2 disabled:opacity-50">
                {adding ? <span className="animate-spin w-4 h-4 border-2 border-white/30 border-t-white rounded-full"></span> : <Plus size={18}/>}
                Add Funds
              </button>
            </div>
          </form>
        </div>
      </div>

      {/* Transaction History */}
      <div className="bg-white dark:bg-slate-800 rounded-2xl shadow-sm border border-slate-200 dark:border-slate-700 p-6">
        <h2 className="text-xl font-bold mb-6">Transaction History</h2>
        
        {transactions.length === 0 ? (
          <div className="text-center py-10 text-slate-500">No transactions yet.</div>
        ) : (
          <div className="space-y-3">
            {transactions.map((tx: any, i: number) => {
              const isCredit = tx.direction === 'Credit'
              const purposeStr = (tx.purpose || tx.direction || '').charAt(0).toUpperCase() + (tx.purpose || tx.direction || '').slice(1)
              return (
                <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: i * 0.03 }} key={tx.transaction_id || i}
                  className="flex items-center justify-between p-4 rounded-xl border border-slate-100 dark:border-slate-700 hover:bg-slate-50 dark:hover:bg-slate-900/30 transition-colors"
                >
                  <div className="flex items-center gap-4">
                    <div className={`p-2 rounded-full ${isCredit ? 'bg-emerald-50 dark:bg-emerald-500/10' : 'bg-rose-50 dark:bg-rose-500/10'}`}>
                      {isCredit ? <ArrowUpCircle className="text-emerald-500" size={22}/> : <ArrowDownCircle className="text-rose-500" size={22}/>}
                    </div>
                    <div>
                      <div className="font-medium text-slate-900 dark:text-white flex items-center gap-2">
                        {purposeStr}
                        {tx.status && <span className={`text-[10px] px-1.5 py-0.5 rounded border uppercase tracking-wider font-bold ${tx.status === 'Success' ? 'bg-emerald-50 text-emerald-600 border-emerald-200' : tx.status === 'Pending' ? 'bg-amber-50 text-amber-600 border-amber-200' : 'bg-rose-50 text-rose-600 border-rose-200'}`}>{tx.status}</span>}
                      </div>
                      <div className="text-xs text-slate-500">{tx.tran_datetime ? new Date(tx.tran_datetime).toLocaleString() : ''}</div>
                    </div>
                  </div>
                  <div className={`text-lg font-bold ${isCredit ? 'text-emerald-600 dark:text-emerald-400' : 'text-rose-600 dark:text-rose-400'}`}>
                    {isCredit ? '+' : '-'}₹{Number(tx.amount || 0).toLocaleString()}
                  </div>
                </motion.div>
              )
            })}
          </div>
        )}
      </div>
    </div>
  )
}
