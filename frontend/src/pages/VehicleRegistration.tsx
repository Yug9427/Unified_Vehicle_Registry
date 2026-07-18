import React, { useState } from 'react'
import { registerVehicle } from '../lib/api'
import { useNavigate } from 'react-router-dom'
import { Car, FileText, CheckCircle2, AlertCircle } from 'lucide-react'

export default function VehicleRegistration() {
  const navigate = useNavigate()
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  
  const [formData, setFormData] = useState({
    vehicle_id: '',
    model_name: '',
    manufacturer: '',
    manufactured_year: new Date().getFullYear(),
    color: '',
    fuel_type: '',
    engine_no: '',
    chassis_no: '',
    registration_type: '',
    vehicle_weight: '',
    body_type: '',
    odometer_reading: '',
    registration_no: '',
    plate_number: '',
    owner_id: ''
  })

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    setFormData({ ...formData, [e.target.name]: e.target.value })
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    setError(null)
    
    // Parse numeric fields before submitting
    const payload = {
      ...formData,
      manufactured_year: parseInt(formData.manufactured_year as any) || new Date().getFullYear(),
      vehicle_weight: parseInt(formData.vehicle_weight as any),
      odometer_reading: parseInt(formData.odometer_reading as any) || 0,
    }
    
    try {
      await registerVehicle(payload)
      navigate(`/vehicles/${formData.vehicle_id}`)
    } catch (err: any) {
      setError(err.message || 'Failed to register vehicle')
      setLoading(false)
    }
  }

  return (
    <div className="max-w-3xl mx-auto space-y-6">
      <div className="mb-8">
        <h1 className="text-2xl font-bold mb-2">Register New Vehicle</h1>
        <p className="text-slate-500">Add a new vehicle to the registry. This will automatically generate an RC book and link the initial owner.</p>
      </div>

      {error && (
        <div className="bg-rose-50 text-rose-600 p-4 rounded-xl border border-rose-200 flex items-start gap-3">
          <AlertCircle className="mt-0.5 shrink-0" size={18} />
          <div>{error}</div>
        </div>
      )}

      <form onSubmit={handleSubmit} className="bg-white dark:bg-slate-800 rounded-2xl shadow-sm border border-slate-200 dark:border-slate-700 overflow-hidden">
        
        <div className="p-6 border-b border-slate-100 dark:border-slate-700 bg-slate-50/50 dark:bg-slate-800/50 flex items-center gap-3">
          <div className="bg-indigo-100 text-indigo-600 p-2 rounded-lg"><Car size={20} /></div>
          <h2 className="font-semibold text-lg">Vehicle Specifications</h2>
        </div>
        
        <div className="p-6 grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="space-y-2">
            <label className="text-sm font-medium">VIN (Vehicle ID) <span className="text-rose-500">*</span></label>
            <input required maxLength={17} type="text" name="vehicle_id" onChange={handleChange} 
                   className="w-full px-4 py-2 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 focus:ring-2 focus:ring-indigo-500 outline-none transition-shadow font-mono uppercase" 
                   placeholder="17-CHAR VIN" />
          </div>
          
          <div className="space-y-2">
            <label className="text-sm font-medium">Manufacturer <span className="text-rose-500">*</span></label>
            <input required type="text" name="manufacturer" onChange={handleChange} 
                   className="w-full px-4 py-2 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 focus:ring-2 focus:ring-indigo-500 outline-none" 
                   placeholder="e.g. Toyota" />
          </div>

          <div className="space-y-2">
            <label className="text-sm font-medium">Model Name <span className="text-rose-500">*</span></label>
            <input required type="text" name="model_name" onChange={handleChange} 
                   className="w-full px-4 py-2 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 focus:ring-2 focus:ring-indigo-500 outline-none" 
                   placeholder="e.g. Camry XLE" />
          </div>

          <div className="space-y-2">
            <label className="text-sm font-medium">Manufacture Year <span className="text-rose-500">*</span></label>
            <input required type="number" min="1990" max={new Date().getFullYear()} name="manufactured_year" value={formData.manufactured_year} onChange={handleChange} 
                   className="w-full px-4 py-2 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 focus:ring-2 focus:ring-indigo-500 outline-none" />
          </div>

          <div className="space-y-2">
            <label className="text-sm font-medium">Color <span className="text-rose-500">*</span></label>
            <input required type="text" name="color" onChange={handleChange} 
                   className="w-full px-4 py-2 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 focus:ring-2 focus:ring-indigo-500 outline-none" />
          </div>

          <div className="space-y-2">
            <label className="text-sm font-medium">Fuel Type <span className="text-rose-500">*</span></label>
            <select required name="fuel_type" onChange={handleChange} className="w-full px-4 py-2 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 focus:ring-2 focus:ring-indigo-500 outline-none">
              <option value="">Select...</option>
              <option value="Petrol">Petrol</option>
              <option value="Diesel">Diesel</option>
              <option value="Electric">Electric</option>
              <option value="CNG">CNG</option>
            </select>
          </div>
          
          <div className="space-y-2">
            <label className="text-sm font-medium">Body Type <span className="text-rose-500">*</span></label>
            <input required type="text" name="body_type" onChange={handleChange} placeholder="e.g. Sedan, SUV, Hatchback"
                   className="w-full px-4 py-2 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 focus:ring-2 focus:ring-indigo-500 outline-none" />
          </div>

          <div className="space-y-2">
            <label className="text-sm font-medium">Vehicle Weight (kg) <span className="text-rose-500">*</span></label>
            <input required type="number" min="1" name="vehicle_weight" onChange={handleChange} 
                   className="w-full px-4 py-2 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 focus:ring-2 focus:ring-indigo-500 outline-none" />
          </div>

          <div className="space-y-2">
            <label className="text-sm font-medium">Engine Number <span className="text-rose-500">*</span></label>
            <input required type="text" name="engine_no" onChange={handleChange} 
                   className="w-full px-4 py-2 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 focus:ring-2 focus:ring-indigo-500 outline-none font-mono uppercase" />
          </div>

          <div className="space-y-2">
            <label className="text-sm font-medium">Chassis Number <span className="text-rose-500">*</span></label>
            <input required type="text" name="chassis_no" onChange={handleChange} 
                   className="w-full px-4 py-2 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 focus:ring-2 focus:ring-indigo-500 outline-none font-mono uppercase" />
          </div>
        </div>

        <div className="p-6 border-y border-slate-100 dark:border-slate-700 bg-slate-50/50 dark:bg-slate-800/50 flex items-center gap-3">
          <div className="bg-indigo-100 text-indigo-600 p-2 rounded-lg"><FileText size={20} /></div>
          <h2 className="font-semibold text-lg">Registration Details</h2>
        </div>

        <div className="p-6 grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="space-y-2">
            <label className="text-sm font-medium">Registration Type <span className="text-rose-500">*</span></label>
            <select required name="registration_type" onChange={handleChange} className="w-full px-4 py-2 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 focus:ring-2 focus:ring-indigo-500 outline-none">
              <option value="">Select...</option>
              <option value="Private">Private</option>
              <option value="Commercial">Commercial</option>
              <option value="Government">Government</option>
            </select>
          </div>

          <div className="space-y-2">
            <label className="text-sm font-medium">Registration Number <span className="text-rose-500">*</span></label>
            <input required type="text" name="registration_no" onChange={handleChange} placeholder="e.g. GJ05AB1234"
                   className="w-full px-4 py-2 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 focus:ring-2 focus:ring-indigo-500 outline-none uppercase font-mono" />
          </div>

          <div className="space-y-2">
            <label className="text-sm font-medium">Plate Number <span className="text-rose-500">*</span></label>
            <input required type="text" name="plate_number" onChange={handleChange} placeholder="e.g. GJ05AB1234"
                   className="w-full px-4 py-2 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 focus:ring-2 focus:ring-indigo-500 outline-none uppercase font-mono" />
          </div>

          <div className="space-y-2">
            <label className="text-sm font-medium">Odometer Reading (km) <span className="text-rose-500">*</span></label>
            <input required type="number" name="odometer_reading" onChange={handleChange} 
                   className="w-full px-4 py-2 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 focus:ring-2 focus:ring-indigo-500 outline-none" />
          </div>

          <div className="space-y-2">
            <label className="text-sm font-medium">Initial Owner ID <span className="text-rose-500">*</span></label>
            <input required type="text" name="owner_id" onChange={handleChange} 
                   className="w-full px-4 py-2 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 focus:ring-2 focus:ring-indigo-500 outline-none" 
                   placeholder="e.g. USR-001" />
            <p className="text-xs text-slate-500">The owner must already be registered in the system.</p>
          </div>
        </div>

        <div className="p-6 bg-slate-50 dark:bg-slate-800/80 border-t border-slate-200 dark:border-slate-700 flex justify-end gap-3">
          <button type="button" onClick={() => navigate('/vehicles')} className="px-6 py-2 rounded-lg font-medium bg-white border border-slate-300 text-slate-700 hover:bg-slate-50">
            Cancel
          </button>
          <button type="submit" disabled={loading} className="px-6 py-2 rounded-lg font-medium bg-indigo-600 text-white hover:bg-indigo-700 shadow-sm flex items-center gap-2 disabled:opacity-50">
            {loading ? <span className="animate-spin w-4 h-4 border-2 border-white/30 border-t-white rounded-full"></span> : <CheckCircle2 size={18} />}
            Register Vehicle
          </button>
        </div>
      </form>
    </div>
  )
}
// Add import for AlertCircle in actual file handling
