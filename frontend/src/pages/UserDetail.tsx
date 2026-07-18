import { useEffect, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { getOwnerDetail } from '../lib/api'
import { 
  Phone, Mail, MapPin, CreditCard, 
  Car, FileCheck, ArrowLeft, CheckCircle2, AlertCircle 
} from 'lucide-react'

export default function UserDetail() {
  const { id } = useParams()
  const [data, setData] = useState<any>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    if (id) {
      getOwnerDetail(id)
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

  if (!data || !data.owner) {
    return (
      <div className="text-center py-20">
        <h2 className="text-2xl font-bold text-slate-800 dark:text-slate-200">User not found</h2>
        <Link to="/users" className="text-indigo-600 mt-4 inline-block hover:underline">Return to list</Link>
      </div>
    )
  }

  const { owner, vehicles, licenses } = data

  return (
    <div className="space-y-6 max-w-5xl mx-auto animate-in fade-in duration-500 pb-20">
      <Link to="/users" className="inline-flex items-center text-slate-500 hover:text-slate-900 dark:hover:text-white transition-colors">
        <ArrowLeft size={16} className="mr-2" /> Back to Users
      </Link>
      
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        
        {/* Profile Card */}
        <div className="md:col-span-2 bg-white dark:bg-slate-800 rounded-3xl p-8 shadow-sm border border-slate-200 dark:border-slate-700 relative overflow-hidden">
          <div className="absolute top-0 right-0 w-48 h-48 bg-gradient-to-bl from-indigo-500/10 to-transparent rounded-bl-full pointer-events-none"></div>
          
          <div className="flex flex-col sm:flex-row items-start sm:items-center gap-6 relative z-10">
            <div className="w-24 h-24 rounded-2xl bg-gradient-to-tr from-indigo-600 to-violet-600 flex items-center justify-center text-white font-bold text-4xl shadow-md">
              {(owner.full_name || '?').charAt(0)}
            </div>
            
            <div>
              <div className="flex items-center gap-3 mb-1">
                <h1 className="text-3xl font-bold text-slate-900 dark:text-white">{owner.full_name}</h1>
              </div>
              <div className="text-sm font-mono text-slate-500 bg-slate-100 dark:bg-slate-700/50 inline-block px-2 py-0.5 rounded mb-4">
                {owner.user_id}
              </div>
              
              <div className="space-y-2 text-sm text-slate-600 dark:text-slate-300">
                <div className="flex items-center gap-2"><Phone size={16} className="text-slate-400"/> {owner.phone_number}</div>
                <div className="flex items-center gap-2"><Mail size={16} className="text-slate-400"/> {owner.email || 'No email provided'}</div>
                <div className="flex items-start gap-2"><MapPin size={16} className="text-slate-400 mt-0.5 shrink-0"/> <span className="max-w-md leading-snug">{owner.full_address}</span></div>
                <div className="flex items-center gap-2 mt-2 pt-2 border-t border-slate-100 dark:border-slate-700"><CreditCard size={16} className="text-slate-400"/> DOB: <span className="font-mono">{new Date(owner.dob).toLocaleDateString()}</span></div>
              </div>
            </div>
          </div>
        </div>

        {/* Wallet Card */}
        {owner.wallet_id ? (
          <div className="bg-gradient-to-br from-indigo-600 to-violet-700 rounded-3xl p-8 shadow-md text-white relative overflow-hidden flex flex-col justify-between">
            <div className="absolute top-0 right-0 p-8 opacity-20 pointer-events-none">
              <CreditCard size={120} />
            </div>
            
            <div className="relative z-10">
              <div className="flex justify-between items-start mb-6">
                <h2 className="font-medium text-indigo-100">E-Wallet Balance</h2>
                {owner.wallet_status === 'Active' ? (
                  <span className="bg-emerald-500/20 text-emerald-100 border border-emerald-500/30 px-2 py-1 rounded text-xs flex items-center gap-1">
                    <CheckCircle2 size={12} /> Active
                  </span>
                ) : owner.wallet_status === 'Blocked' ? (
                  <span className="bg-rose-500/20 text-rose-100 border border-rose-500/30 px-2 py-1 rounded text-xs flex items-center gap-1">
                    <AlertCircle size={12} /> Blocked
                  </span>
                ) : (
                  <span className="bg-slate-500/20 text-slate-200 border border-slate-500/30 px-2 py-1 rounded text-xs flex items-center gap-1">
                    <AlertCircle size={12} /> Closed
                  </span>
                )}
              </div>
              
              <div className="text-4xl font-bold mb-1 tracking-tight">₹{owner.wallet_balance?.toLocaleString() || 0}</div>
              <div className="text-indigo-200 text-sm font-mono opacity-80">WID: {owner.wallet_id}</div>
            </div>

            <div className="relative z-10 mt-8">
              <Link to={`/wallets/${owner.wallet_id}`} className="block w-full text-center bg-white/20 hover:bg-white/30 backdrop-blur-md transition-colors py-2.5 rounded-xl font-medium text-white text-sm">
                Manage Wallet
              </Link>
            </div>
          </div>
        ) : (
          <div className="bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700 rounded-3xl p-8 text-slate-500 dark:text-slate-400 relative overflow-hidden flex flex-col justify-center items-center text-center">
            <CreditCard size={48} className="mb-4 opacity-30" />
            <h2 className="font-medium text-lg text-slate-700 dark:text-slate-300 mb-2">No Wallet Setup</h2>
            <p className="text-sm mb-6 max-w-[200px] text-slate-500 dark:text-slate-400">This user does not have an active E-Wallet yet.</p>
            <button className="bg-indigo-600 hover:bg-indigo-700 text-white px-6 py-2 rounded-xl font-medium transition-colors text-sm w-full">
              Create Wallet
            </button>
          </div>
        )}

      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        
        {/* Vehicles Owned */}
        <div className="bg-white dark:bg-slate-800 rounded-2xl p-6 shadow-sm border border-slate-200 dark:border-slate-700">
          <div className="flex justify-between items-center mb-6 border-b border-slate-100 dark:border-slate-700 pb-4">
            <h2 className="text-xl font-bold flex items-center gap-2">
              <Car className="text-indigo-500" /> Owned Vehicles
            </h2>
            <span className="bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300 px-3 py-1 rounded-full text-xs font-bold">
              {vehicles?.length || 0}
            </span>
          </div>

          <div className="space-y-3">
            {vehicles?.map((v: any) => (
              <Link key={v.vehicle_id} to={`/vehicles/${v.vehicle_id}`} className="block group">
                <div className="p-4 rounded-xl border border-slate-100 dark:border-slate-700 bg-slate-50 dark:bg-slate-900/30 group-hover:border-indigo-300 dark:group-hover:border-indigo-700 transition-colors flex items-center justify-between">
                  <div>
                    <h3 className="font-bold text-slate-900 dark:text-white group-hover:text-indigo-600 dark:group-hover:text-indigo-400">{v.model_name}</h3>
                    <div className="text-sm text-slate-500">{v.registration_no || 'PENDING'} • {v.status}</div>
                  </div>
                  {v.status === 'Current' ? (
                    <CheckCircle2 size={18} className="text-emerald-500" />
                  ) : (
                    <AlertCircle size={18} className="text-amber-500" />
                  )}
                </div>
              </Link>
            ))}
            {(!vehicles || vehicles.length === 0) && (
              <div className="text-center py-8 text-slate-500">No vehicles owned.</div>
            )}
          </div>
        </div>

        {/* Driving Licenses */}
        <div className="bg-white dark:bg-slate-800 rounded-2xl p-6 shadow-sm border border-slate-200 dark:border-slate-700">
          <div className="flex justify-between items-center mb-6 border-b border-slate-100 dark:border-slate-700 pb-4">
            <h2 className="text-xl font-bold flex items-center gap-2">
              <FileCheck className="text-indigo-500" /> Driving Licenses
            </h2>
          </div>

          <div className="space-y-4">
            {licenses?.map((lic: any) => {
              const isExpired = new Date(lic.expiry_date) < new Date();
              const isSuspended = lic.effective_status === 'Suspended';
              
              let statusIcon = <CheckCircle2 size={24} className="text-emerald-500" />;
              
              if (isSuspended) {
                statusIcon = <AlertCircle size={24} className="text-rose-500" />;
              } else if (isExpired) {
                statusIcon = <AlertCircle size={24} className="text-amber-500" />;
              }

              return (
                <div key={lic.license_no} className="relative rounded-xl border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900 overflow-hidden shadow-sm">
                  <div className={`absolute top-0 left-0 w-1.5 h-full ${
                    isSuspended ? 'bg-rose-500' : isExpired ? 'bg-amber-500' : 'bg-emerald-500'
                  }`}></div>
                  
                  <div className="p-5 pl-6 flex items-start justify-between">
                    <div>
                      <div className="text-xs text-slate-500 uppercase tracking-wider font-semibold mb-1">{lic.vehicle_class} LICENSE</div>
                      <div className="font-mono text-lg font-bold text-slate-900 dark:text-white mb-3">{lic.license_no}</div>
                      
                      <div className="grid grid-cols-2 gap-x-8 gap-y-2 text-sm">
                        <div>
                          <div className="text-slate-400 text-xs">Issued</div>
                          <div className="font-medium text-slate-700 dark:text-slate-300">{new Date(lic.issue_date).toLocaleDateString()}</div>
                        </div>
                        <div>
                          <div className="text-slate-400 text-xs">Valid Till</div>
                          <div className="font-medium text-slate-700 dark:text-slate-300">{new Date(lic.expiry_date).toLocaleDateString()}</div>
                        </div>
                        <div className="col-span-2">
                          <div className="text-slate-400 text-xs">Type</div>
                          <div className="font-medium text-slate-700 dark:text-slate-300">{lic.license_type}</div>
                        </div>
                      </div>
                    </div>
                    
                    <div className="flex flex-col items-end gap-2">
                      {statusIcon}
                      <span className={`text-xs font-bold uppercase tracking-wider px-2 py-1 rounded border ${
                        isSuspended ? 'bg-rose-50 text-rose-600 border-rose-200 dark:bg-rose-500/10 dark:border-rose-500/30' : 
                        isExpired ? 'bg-amber-50 text-amber-600 border-amber-200 dark:bg-amber-500/10 dark:border-amber-500/30' : 
                        'bg-emerald-50 text-emerald-600 border-emerald-200 dark:bg-emerald-500/10 dark:border-emerald-500/30'
                      }`}>
                        {isSuspended ? 'Suspended' : isExpired ? 'Expired' : 'Active'}
                      </span>
                    </div>
                  </div>
                </div>
              )
            })}
            {(!licenses || licenses.length === 0) && (
              <div className="text-center py-8 text-slate-500">No driving license registered.</div>
            )}
          </div>
        </div>

      </div>
    </div>
  )
}
