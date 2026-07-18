import React, { useEffect, useState } from 'react'
import { searchVehicles } from '../lib/api'
import { Car, Search, MapPin, Calendar, CheckCircle2, AlertCircle } from 'lucide-react'
import { Link } from 'react-router-dom'
import { motion } from 'framer-motion'

export default function VehiclesList() {
  const [query, setQuery] = useState('')
  const [vehicles, setVehicles] = useState<any[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    // Initial fetch
    fetchData()
  }, [])

  const fetchData = async (q: string = '') => {
    setLoading(true)
    try {
      const res = await searchVehicles(q)
      setVehicles(res.vehicles || [])
    } catch (err) {
      console.error(err)
    } finally {
      setLoading(false)
    }
  }

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault()
    fetchData(query)
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-2xl font-bold">Vehicles</h1>
          <p className="text-slate-500">Manage and search registered vehicles</p>
        </div>
        <button className="bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2 rounded-lg font-medium shadow-sm transition-colors flex items-center gap-2">
          <Car size={18} /> Register Vehicle
        </button>
      </div>

      {/* Search Bar */}
      <div className="bg-white dark:bg-slate-800 p-2 rounded-xl shadow-sm border border-slate-200 dark:border-slate-700">
        <form onSubmit={handleSearch} className="flex items-center">
          <div className="pl-3 text-slate-400"><Search size={20} /></div>
          <input 
            type="text" 
            value={query}
            onChange={e => setQuery(e.target.value)}
            placeholder="Search by VIN, Model, or Reg No..."
            className="w-full bg-transparent border-none focus:ring-0 px-4 py-2 text-slate-900 dark:text-white placeholder:text-slate-400"
          />
          <button type="submit" className="bg-indigo-50 text-indigo-600 hover:bg-indigo-100 dark:bg-indigo-500/10 dark:text-indigo-400 dark:hover:bg-indigo-500/20 px-6 py-2 rounded-lg font-medium transition-colors">
            Search
          </button>
          <button 
            type="button" 
            onClick={() => {
              setQuery('')
              fetchData('')
            }}
            className="bg-slate-100 text-slate-600 hover:bg-slate-200 dark:bg-slate-700 dark:text-slate-300 dark:hover:bg-slate-600 px-4 py-2 rounded-lg font-medium transition-colors whitespace-nowrap ml-2"
          >
            Show All Vehicles
          </button>
        </form>
      </div>

      {/* Vehicle Grid */}
      {loading ? (
        <div className="flex justify-center p-12">
          <div className="animate-spin rounded-full h-8 w-8 border-t-2 border-b-2 border-indigo-500"></div>
        </div>
      ) : vehicles.length === 0 ? (
        <div className="text-center py-20 bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 border-dashed">
          <Car className="mx-auto h-12 w-12 text-slate-300 dark:text-slate-600 mb-4" />
          <h3 className="text-lg font-medium text-slate-900 dark:text-white">No vehicles found</h3>
          <p className="text-slate-500">Try adjusting your search query.</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
          {vehicles.map((v, i) => (
            <motion.div
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: i * 0.05 }}
              key={v.vehicle_id}
            >
              <Link to={`/vehicles/${v.vehicle_id}`} className="block h-full group">
                <div className="bg-white dark:bg-slate-800 rounded-xl p-5 shadow-sm border border-slate-200 dark:border-slate-700 group-hover:border-indigo-500 group-hover:shadow-md transition-all h-full flex flex-col">
                  
                  <div className="flex justify-between items-start mb-4">
                    <div>
                      <h3 className="font-bold text-lg text-slate-900 dark:text-white group-hover:text-indigo-600 dark:group-hover:text-indigo-400 transition-colors">
                        {v.model_name}
                      </h3>
                      <p className="text-sm text-slate-500">{v.manufacturer}</p>
                    </div>
                    <div className="flex flex-col items-end">
                      <span className="bg-slate-100 dark:bg-slate-700 text-slate-800 dark:text-slate-200 text-xs font-bold px-2.5 py-1 rounded-md tracking-wider mb-1">
                        {v.registration_no || 'PENDING'}
                      </span>
                      {v.plate_number && (
                        <span className="text-slate-500 dark:text-slate-400 text-xs font-mono">
                          ({v.plate_number})
                        </span>
                      )}
                    </div>
                  </div>

                  <div className="space-y-2 mt-auto">
                    <div className="flex items-center justify-between text-sm">
                      <span className="text-slate-500 flex items-center gap-1.5"><MapPin size={14} /> Owner</span>
                      <span className="font-medium text-slate-900 dark:text-white">{v.owner_name}</span>
                    </div>
                    <div className="flex items-center justify-between text-sm">
                      <span className="text-slate-500 flex items-center gap-1.5"><Calendar size={14} /> Registered</span>
                      <span className="font-medium text-slate-900 dark:text-white">{v.registration_date ? new Date(v.registration_date).toLocaleDateString() : 'N/A'}</span>
                    </div>
                  </div>

                  <div className="mt-5 pt-4 border-t border-slate-100 dark:border-slate-700 flex justify-between items-center text-xs">
                    <div className="font-mono text-slate-400">{v.vehicle_id}</div>
                    
                    <div className="flex items-center gap-1">
                      {(v.has_insurance && v.has_puc) ? (
                        <span className="flex items-center gap-1 text-emerald-600 dark:text-emerald-400 font-medium bg-emerald-50 dark:bg-emerald-500/10 px-2 py-1 rounded-md">
                          <CheckCircle2 size={14} /> Compliant
                        </span>
                      ) : (
                        <span className="flex items-center gap-1 text-amber-600 dark:text-amber-400 font-medium bg-amber-50 dark:bg-amber-500/10 px-2 py-1 rounded-md">
                          <AlertCircle size={14} /> Attention Needed
                        </span>
                      )}
                    </div>
                  </div>
                </div>
              </Link>
            </motion.div>
          ))}
        </div>
      )}
    </div>
  )
}
