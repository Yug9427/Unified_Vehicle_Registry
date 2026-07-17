from app.db import execute_query, execute_one, execute_procedure
import psycopg

def get_all_challans(filter_status=None):
    """Gets all challans, optionally filtered by status (paid/unpaid)."""
    query = """
        SELECT c.challan_id, c.vehicle_id, v.model_name, c.reason, c.amount, 
               c.challan_date, c.location, c.is_paid, o.name as officer_name
        FROM challan c
        JOIN vehicle v ON c.vehicle_id = v.vehicle_id
        JOIN officer o ON c.issuing_officer_id = o.officer_id
    """
    if filter_status == 'paid':
        query += " WHERE c.is_paid = TRUE"
    elif filter_status == 'unpaid':
        query += " WHERE c.is_paid = FALSE"
        
    query += " ORDER BY c.challan_date DESC"
    return execute_query(query)

def search_challans(query):
    search_term = f"%{query}%"
    return execute_query("""
        SELECT c.challan_id, c.vehicle_id, v.model_name, c.reason, c.amount, 
               c.challan_date, c.location, c.is_paid, o.name as officer_name
        FROM challan c
        JOIN vehicle v ON c.vehicle_id = v.vehicle_id
        JOIN officer o ON c.issuing_officer_id = o.officer_id
        WHERE c.vehicle_id ILIKE %s OR v.model_name ILIKE %s OR c.reason ILIKE %s
        ORDER BY c.challan_date DESC
    """, (search_term, search_term, search_term))

def get_challan_detail(challan_id):
    """Gets detailed info for a single challan, including the current owner's wallet info."""
    return execute_one("""
        SELECT c.challan_id, c.vehicle_id, v.model_name, c.reason, c.amount, 
               c.challan_date, c.location, c.is_paid, o.name as officer_name,
               u.user_id as owner_id, 
               u.fname || ' ' || u.lname as owner_name,
               w.wallet_id, w.balance as wallet_balance, w.status as wallet_status
        FROM challan c
        JOIN vehicle v ON c.vehicle_id = v.vehicle_id
        JOIN officer o ON c.issuing_officer_id = o.officer_id
        LEFT JOIN ownership own ON c.vehicle_id = own.vehicle_id AND own.to_date IS NULL
        LEFT JOIN users u ON own.owner_id = u.user_id
        LEFT JOIN e_wallet w ON u.user_id = w.user_id
        WHERE c.challan_id = %s
    """, (challan_id,))

def issue_challan(data):
    """Issues a new challan using sp_issue_challan."""
    try:
        execute_procedure("sp_issue_challan", (
            data['vehicle_id'],
            data['officer_id'],
            data['amount'],
            data['reason'],
            data['location']
        ))
        return True, "Challan issued successfully."
    except psycopg.errors.RaiseException as e:
        return False, str(e).split('\n')[0]
    except Exception as e:
        return False, f"Failed to issue challan: {str(e)}"

def pay_challan(challan_id, wallet_id):
    """Pays a challan using sp_pay_challan_via_wallet."""
    try:
        execute_procedure("sp_pay_challan_via_wallet", (challan_id, wallet_id))
        return True, "Challan paid successfully."
    except psycopg.errors.RaiseException as e:
        return False, str(e).split('\n')[0]
    except Exception as e:
        return False, f"Payment failed: {str(e)}"
