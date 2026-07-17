from app.db import execute_query, execute_one

def get_dashboard_stats():
    """Fetches high-level statistics for the dashboard."""
    stats = {}
    
    # Total Vehicles & Users
    stats['total_vehicles'] = execute_one("SELECT COUNT(*) as count FROM vehicle")['count']
    stats['total_users'] = execute_one("SELECT COUNT(*) as count FROM users")['count']
    
    # Active Insurance & Licenses
    stats['active_insurance'] = execute_one("SELECT COUNT(*) as count FROM insurance WHERE expiry_date >= CURRENT_DATE")['count']
    stats['active_licenses'] = execute_one("SELECT COUNT(*) as count FROM license WHERE status = 'Active' AND expiry_date >= CURRENT_DATE")['count']
    
    # Unpaid Challans (Count and Amount)
    unpaid_challans = execute_one("SELECT COUNT(*) as count, COALESCE(SUM(amount), 0) as total FROM challan WHERE is_paid = FALSE")
    stats['unpaid_challans_count'] = unpaid_challans['count']
    stats['unpaid_challans_amount'] = unpaid_challans['total']
    
    # Total Wallet Balance
    stats['total_wallet_balance'] = execute_one("SELECT COALESCE(SUM(balance), 0) as total FROM e_wallet WHERE status = 'Active'")['total']
    
    return stats

def get_fuel_distribution():
    """Fetches vehicle distribution by fuel type (Q21)"""
    return execute_query("""
        SELECT fuel_type, COUNT(*) as count 
        FROM vehicle 
        GROUP BY fuel_type 
        ORDER BY count DESC
    """)

def get_recent_challans():
    """Fetches 5 most recent challans."""
    return execute_query("""
        SELECT c.challan_id, c.vehicle_id, v.model_name, c.amount, c.challan_date, c.reason
        FROM challan c
        JOIN vehicle v ON c.vehicle_id = v.vehicle_id
        ORDER BY c.challan_date DESC, c.challan_id DESC
        LIMIT 5
    """)
