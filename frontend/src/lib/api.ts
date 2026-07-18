// API Client to interact with Flask Backend
const API_BASE = '/api';

export async function fetchApi<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
  const url = `${API_BASE}${endpoint}`;
  
  const headers = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    ...options.headers,
  };

  const response = await fetch(url, {
    ...options,
    headers,
  });

  const data = await response.json();

  if (!response.ok) {
    throw new Error(data.error || data.message || `API Error: ${response.status}`);
  }

  return data;
}

// Specific API calls

// Dashboard
export const getDashboardStats = () => fetchApi<any>('/dashboard/');

// Vehicles
export const searchVehicles = (q: string = '') => fetchApi<any>(`/vehicles/?q=${encodeURIComponent(q)}`);
export const getVehicleDetail = (id: string) => fetchApi<any>(`/vehicles/${id}`);
export const registerVehicle = (data: any) => fetchApi<any>('/vehicles/', { method: 'POST', body: JSON.stringify(data) });

// Owners
export const searchOwners = (q: string = '') => fetchApi<any>(`/owners/?q=${encodeURIComponent(q)}`);
export const getOwnerDetail = (id: string) => fetchApi<any>(`/owners/${id}`);
export const registerOwner = (data: any) => fetchApi<any>('/owners/', { method: 'POST', body: JSON.stringify(data) });

// Ownership Transfer
export const transferOwnership = (data: any) => fetchApi<any>('/ownership/transfer', { method: 'POST', body: JSON.stringify(data) });

// Licenses
export const getLicenses = (q: string = '') => fetchApi<any>(`/licenses/?q=${encodeURIComponent(q)}`);
export const issueLicense = (data: any) => fetchApi<any>('/licenses/', { method: 'POST', body: JSON.stringify(data) });

// Insurance
export const getInsurances = (q: string = '') => fetchApi<any>(`/insurance/?q=${encodeURIComponent(q)}`);
export const renewInsurance = (data: any) => fetchApi<any>('/insurance/renew', { method: 'POST', body: JSON.stringify(data) });

// Permits
export const getPermits = (q: string = '') => fetchApi<any>(`/permits/?q=${encodeURIComponent(q)}`);
export const issuePermit = (data: any) => fetchApi<any>('/permits/', { method: 'POST', body: JSON.stringify(data) });

// Challans
export const getChallans = (q: string = '', status: string = 'all') => 
  fetchApi<any>(`/challans/?q=${encodeURIComponent(q)}&status=${status}`);
export const issueChallan = (data: any) => fetchApi<any>('/challans/', { method: 'POST', body: JSON.stringify(data) });
export const payChallan = (id: number) => fetchApi<any>(`/challans/${id}/pay`, { method: 'POST' });

// Wallets
export const getWallets = (q: string = '') => fetchApi<any>(`/wallets/?q=${encodeURIComponent(q)}`);
export const getWalletDetail = (id: number) => fetchApi<any>(`/wallets/${id}`);
export const addWalletFunds = (id: number, amount: number) => 
  fetchApi<any>(`/wallets/${id}/add-funds`, { method: 'POST', body: JSON.stringify({ amount }) });
export const blockWallet = (id: number, reason: string) => 
  fetchApi<any>(`/wallets/${id}/block`, { method: 'POST', body: JSON.stringify({ reason }) });

// Reports
export const getReports = () => fetchApi<any>('/reports/');
export const refreshReports = () => fetchApi<any>('/reports/refresh', { method: 'POST' });
