import { useEffect, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { getVehicleDetail } from '../lib/api'
import { 
  Shield, MapPin, AlertCircle, 
  CheckCircle2, ArrowLeft, Fuel, Calendar, Factory, Users, Receipt 
} from 'lucide-react'

export default function VehicleDetail() {
  const { id } = useParams()
  const [data, setData] = useState<any>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    if (id) {
      getVehicleDetail(id)
        .then(res => setData(res))
        .catch(err => console.error(err))
        .finally(() => setLoading(false))
    }
  }, [id])

  if (loading) {
    return (
      <div className="flex h-[50vh] items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-indigo-500"></div>
      </div>
    )
  }

  if (!data || !data.vehicle) {
    return (
      <div className="text-center py-20">
        <h2 className="text-2xl font-bold text-slate-800 dark:text-slate-200">Vehicle not found</h2>
        <Link to="/vehicles" className="text-indigo-600 mt-4 inline-block hover:underline">Return to list</Link>
      </div>
    )
  }

  const { vehicle, owners, insurances, challans } = data

  return (
    <div className="space-y-6 max-w-5xl mx-auto animate-in fade-in duration-500 pb-20">
      <Link to="/vehicles" className="inline-flex items-center text-slate-500 hover:text-slate-900 dark:hover:text-white transition-colors">
        <ArrowLeft size={16} className="mr-2" /> Back to Vehicles
      </Link>
      
      {/* Hero Profile Card */}
      <div className="bg-white dark:bg-slate-800 rounded-3xl p-8 shadow-sm border border-slate-200 dark:border-slate-700 relative overflow-hidden">
        <div className="absolute top-0 right-0 w-64 h-64 bg-gradient-to-bl from-indigo-500/10 to-transparent rounded-bl-full pointer-events-none"></div>
        
        <div className="flex flex-col md:flex-row justify-between gap-8 relative z-10">
          <div>
            <div className="flex items-center gap-3 mb-2">
              <span className="bg-indigo-100 text-indigo-700 dark:bg-indigo-500/20 dark:text-indigo-300 font-bold px-3 py-1 rounded-lg tracking-widest border border-indigo-200 dark:border-indigo-500/30">
                {vehicle.reg_no || 'PENDING REGISTRATION'}
              </span>
              {vehicle.is_fully_compliant ? (
                <span className="flex items-center gap-1 text-emerald-600 dark:text-emerald-400 font-medium text-sm bg-emerald-50 dark:bg-emerald-500/10 px-2 py-1 rounded-md">
                  <CheckCircle2 size={14} /> Fully Compliant
                </span>
              ) : (
                <span className="flex items-center gap-1 text-rose-600 dark:text-rose-400 font-medium text-sm bg-rose-50 dark:bg-rose-500/10 px-2 py-1 rounded-md">
                  <AlertCircle size={14} /> Compliance Issues
                </span>
              )}
            </div>
            
            <h1 className="text-4xl font-bold mt-4 mb-1 text-slate-900 dark:text-white">{vehicle.model_name}</h1>
            <p className="text-lg text-slate-500 mb-6">{vehicle.manufacturer} • {vehicle.registration_type}</p>
            
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-6">
              <div>
                <div className="text-sm text-slate-400 mb-1 flex items-center gap-1.5"><Fuel size={14}/> Fuel</div>
                <div className="font-medium">{vehicle.fuel_type}</div>
              </div>
              <div>
                <div className="text-sm text-slate-400 mb-1 flex items-center gap-1.5"><Calendar size={14}/> Year</div>
                <div className="font-medium">{vehicle.manufacture_year}</div>
              </div>
              <div>
                <div className="text-sm text-slate-400 mb-1 flex items-center gap-1.5"><Factory size={14}/> Color</div>
                <div className="font-medium">{vehicle.color}</div>
              </div>
              <div>
                <div className="text-sm text-slate-400 mb-1 flex items-center gap-1.5"><MapPin size={14}/> State</div>
                <div className="font-medium">{vehicle.registration_state}</div>
              </div>
            </div>
          </div>
          
          <div className="bg-slate-50 dark:bg-slate-900/50 p-5 rounded-2xl border border-slate-100 dark:border-slate-700/50 min-w-[240px]">
            <h3 className="text-sm font-semibold text-slate-400 uppercase tracking-wider mb-4">Identifiers</h3>
            <div className="space-y-4">
              <div>
                <div className="text-xs text-slate-500 mb-1">VIN (Vehicle ID)</div>
                <div className="font-mono bg-white dark:bg-slate-800 px-3 py-1.5 rounded text-sm border border-slate-200 dark:border-slate-700">{vehicle.vehicle_id}</div>
              </div>
              <div>
                <div className="text-xs text-slate-500 mb-1">Engine Number</div>
                <div className="font-mono bg-white dark:bg-slate-800 px-3 py-1.5 rounded text-sm border border-slate-200 dark:border-slate-700">{vehicle.engine_number}</div>
              </div>
              <div>
                <div className="text-xs text-slate-500 mb-1">Chassis Number</div>
                <div className="font-mono bg-white dark:bg-slate-800 px-3 py-1.5 rounded text-sm border border-slate-200 dark:border-slate-700">{vehicle.chassis_number}</div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Info Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        
        {/* Ownership History */}
        <div className="bg-white dark:bg-slate-800 rounded-2xl p-6 shadow-sm border border-slate-200 dark:border-slate-700">
          <h2 className="text-xl font-bold mb-4 flex items-center gap-2 border-b border-slate-100 dark:border-slate-700 pb-4">
            <Users className="text-indigo-500" /> Ownership History
          </h2>
          <div className="space-y-4 relative before:absolute before:inset-0 before:ml-5 before:-translate-x-px md:before:mx-auto md:before:translate-x-0 before:h-full before:w-0.5 before:bg-gradient-to-b before:from-transparent before:via-slate-200 dark:before:via-slate-700 before:to-transparent">
            {owners?.map((owner: any, idx: number) => (
              <div key={idx} className="relative flex items-center justify-between md:justify-normal md:odd:flex-row-reverse group is-active">
                <div className="flex items-center justify-center w-10 h-10 rounded-full border-4 border-white dark:border-slate-800 bg-slate-100 dark:bg-slate-700 text-slate-500 shadow shrink-0 md:order-1 md:group-odd:-translate-x-1/2 md:group-even:translate-x-1/2 z-10">
                  {idx === 0 ? <CheckCircle2 className="text-emerald-500" size={20}/> : <div className="w-2 h-2 rounded-full bg-slate-400"></div>}
                </div>
                <div className="w-[calc(100%-4rem)] md:w-[calc(50%-2.5rem)] p-4 rounded-xl border border-slate-100 dark:border-slate-700/50 bg-slate-50 dark:bg-slate-900/30 shadow-sm">
                  <div className="flex items-center justify-between mb-1">
                    <h3 className="font-bold text-slate-800 dark:text-slate-200">{owner.owner_name}</h3>
                    {idx === 0 && <span className="bg-emerald-100 text-emerald-700 dark:bg-emerald-500/20 dark:text-emerald-400 text-xs px-2 py-0.5 rounded font-medium">Current</span>}
                  </div>
                  <div className="text-sm text-slate-500 mb-2 font-mono">{owner.owner_id}</div>
                  <div className="text-xs text-slate-400">
                    From: {new Date(owner.from_date).toLocaleDateString()} 
                    {owner.to_date ? ` to ${new Date(owner.to_date).toLocaleDateString()}` : ' - Present'}
                  </div>
                </div>
              </div>
            ))}
            {owners?.length === 0 && <div className="text-slate-500 text-center py-4 relative z-10">No owners registered.</div>}
          </div>
        </div>

        {/* Challans */}
        <div className="bg-white dark:bg-slate-800 rounded-2xl p-6 shadow-sm border border-slate-200 dark:border-slate-700">
          <div className="flex justify-between items-center border-b border-slate-100 dark:border-slate-700 pb-4 mb-4">
            <h2 className="text-xl font-bold flex items-center gap-2">
              <Receipt className="text-rose-500" /> Traffic Challans
            </h2>
            <Link to="/challans" className="text-sm text-indigo-600 hover:underline">View All</Link>
          </div>
          <div className="space-y-3">
            {challans?.map((c: any) => (
              <div key={c.challan_id} className={`p-4 rounded-xl border ${c.is_paid ? 'border-slate-100 dark:border-slate-700 bg-slate-50 dark:bg-slate-900/30' : 'border-rose-200 dark:border-rose-900/30 bg-rose-50/50 dark:bg-rose-900/10'}`}>
                <div className="flex justify-between mb-2">
                  <div className="font-medium">{c.reason}</div>
                  <div className="font-bold text-lg text-slate-900 dark:text-white">₹{c.amount}</div>
                </div>
                <div className="flex justify-between items-end">
                  <div className="text-xs text-slate-500">
                    <div><MapPin size={12} className="inline mr-1"/>{c.location}</div>
                    <div className="mt-1">{new Date(c.challan_date).toLocaleDateString()}</div>
                  </div>
                  <div>
                    {c.is_paid ? 
                      <span className="text-xs font-medium text-emerald-600 bg-emerald-100 dark:bg-emerald-500/20 px-2 py-1 rounded">Paid</span> : 
                      <span className="text-xs font-medium text-rose-600 bg-rose-100 dark:bg-rose-500/20 px-2 py-1 rounded">Unpaid</span>
                    }
                  </div>
                </div>
              </div>
            ))}
            {challans?.length === 0 && (
              <div className="text-center py-8">
                <div className="bg-emerald-100 dark:bg-emerald-900/30 w-12 h-12 rounded-full flex items-center justify-center mx-auto mb-3">
                  <CheckCircle2 className="text-emerald-600 dark:text-emerald-400" />
                </div>
                <div className="font-medium text-slate-900 dark:text-slate-100">No Challans</div>
                <div className="text-sm text-slate-500">Clean driving record.</div>
              </div>
            )}
          </div>
        </div>

        {/* Insurance */}
        <div className="bg-white dark:bg-slate-800 rounded-2xl p-6 shadow-sm border border-slate-200 dark:border-slate-700 md:col-span-2">
          <h2 className="text-xl font-bold mb-4 flex items-center gap-2 border-b border-slate-100 dark:border-slate-700 pb-4">
            <Shield className="text-indigo-500" /> Insurance Policies
          </h2>
          <div className="overflow-x-auto">
            <table className="w-full text-left text-sm">
              <thead className="bg-slate-50 dark:bg-slate-900/50 text-slate-500">
                <tr>
                  <th className="p-3 font-medium rounded-l-lg">Policy ID</th>
                  <th className="p-3 font-medium">Company</th>
                  <th className="p-3 font-medium">Type</th>
                  <th className="p-3 font-medium">Coverage</th>
                  <th className="p-3 font-medium">Valid Till</th>
                  <th className="p-3 font-medium rounded-r-lg text-right">Status</th>
                </tr>
              </thead>
              <tbody>
                {insurances?.map((ins: any) => (
                  <tr key={ins.policy_id} className="border-b border-slate-100 dark:border-slate-700/50 last:border-0">
                    <td className="p-3 font-mono text-xs">{ins.policy_id}</td>
                    <td className="p-3 font-medium">{ins.insurance_company}</td>
                    <td className="p-3">{ins.insurance_type}</td>
                    <td className="p-3">₹{ins.coverage_amount}</td>
                    <td className="p-3">{new Date(ins.expiry_date).toLocaleDateString()}</td>
                    <td className="p-3 text-right">
                      {new Date(ins.expiry_date) >= new Date() ? 
                        <span className="text-emerald-600 bg-emerald-50 dark:bg-emerald-500/10 px-2 py-1 rounded text-xs font-medium">Active</span> : 
                        <span className="text-rose-600 bg-rose-50 dark:bg-rose-500/10 px-2 py-1 rounded text-xs font-medium">Expired</span>
                      }
                    </td>
                  </tr>
                ))}
                {insurances?.length === 0 && (
                  <tr><td colSpan={6} className="text-center py-6 text-slate-500">No insurance records found.</td></tr>
                )}
              </tbody>
            </table>
          </div>
        </div>

      </div>
    </div>
  )
}
