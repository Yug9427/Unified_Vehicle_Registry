from app.db import execute_query, execute_one, execute_procedure
import psycopg

def get_all_insurance():
    return execute_query("""
        SELECT i.policy_id, i.vehicle_id, v.model_name, i.insurance_company,
               i.insurance_type, i.issue_date, i.expiry_date,
               i.coverage_amount, i.premium_amount, i.policy_status
        FROM v_insurance_status i
        JOIN vehicle v ON i.vehicle_id = v.vehicle_id
        ORDER BY i.expiry_date DESC
    """)

def search_insurance(query):
    search_term = f"%{query}%"
    return execute_query("""
        SELECT i.policy_id, i.vehicle_id, v.model_name, i.insurance_company,
               i.insurance_type, i.issue_date, i.expiry_date,
               i.coverage_amount, i.premium_amount, i.policy_status
        FROM v_insurance_status i
        JOIN vehicle v ON i.vehicle_id = v.vehicle_id
        WHERE i.policy_id ILIKE %s OR i.vehicle_id ILIKE %s OR v.model_name ILIKE %s
        ORDER BY i.expiry_date DESC
    """, (search_term, search_term, search_term))

def renew_insurance(data):
    """Renews insurance by calling sp_renew_insurance."""
    try:
        # Check if vehicle exists
        if not execute_one("SELECT 1 FROM vehicle WHERE vehicle_id = %s", (data['vehicle_id'],)):
            return False, "Vehicle ID not found."
            
        # Call stored procedure
        execute_procedure("sp_renew_insurance", (
            data['vehicle_id'],
            data['policy_id'],
            data['insurance_company'],
            data['insurance_type'],
            data['coverage_amount'],
            data['premium_amount'],
            int(data['validity_years']) * 12
        ))
        return True, "Insurance renewed successfully."
    except psycopg.errors.RaiseException as e:
        return False, str(e).split('\n')[0]
    except Exception as e:
        return False, f"Failed to renew insurance: {str(e)}"
