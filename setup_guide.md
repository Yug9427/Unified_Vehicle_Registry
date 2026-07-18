# Setup Guide — Unified Vehicle Registry

This guide walks you through setting up the full-stack **Unified Vehicle Registry** application on your local machine.

---

## Prerequisites

Make sure the following are installed before you begin:

| Tool | Version | Purpose |
|------|---------|---------|
| **Python** | 3.10+ | Flask backend runtime |
| **Node.js** | 18+ | Vite/React frontend tooling |
| **npm** | 9+ | Frontend package management |
| **PostgreSQL** | 14+ | Relational database |

> [!TIP]
> On macOS you can install PostgreSQL with Homebrew:
> ```bash
> brew install postgresql@16
> brew services start postgresql@16
> ```

---

## 1. Clone the Repository

```bash
git clone <your-repo-url>
cd DBMS_Project
```

---

## 2. Database Setup

### 2.1 Create the database

Open a PostgreSQL shell (`psql`) and create a fresh database:

```sql
CREATE DATABASE unified_vehicle_registry;
```

### 2.2 Run the SQL scripts (in order)

The `SQL/` directory contains numbered scripts that must be executed sequentially:

```bash
psql -d unified_vehicle_registry -f SQL/01_DDL.sql
psql -d unified_vehicle_registry -f SQL/02_Insert_data.sql
psql -d unified_vehicle_registry -f SQL/03_Queries.sql
psql -d unified_vehicle_registry -f SQL/04_Indexes.sql
psql -d unified_vehicle_registry -f SQL/05_Triggers.sql
psql -d unified_vehicle_registry -f SQL/06_Procedures_Functions.sql
psql -d unified_vehicle_registry -f SQL/07_Materialized_Views.sql
psql -d unified_vehicle_registry -f SQL/08_Advanced_Queries.sql
psql -d unified_vehicle_registry -f SQL/09_Cursors.sql
psql -d unified_vehicle_registry -f SQL/10_Transactions.sql
```

> [!IMPORTANT]
> **Script `01_DDL.sql` drops all existing tables and views before recreating them.** Do not run it on a database that contains data you want to keep.

---

## 3. Environment Configuration

Copy the example env file and fill in your values:

```bash
cp .env.example .env
```

Edit `.env` with your PostgreSQL credentials:

```env
DB_HOST=localhost
DB_PORT=5432
DB_NAME=unified_vehicle_registry
DB_USER=your_username
DB_PASSWORD=your_password
FLASK_APP=run.py
FLASK_DEBUG=1
SECRET_KEY=generate-a-random-secret-key
```

> [!NOTE]
> You can generate a secret key with:
> ```bash
> python3 -c "import secrets; print(secrets.token_hex(32))"
> ```

---

## 4. Backend Setup (Flask)

### 4.1 Create and activate a virtual environment

```bash
python3 -m venv venv
source venv/bin/activate      # macOS / Linux
# venv\Scripts\activate       # Windows
```

### 4.2 Install Python dependencies

```bash
pip install -r requirements.txt
```

### 4.3 Start the backend server

```bash
python run.py
```

The Flask API will be available at **http://127.0.0.1:5001**.

---

## 5. Frontend Setup (React + Vite)

### 5.1 Install Node dependencies

```bash
cd frontend
npm install
```

### 5.2 Start the development server

```bash
npm run dev
```

The frontend will be available at **http://localhost:5173** (default Vite port).

> [!NOTE]
> The Vite dev server is pre-configured to proxy all `/api/*` requests to the Flask backend at `http://127.0.0.1:5001`, so you don't need to worry about CORS during development.

---

## 6. Quick Start (Both Servers)

A convenience script is provided to start both servers at once:

```bash
chmod +x start.sh
./start.sh
```

This will:
1. Activate the Python virtual environment
2. Start the Flask backend on port **5001**
3. Start the Vite frontend dev server
4. Shut both down cleanly on `Ctrl+C`

---

## Project Structure

```
DBMS_Project/
├── app/                        # Flask backend
│   ├── __init__.py             # App factory & blueprint registration
│   ├── config.py               # Environment-based configuration
│   ├── db.py                   # psycopg connection pool & query helpers
│   ├── routes/                 # API route blueprints
│   │   ├── dashboard.py
│   │   ├── vehicles.py
│   │   ├── owners.py
│   │   ├── ownership.py
│   │   ├── licenses.py
│   │   ├── insurance.py
│   │   ├── permits.py
│   │   ├── challans.py
│   │   ├── wallets.py
│   │   └── reports.py
│   └── services/               # Business logic layer
├── frontend/                   # React + Vite + Tailwind frontend
│   ├── src/
│   ├── package.json
│   └── vite.config.ts
├── SQL/                        # Database scripts (run in order)
│   ├── 01_DDL.sql              # Schema creation
│   ├── 02_Insert_data.sql      # Seed data
│   ├── 03_Queries.sql          # Sample queries
│   ├── 04_Indexes.sql          # Performance indexes
│   ├── 05_Triggers.sql         # Database triggers
│   ├── 06_Procedures_Functions.sql
│   ├── 07_Materialized_Views.sql
│   ├── 08_Advanced_Queries.sql
│   ├── 09_Cursors.sql
│   └── 10_Transactions.sql
├── Diagrams/                   # ER / schema diagrams
├── .env.example                # Environment template
├── requirements.txt            # Python dependencies
├── run.py                      # Backend entry point
└── start.sh                    # One-command launcher
```

---

## API Endpoints

All API routes are served under the `/api` prefix:

| Prefix | Module |
|--------|--------|
| `/api/dashboard` | Dashboard statistics |
| `/api/vehicles` | Vehicle CRUD |
| `/api/owners` | Owner/user management |
| `/api/ownership` | Ownership transfers |
| `/api/licenses` | License management |
| `/api/insurance` | Insurance policies |
| `/api/permits` | Transport permits |
| `/api/challans` | Traffic challans |
| `/api/wallets` | E-Wallet & transactions |
| `/api/reports` | Analytical reports |

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `psycopg` can't connect | Verify PostgreSQL is running and `.env` credentials are correct |
| Port 5001 already in use | Kill the existing process: `lsof -ti:5001 \| xargs kill` |
| `npm install` fails | Make sure Node.js ≥ 18 is installed (`node -v`) |
| SQL scripts fail | Run them in numeric order; `01_DDL.sql` must go first |
| Frontend can't reach API | Ensure the Flask backend is running on port 5001 |
