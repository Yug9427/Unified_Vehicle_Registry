import React, { useState } from 'react'
import { transferOwnership } from '../lib/api'
import { ArrowRight, Car, Users, CheckCircle2, AlertCircle } from 'lucide-react'

export default function OwnershipTransfer() {
  const [vehicleId, setVehicleId] = useState('')
  const [newOwnerId, setNewOwnerId] = useState('')
  const [loading, setLoading] = useState(false)
  const [msg, setMsg] = useState<string | null>(null)
  const [err, setErr] = useState<string | null>(null)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true); setMsg(null); setErr(null)
    try {
      const res = await transferOwnership({ vehicle_id: vehicleId, new_owner_id: newOwnerId })
      setMsg(res.message)
      setVehicleId(''); setNewOwnerId('')
    } catch (e: any) { setErr(e.message || 'Transfer failed') }
    finally { setLoading(false) }
  }

  return (
    <div className="max-w-2xl mx-auto space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Ownership Transfer</h1>
        <p className="text-slate-500">Transfer a vehicle's ownership from the current owner to a new owner. This calls a PostgreSQL stored procedure to handle the transfer atomically.</p>
      </div>

      {msg && (
        <div className="bg-emerald-50 dark:bg-emerald-900/20 text-emerald-600 dark:text-emerald-400 p-4 rounded-xl border border-emerald-200 dark:border-emerald-800 flex items-center gap-2 font-medium">
          <CheckCircle2 size={20}/> {msg}
        </div>
      )}
      {err && (
        <div className="bg-rose-50 dark:bg-rose-900/20 text-rose-600 dark:text-rose-400 p-4 rounded-xl border border-rose-200 dark:border-rose-800 flex items-center gap-2 font-medium">
          <AlertCircle size={20}/> {err}
        </div>
      )}

      <form onSubmit={handleSubmit} className="bg-white dark:bg-slate-800 rounded-2xl shadow-sm border border-slate-200 dark:border-slate-700 overflow-hidden">
        <div className="p-8">
          <div className="flex flex-col md:flex-row items-center gap-6">
            {/* Vehicle */}
            <div className="flex-1 w-full">
              <div className="bg-slate-50 dark:bg-slate-900/50 rounded-2xl p-6 border-2 border-dashed border-slate-200 dark:border-slate-700 text-center">
                <div className="bg-indigo-100 dark:bg-indigo-500/20 p-4 rounded-xl inline-block mb-4">
                  <Car size={32} className="text-indigo-600 dark:text-indigo-400" />
                </div>
                <label className="text-sm font-medium text-slate-700 dark:text-slate-300 block mb-2">Vehicle ID (VIN)</label>
                <input type="text" required value={vehicleId} onChange={e => setVehicleId(e.target.value)}
                  className="w-full px-4 py-3 rounded-xl border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-800 focus:ring-2 focus:ring-indigo-500 outline-none font-mono text-center uppercase"
                  placeholder="e.g. VH-001" />
              </div>
            </div>

            {/* Arrow */}
            <div className="flex-shrink-0">
              <div className="bg-indigo-600 p-3 rounded-full shadow-md shadow-indigo-600/20">
                <ArrowRight size={24} className="text-white" />
              </div>
            </div>

            {/* New Owner */}
            <div className="flex-1 w-full">
              <div className="bg-slate-50 dark:bg-slate-900/50 rounded-2xl p-6 border-2 border-dashed border-slate-200 dark:border-slate-700 text-center">
                <div className="bg-violet-100 dark:bg-violet-500/20 p-4 rounded-xl inline-block mb-4">
                  <Users size={32} className="text-violet-600 dark:text-violet-400" />
                </div>
                <label className="text-sm font-medium text-slate-700 dark:text-slate-300 block mb-2">New Owner ID</label>
                <input type="text" required value={newOwnerId} onChange={e => setNewOwnerId(e.target.value)}
                  className="w-full px-4 py-3 rounded-xl border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-800 focus:ring-2 focus:ring-indigo-500 outline-none font-mono text-center uppercase"
                  placeholder="e.g. USR-010" />
              </div>
            </div>
          </div>
        </div>

        <div className="p-6 bg-slate-50 dark:bg-slate-800/80 border-t border-slate-200 dark:border-slate-700 flex justify-end">
          <button type="submit" disabled={loading}
            className="bg-indigo-600 hover:bg-indigo-700 text-white px-8 py-3 rounded-xl font-medium shadow-sm transition-colors flex items-center gap-2 disabled:opacity-50">
            {loading ? <span className="animate-spin w-4 h-4 border-2 border-white/30 border-t-white rounded-full"></span> : <ArrowRight size={18}/>}
            Transfer Ownership
          </button>
        </div>
      </form>
    </div>
  )
}
