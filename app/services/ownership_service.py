from app.db import execute_procedure, execute_one
import psycopg

def transfer_ownership(vehicle_id, new_owner_id):
    """Transfers ownership of a vehicle by calling sp_transfer_vehicle_ownership."""
    try:
        # Check if vehicle exists
        if not execute_one("SELECT 1 FROM vehicle WHERE vehicle_id = %s", (vehicle_id,)):
            return False, "Vehicle ID not found."
            
        # Check if new owner exists
        if not execute_one("SELECT 1 FROM users WHERE user_id = %s", (new_owner_id,)):
            return False, "New Owner ID not found."
        # Fetch current owner
        current = execute_one(
            "SELECT owner_id FROM ownership WHERE vehicle_id = %s AND to_date IS NULL",
            (vehicle_id,)
        )
        if not current:
            return False, "This vehicle has no active owner to transfer from."
        old_owner_id = current['owner_id']
            
        # Call stored procedure
        execute_procedure("sp_transfer_vehicle_ownership", (vehicle_id, old_owner_id, new_owner_id))
        return True, "Ownership transferred successfully."
        
    except psycopg.errors.RaiseException as e:
        # Catch custom RAISE EXCEPTION from triggers or procedures
        return False, str(e).split('\n')[0]
    except Exception as e:
        return False, f"Transfer failed: {str(e)}"
