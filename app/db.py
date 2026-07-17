import psycopg
from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool
from .config import Config

# Initialize connection pool
pool = ConnectionPool(conninfo=Config.get_db_conn_info(), open=False)

def init_db_pool():
    """Opens the connection pool. Called during app initialization."""
    try:
        pool.open()
        print("Database connection pool initialized successfully.")
    except Exception as e:
        print(f"Error initializing database connection pool: {e}")

def get_db_connection():
    """Context manager for getting a database connection from the pool."""
    return pool.connection()

def execute_query(sql, params=None):
    """Executes a SELECT query and returns a list of dictionaries."""
    with pool.connection() as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            cur.execute(sql, params)
            return cur.fetchall()

def execute_one(sql, params=None):
    """Executes a SELECT query and returns a single dictionary or None."""
    with pool.connection() as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            cur.execute(sql, params)
            return cur.fetchone()

def execute_write(sql, params=None):
    """Executes an INSERT, UPDATE, or DELETE query and commits."""
    with pool.connection() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, params)
            conn.commit()
            return cur.rowcount

def execute_procedure(proc_name, params=None):
    """Calls a stored procedure."""
    # Build the CALL statement dynamically based on params length
    if params:
        placeholders = ', '.join(['%s'] * len(params))
        sql = f"CALL {proc_name}({placeholders})"
    else:
        sql = f"CALL {proc_name}()"
        
    with pool.connection() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, params)
            conn.commit()

def execute_scalar(sql, params=None):
    """Executes a query that returns a single scalar value."""
    with pool.connection() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, params)
            result = cur.fetchone()
            if result:
                return result[0]
            return None
