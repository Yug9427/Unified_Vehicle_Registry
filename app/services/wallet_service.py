from app.db import execute_query, execute_one, execute_write, execute_procedure
import psycopg

def get_all_wallets():
    """Gets all wallets and their balances."""
    return execute_query("""
        SELECT w.wallet_id, w.user_id,
               u.fname || COALESCE(' ' || u.mname, '') || COALESCE(' ' || u.lname, '') as owner_name,
               w.balance, w.status
        FROM e_wallet w
        JOIN users u ON w.user_id = u.user_id
        ORDER BY w.balance DESC
    """)

def search_wallets(query):
    search_term = f"%{query}%"
    return execute_query("""
        SELECT w.wallet_id, w.user_id,
               u.fname || COALESCE(' ' || u.mname, '') || COALESCE(' ' || u.lname, '') as owner_name,
               w.balance, w.status
        FROM e_wallet w
        JOIN users u ON w.user_id = u.user_id
        WHERE w.wallet_id::text ILIKE %s
           OR w.user_id ILIKE %s
           OR (u.fname || COALESCE(' ' || u.mname, '') || COALESCE(' ' || u.lname, '')) ILIKE %s
        ORDER BY w.balance DESC
    """, (search_term, search_term, search_term))

def get_wallet_detail(wallet_id):
    """Gets wallet details and transaction history."""
    wallet = execute_one("""
        SELECT w.wallet_id, w.user_id,
               u.fname || COALESCE(' ' || u.mname, '') || COALESCE(' ' || u.lname, '') as owner_name,
               w.balance, w.status
        FROM e_wallet w
        JOIN users u ON w.user_id = u.user_id
        WHERE w.wallet_id = %s
    """, (wallet_id,))
    
    if not wallet:
        return None, []
        
    transactions = execute_query("""
        SELECT transaction_id, 
               from_wallet_id, 
               to_wallet_id,
               CASE WHEN to_wallet_id = %s THEN 'Credit' ELSE 'Debit' END AS direction,
               amount, 
               purpose, 
               tran_datetime, 
               status
        FROM wallet_transaction
        WHERE from_wallet_id = %s OR to_wallet_id = %s
        ORDER BY tran_datetime DESC
    """, (wallet_id, wallet_id, wallet_id))
    
    return wallet, transactions

def add_funds(wallet_id, amount):
    """Adds funds by directly crediting the wallet balance (admin top-up)."""
    try:
        if amount <= 0:
            return False, "Amount must be greater than zero."
            
        rows = execute_write("""
            UPDATE e_wallet SET balance = balance + %s
            WHERE wallet_id = %s AND status = 'Active'
        """, (amount, wallet_id))
        if rows == 0:
            return False, "Wallet not found or not active."
        return True, "Funds added successfully."
    except Exception as e:
        return False, f"Failed to add funds: {str(e)}"

def block_wallet(wallet_id, reason):
    """Blocks a wallet using sp_block_wallet."""
    try:
        execute_procedure("sp_block_wallet", (wallet_id, reason))
        return True, "Wallet blocked successfully."
    except Exception as e:
        return False, f"Failed to block wallet: {str(e)}"
