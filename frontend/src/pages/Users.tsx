import React, { useEffect, useState } from 'react'
import { searchOwners, registerOwner } from '../lib/api'
import { Users, Search, MapPin, Phone, CheckCircle2, AlertCircle, Plus, X } from 'lucide-react'
import { Link } from 'react-router-dom'
import { motion, AnimatePresence } from 'framer-motion'

const BLOOD_GROUPS = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
const GENDERS = ['Male', 'Female', 'Other']

const emptyForm = {
  user_id: '', fname: '', mname: '', lname: '',
  dob: '', gender: '', blood_group: '', email: '',
  phone_number: '', street: '', city: '', state: '', pincode: '',
  password: '', confirm_password: ''
}

export default function UsersList() {
  const [query, setQuery] = useState('')
  const [owners, setOwners] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [showModal, setShowModal] = useState(false)
  const [form, setForm] = useState(emptyForm)
  const [submitting, setSubmitting] = useState(false)
  const [formError, setFormError] = useState('')
  const [formSuccess, setFormSuccess] = useState('')

  useEffect(() => {
    fetchData()
  }, [])

  const fetchData = async (q: string = '') => {
    setLoading(true)
    try {
      const res = await searchOwners(q)
      setOwners(res.owners || [])
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

  const handleFormChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    setForm(prev => ({ ...prev, [e.target.name]: e.target.value }))
  }

  const handleAddUser = async (e: React.FormEvent) => {
    e.preventDefault()
    if (form.password !== form.confirm_password) {
      setFormError('Passwords do not match.')
      return
    }
    if (form.password.length < 6) {
      setFormError('Password must be at least 6 characters.')
      return
    }
    setSubmitting(true)
    setFormError('')
    setFormSuccess('')
    try {
      const { confirm_password, ...payload } = form
      await registerOwner(payload)
      setFormSuccess('User added successfully!')
      setForm(emptyForm)
      fetchData()
      setTimeout(() => { setShowModal(false); setFormSuccess('') }, 1500)
    } catch (err: any) {
      setFormError(err.message || 'Failed to add user.')
    } finally {
      setSubmitting(false)
    }
  }

  const inputCls = "w-full bg-slate-50 dark:bg-slate-900 border border-slate-200 dark:border-slate-700 rounded-lg px-3 py-2 text-sm text-slate-900 dark:text-white placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-indigo-500"
  const labelCls = "block text-xs font-semibold text-slate-500 dark:text-slate-400 mb-1 uppercase tracking-wide"

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-2xl font-bold">Users</h1>
          <p className="text-slate-500">Manage registered users and their profiles</p>
        </div>
        <button
          onClick={() => { setShowModal(true); setFormError(''); setFormSuccess(''); setForm(emptyForm) }}
          className="bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2 rounded-lg font-medium shadow-sm transition-colors flex items-center gap-2"
        >
          <Plus size={18} /> Add User
        </button>
      </div>

      {/* Search */}
      <div className="bg-white dark:bg-slate-800 p-2 rounded-xl shadow-sm border border-slate-200 dark:border-slate-700">
        <form onSubmit={handleSearch} className="flex items-center">
          <div className="pl-3 text-slate-400"><Search size={20} /></div>
          <input 
            type="text" 
            value={query}
            onChange={e => setQuery(e.target.value)}
            placeholder="Search by ID, Name, Phone, or Aadhaar..."
            className="w-full bg-transparent border-none focus:ring-0 px-4 py-2 text-slate-900 dark:text-white placeholder:text-slate-400"
          />
          <button type="submit" className="bg-indigo-50 text-indigo-600 hover:bg-indigo-100 dark:bg-indigo-500/10 dark:text-indigo-400 dark:hover:bg-indigo-500/20 px-6 py-2 rounded-lg font-medium transition-colors">
            Search
          </button>
          <button 
            type="button" 
            onClick={() => { setQuery(''); fetchData('') }}
            className="bg-slate-100 text-slate-600 hover:bg-slate-200 dark:bg-slate-700 dark:text-slate-300 dark:hover:bg-slate-600 px-4 py-2 rounded-lg font-medium transition-colors whitespace-nowrap ml-2"
          >
            Show All Users
          </button>
        </form>
      </div>

      {loading ? (
        <div className="flex justify-center p-12">
          <div className="animate-spin rounded-full h-8 w-8 border-t-2 border-b-2 border-indigo-500"></div>
        </div>
      ) : owners.length === 0 ? (
        <div className="text-center py-20 bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 border-dashed">
          <Users className="mx-auto h-12 w-12 text-slate-300 dark:text-slate-600 mb-4" />
          <h3 className="text-lg font-medium text-slate-900 dark:text-white">No users found</h3>
          <p className="text-slate-500">Try adjusting your search query.</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
          {owners.map((owner, i) => (
            <motion.div
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: i * 0.05 }}
              key={owner.user_id}
            >
              <Link to={`/users/${owner.user_id}`} className="block h-full group">
                <div className="bg-white dark:bg-slate-800 rounded-xl p-6 shadow-sm border border-slate-200 dark:border-slate-700 group-hover:border-indigo-500 group-hover:shadow-md transition-all h-full flex flex-col">
                  
                  <div className="flex items-start gap-4 mb-4">
                    <div className="w-12 h-12 rounded-full bg-gradient-to-tr from-indigo-500 to-violet-500 flex items-center justify-center text-white font-bold text-lg shrink-0">
                      {(owner.full_name || '?').charAt(0)}
                    </div>
                    <div className="flex-1 min-w-0">
                      <h3 className="font-bold text-lg text-slate-900 dark:text-white truncate group-hover:text-indigo-600 dark:group-hover:text-indigo-400 transition-colors">
                        {owner.full_name}
                      </h3>
                      <div className="text-sm text-slate-500 font-mono mt-0.5">{owner.user_id}</div>
                    </div>
                  </div>

                  <div className="space-y-3 mt-2 text-sm">
                    <div className="flex items-center gap-3 text-slate-600 dark:text-slate-300">
                      <Phone size={16} className="text-slate-400" />
                      <span>{owner.phone_number}</span>
                    </div>
                    <div className="flex items-start gap-3 text-slate-600 dark:text-slate-300">
                      <MapPin size={16} className="text-slate-400 mt-0.5 shrink-0" />
                      <span className="line-clamp-2 leading-tight">{owner.city}</span>
                    </div>
                  </div>

                  <div className="mt-auto pt-4 flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <div className="text-xs font-semibold uppercase tracking-wider text-slate-500">Wallet</div>
                      {owner.wallet_status === 'Active' ? (
                        <span className="flex items-center gap-1 text-emerald-600 dark:text-emerald-400 font-medium text-xs bg-emerald-50 dark:bg-emerald-500/10 px-2 py-1 rounded">
                          <CheckCircle2 size={12} /> Active
                        </span>
                      ) : owner.wallet_status === 'Blocked' ? (
                        <span className="flex items-center gap-1 text-rose-600 dark:text-rose-400 font-medium text-xs bg-rose-50 dark:bg-rose-500/10 px-2 py-1 rounded">
                          <AlertCircle size={12} /> Blocked
                        </span>
                      ) : owner.wallet_status === 'Closed' ? (
                        <span className="flex items-center gap-1 text-slate-600 dark:text-slate-400 font-medium text-xs bg-slate-100 dark:bg-slate-800 px-2 py-1 rounded border border-slate-200 dark:border-slate-700">
                          <AlertCircle size={12} /> Closed
                        </span>
                      ) : (
                        <span className="flex items-center gap-1 text-slate-500 dark:text-slate-400 font-medium text-xs bg-slate-50 dark:bg-slate-800/50 px-2 py-1 rounded border border-dashed border-slate-300 dark:border-slate-600">
                          Not Setup
                        </span>
                      )}
                    </div>
                    <div className="font-bold text-lg">
                      {owner.wallet_status ? `₹${parseFloat(owner.wallet_balance || 0).toFixed(2)}` : '--'}
                    </div>
                  </div>
                </div>
              </Link>
            </motion.div>
          ))}
        </div>
      )}

      {/* Add User Modal */}
      <AnimatePresence>
        {showModal && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm"
            onClick={(e) => { if (e.target === e.currentTarget) setShowModal(false) }}
          >
            <motion.div
              initial={{ scale: 0.95, opacity: 0, y: 20 }}
              animate={{ scale: 1, opacity: 1, y: 0 }}
              exit={{ scale: 0.95, opacity: 0, y: 20 }}
              transition={{ type: 'spring', stiffness: 300, damping: 25 }}
              className="bg-white dark:bg-slate-800 rounded-2xl shadow-2xl w-full max-w-2xl max-h-[90vh] overflow-y-auto"
            >
              {/* Modal Header */}
              <div className="flex items-center justify-between px-6 py-5 border-b border-slate-100 dark:border-slate-700">
                <div>
                  <h2 className="text-xl font-bold text-slate-900 dark:text-white">Add New User</h2>
                  <p className="text-sm text-slate-500 mt-0.5">Fill in the details to register a new user</p>
                </div>
                <button onClick={() => setShowModal(false)} className="p-2 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-700 transition-colors">
                  <X size={20} className="text-slate-500" />
                </button>
              </div>

              <form onSubmit={handleAddUser} className="p-6 space-y-5">

                {/* User ID */}
                <div>
                  <label className={labelCls}>User ID <span className="text-rose-500">*</span></label>
                  <input name="user_id" value={form.user_id} onChange={handleFormChange} required
                    placeholder="e.g. USR000000051" className={inputCls} />
                  <p className="text-xs text-slate-400 mt-1">Format: USR followed by 9 digits</p>
                </div>

                {/* Password fields */}
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className={labelCls}>Password <span className="text-rose-500">*</span></label>
                    <input type="password" name="password" value={form.password} onChange={handleFormChange} required
                      placeholder="Min. 6 characters" className={inputCls} />
                  </div>
                  <div>
                    <label className={labelCls}>Confirm Password <span className="text-rose-500">*</span></label>
                    <input type="password" name="confirm_password" value={form.confirm_password} onChange={handleFormChange} required
                      placeholder="Re-enter password" className={inputCls} />
                  </div>
                </div>

                {/* Name fields */}
                <div className="grid grid-cols-3 gap-3">
                  <div>
                    <label className={labelCls}>First Name <span className="text-rose-500">*</span></label>
                    <input name="fname" value={form.fname} onChange={handleFormChange} required
                      placeholder="e.g. Dhavnit" className={inputCls} />
                  </div>
                  <div>
                    <label className={labelCls}>Father's Name</label>
                    <input name="mname" value={form.mname} onChange={handleFormChange}
                      placeholder="e.g. Rajeshkumar" className={inputCls} />
                  </div>
                  <div>
                    <label className={labelCls}>Last Name</label>
                    <input name="lname" value={form.lname} onChange={handleFormChange}
                      placeholder="e.g. Vaghela" className={inputCls} />
                  </div>
                </div>

                {/* DOB, Gender, Blood Group */}
                <div className="grid grid-cols-3 gap-3">
                  <div>
                    <label className={labelCls}>Date of Birth <span className="text-rose-500">*</span></label>
                    <input type="date" name="dob" value={form.dob} onChange={handleFormChange} required className={inputCls} />
                  </div>
                  <div>
                    <label className={labelCls}>Gender</label>
                    <select name="gender" value={form.gender} onChange={handleFormChange} className={inputCls}>
                      <option value="">Select</option>
                      {GENDERS.map(g => <option key={g} value={g}>{g}</option>)}
                    </select>
                  </div>
                  <div>
                    <label className={labelCls}>Blood Group</label>
                    <select name="blood_group" value={form.blood_group} onChange={handleFormChange} className={inputCls}>
                      <option value="">Select</option>
                      {BLOOD_GROUPS.map(b => <option key={b} value={b}>{b}</option>)}
                    </select>
                  </div>
                </div>

                {/* Contact */}
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className={labelCls}>Email</label>
                    <input type="email" name="email" value={form.email} onChange={handleFormChange}
                      placeholder="name@example.com" className={inputCls} />
                  </div>
                  <div>
                    <label className={labelCls}>Phone <span className="text-rose-500">*</span></label>
                    <input name="phone_number" value={form.phone_number} onChange={handleFormChange} required
                      placeholder="10-digit mobile number" className={inputCls} />
                  </div>
                </div>

                {/* Address */}
                <div>
                  <label className={labelCls}>Street Address</label>
                  <input name="street" value={form.street} onChange={handleFormChange}
                    placeholder="e.g. MG Road 42" className={inputCls} />
                </div>
                <div className="grid grid-cols-3 gap-3">
                  <div>
                    <label className={labelCls}>City</label>
                    <input name="city" value={form.city} onChange={handleFormChange}
                      placeholder="e.g. Ahmedabad" className={inputCls} />
                  </div>
                  <div>
                    <label className={labelCls}>State</label>
                    <input name="state" value={form.state} onChange={handleFormChange}
                      placeholder="e.g. Gujarat" className={inputCls} />
                  </div>
                  <div>
                    <label className={labelCls}>Pincode</label>
                    <input name="pincode" value={form.pincode} onChange={handleFormChange}
                      maxLength={6} placeholder="6-digit code" className={inputCls} />
                  </div>
                </div>

                {/* Feedback */}
                {formError && (
                  <div className="bg-rose-50 dark:bg-rose-500/10 border border-rose-200 dark:border-rose-500/30 text-rose-600 dark:text-rose-400 px-4 py-3 rounded-lg text-sm flex items-center gap-2">
                    <AlertCircle size={16} /> {formError}
                  </div>
                )}
                {formSuccess && (
                  <div className="bg-emerald-50 dark:bg-emerald-500/10 border border-emerald-200 dark:border-emerald-500/30 text-emerald-600 dark:text-emerald-400 px-4 py-3 rounded-lg text-sm flex items-center gap-2">
                    <CheckCircle2 size={16} /> {formSuccess}
                  </div>
                )}

                {/* Actions */}
                <div className="flex gap-3 pt-2">
                  <button type="button" onClick={() => setShowModal(false)}
                    className="flex-1 bg-slate-100 dark:bg-slate-700 hover:bg-slate-200 dark:hover:bg-slate-600 text-slate-700 dark:text-slate-200 py-2.5 rounded-xl font-medium transition-colors">
                    Cancel
                  </button>
                  <button type="submit" disabled={submitting}
                    className="flex-1 bg-indigo-600 hover:bg-indigo-700 disabled:opacity-50 text-white py-2.5 rounded-xl font-medium transition-colors flex items-center justify-center gap-2">
                    {submitting ? <div className="animate-spin rounded-full h-4 w-4 border-t-2 border-b-2 border-white"></div> : <Plus size={18} />}
                    {submitting ? 'Adding...' : 'Add User'}
                  </button>
                </div>
              </form>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}

