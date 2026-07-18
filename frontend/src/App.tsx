import React from 'react'
import { BrowserRouter, Routes, Route, Link, useLocation } from 'react-router-dom'
import { Car, LayoutDashboard, Users, FileText, Shield, FileCheck, MapPin, Receipt, Wallet, BarChart3, Menu } from 'lucide-react'

import Dashboard from './pages/Dashboard'
import VehiclesList from './pages/Vehicles'
import VehicleDetail from './pages/VehicleDetail'
import VehicleRegistration from './pages/VehicleRegistration'
import UsersList from './pages/Users'
import UserDetail from './pages/UserDetail'
import OwnershipTransfer from './pages/OwnershipTransfer'
import Licenses from './pages/Licenses'
import Insurance from './pages/Insurance'
import Permits from './pages/Permits'
import ChallansList from './pages/Challans'
import WalletsList from './pages/Wallets'
import WalletDetail from './pages/WalletDetail'
import Reports from './pages/Reports'

// Layout Component
const Layout = ({ children }: { children: React.ReactNode }) => {
  return (
    <div className="flex h-screen bg-gray-50 dark:bg-slate-900 text-slate-900 dark:text-slate-100 transition-colors duration-300 font-sans">
      
      {/* Sidebar */}
      <aside className="w-64 bg-white dark:bg-slate-800 border-r border-gray-200 dark:border-slate-700 hidden md:flex flex-col shadow-sm transition-colors duration-300">
        <div className="p-5 flex items-center gap-3 border-b border-gray-100 dark:border-slate-700">
          <div className="bg-indigo-600 p-2 rounded-lg shadow-sm shadow-indigo-600/20">
            <Car className="text-white w-6 h-6" />
          </div>
          <h1 className="font-bold text-lg leading-tight bg-clip-text text-transparent bg-gradient-to-r from-indigo-600 to-violet-600 dark:from-indigo-400 dark:to-violet-400">
            Unified Vehicle<br />Registry
          </h1>
        </div>
        
        <nav className="flex-1 overflow-y-auto p-4 space-y-1">
          <NavItem to="/" icon={<LayoutDashboard size={20} />} label="Dashboard" />
          
          <div className="pt-4 pb-2 px-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">Vehicles & Users</div>
          <NavItem to="/vehicles" icon={<Car size={20} />} label="Vehicles" />
          <NavItem to="/users" icon={<Users size={20} />} label="Users" />
          <NavItem to="/ownership" icon={<FileText size={20} />} label="Ownership Transfer" />
          
          <div className="pt-4 pb-2 px-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">Compliance & Fines</div>
          <NavItem to="/licenses" icon={<FileCheck size={20} />} label="Licenses" />
          <NavItem to="/insurance" icon={<Shield size={20} />} label="Insurance" />
          <NavItem to="/permits" icon={<MapPin size={20} />} label="Permits" />
          <NavItem to="/challans" icon={<Receipt size={20} />} label="Traffic Challans" />
          
          <div className="pt-4 pb-2 px-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">Finance & Insights</div>
          <NavItem to="/wallets" icon={<Wallet size={20} />} label="E-Wallets" />
          <NavItem to="/reports" icon={<BarChart3 size={20} />} label="Reports & Analytics" />
        </nav>
      </aside>

      {/* Main Content */}
      <main className="flex-1 flex flex-col overflow-hidden">
        {/* Topbar */}
        <header className="h-16 bg-white/80 backdrop-blur-md dark:bg-slate-800/80 border-b border-gray-200 dark:border-slate-700 flex items-center justify-between px-6 z-10 transition-colors duration-300">
          <button className="md:hidden text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200">
            <Menu size={24} />
          </button>
          
          <div className="flex-1 md:flex-none"></div>
          
          <div className="flex items-center gap-4">
            <div className="w-8 h-8 rounded-full bg-gradient-to-tr from-indigo-600 to-violet-600 flex items-center justify-center text-white font-medium shadow-sm">
              A
            </div>
          </div>
        </header>
        
        {/* Page Content */}
        <div className="flex-1 overflow-auto p-6 bg-slate-50 dark:bg-slate-900">
          <div className="mx-auto max-w-7xl">
            {children}
          </div>
        </div>
      </main>
    </div>
  )
}

const NavItem = ({ to, icon, label }: { to: string, icon: React.ReactNode, label: string }) => {
  const location = useLocation();
  const isActive = location.pathname === to || (to !== '/' && location.pathname.startsWith(to))
  
  return (
    <Link 
      to={to} 
      className={`flex items-center gap-3 px-3 py-2.5 rounded-lg transition-all duration-200 ${
        isActive 
          ? 'bg-indigo-50 dark:bg-indigo-500/15 text-indigo-700 dark:text-indigo-300 font-medium' 
          : 'text-slate-600 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800/50 hover:text-slate-900 dark:hover:text-slate-200'
      }`}
    >
      <span className={isActive ? 'text-indigo-600 dark:text-indigo-400' : 'text-slate-400 dark:text-slate-500'}>
        {icon}
      </span>
      {label}
    </Link>
  )
}

function App() {
  return (
    <BrowserRouter>
      <Layout>
        <Routes>
          <Route path="/" element={<Dashboard />} />
          <Route path="/vehicles" element={<VehiclesList />} />
          <Route path="/vehicles/new" element={<VehicleRegistration />} />
          <Route path="/vehicles/:id" element={<VehicleDetail />} />
          <Route path="/users" element={<UsersList />} />
          <Route path="/users/:id" element={<UserDetail />} />
          <Route path="/ownership" element={<OwnershipTransfer />} />
          <Route path="/licenses" element={<Licenses />} />
          <Route path="/insurance" element={<Insurance />} />
          <Route path="/permits" element={<Permits />} />
          <Route path="/challans" element={<ChallansList />} />
          <Route path="/wallets" element={<WalletsList />} />
          <Route path="/wallets/:id" element={<WalletDetail />} />
          <Route path="/reports" element={<Reports />} />
        </Routes>
      </Layout>
    </BrowserRouter>
  )
}

export default App
