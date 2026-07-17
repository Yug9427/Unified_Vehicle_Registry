from app.db import execute_query, execute_one, execute_write

def search_owners(query):
    """Searches for users/owners by Aadhaar ID, name, or phone."""
    search_term = f"%{query}%"
    return execute_query("""
        SELECT u.user_id, u.fname || COALESCE(' ' || u.mname, '') || COALESCE(' ' || u.lname, '') AS full_name,
               u.phone_number, u.city,
               (SELECT COUNT(DISTINCT vehicle_id) FROM ownership WHERE owner_id = u.user_id AND to_date IS NULL) AS current_vehicles,
               ew.balance AS wallet_balance, ew.status as wallet_status
        FROM users u
        LEFT JOIN e_wallet ew ON u.user_id = ew.user_id
        WHERE u.user_id ILIKE %s
           OR (u.fname || COALESCE(' ' || u.mname, '') || COALESCE(' ' || u.lname, '')) ILIKE %s
           OR u.phone_number ILIKE %s
        ORDER BY u.fname, u.lname
        LIMIT 50
    """, (search_term, search_term, search_term))

def get_owner_profile(user_id):
    """Gets complete user profile (Q28)."""
    return execute_one("""
        SELECT
            u.user_id,
            u.fname || COALESCE(' ' || u.mname, '') || COALESCE(' ' || u.lname, '') AS full_name,
            u.dob, EXTRACT(YEAR FROM AGE(CURRENT_DATE, u.dob))::int AS age,
            u.gender, u.blood_group, u.email, u.phone_number,
            u.street || ', ' || u.city || ', ' || u.state || ' - ' || u.pincode AS full_address,
            ew.wallet_id, ew.balance AS wallet_balance, ew.status AS wallet_status,
            (SELECT COUNT(DISTINCT vehicle_id) FROM ownership WHERE owner_id = u.user_id AND to_date IS NULL) AS current_vehicles,
            (SELECT COUNT(DISTINCT vehicle_id) FROM ownership WHERE owner_id = u.user_id) AS total_vehicles_ever
        FROM users u
        LEFT JOIN e_wallet ew ON u.user_id = ew.user_id
        WHERE u.user_id = %s
    """, (user_id,))

def get_owner_vehicles(user_id):
    """Gets vehicles currently and previously owned by the user."""
    return execute_query("""
        SELECT v.vehicle_id, v.model_name, rc.registration_no,
               o.from_date, o.to_date,
               CASE WHEN o.to_date IS NULL THEN 'Current' ELSE 'Past' END AS status
        FROM ownership o
        JOIN vehicle v ON o.vehicle_id = v.vehicle_id
        LEFT JOIN rc_book rc ON v.vehicle_id = rc.vehicle_id
        WHERE o.owner_id = %s
        ORDER BY o.from_date DESC
    """, (user_id,))

def get_owner_licenses(user_id):
    return execute_query("""
        SELECT l.license_no, l.license_type, l.vehicle_class, l.issue_date, l.expiry_date,
               CASE 
                   WHEN l.status = 'Revoked' THEN 'Revoked'
                   WHEN l.status = 'Suspended' THEN 'Suspended'
                   WHEN l.expiry_date < CURRENT_DATE THEN 'Expired'
                   ELSE 'Active'
               END AS effective_status
        FROM license l
        WHERE l.user_id = %s
        ORDER BY l.issue_date DESC
    """, (user_id,))

def hash_password(plain_password):
    """Hashes a password using MD5 with pbkdf2$ prefix, matching the Insert_data.sql scheme."""
    import hashlib
    hashed = hashlib.md5(plain_password.encode()).hexdigest()
    return f"pbkdf2${hashed}"

def add_user(data):
    """Adds a new user and creates an initial wallet."""
    try:
        from app.db import pool
        hashed_pw = hash_password(data['password'])
        with pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO users (user_id, password, fname, mname, lname, dob, gender, 
                                       blood_group, email, phone_number, street, city, state, pincode)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                """, (
                    data['user_id'], hashed_pw, data['fname'], data.get('mname'), data.get('lname'),
                    data['dob'], data.get('gender'), data.get('blood_group'), data.get('email'), 
                    data['phone_number'], data.get('street'), data.get('city'), data.get('state'), data.get('pincode')
                ))
                
                # Auto-create wallet
                cur.execute("""
                    INSERT INTO e_wallet (user_id, balance, status)
                    VALUES (%s, 0, 'Active')
                """, (data['user_id'],))
                
            conn.commit()
        return True, "User created successfully."
    except Exception as e:
        return False, f"Failed to create user: {str(e)}"

