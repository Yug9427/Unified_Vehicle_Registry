from flask import Flask
from flask_cors import CORS
from .config import Config
from .db import init_db_pool

def create_app():
    app = Flask(__name__)
    CORS(app)
    app.config.from_object(Config)
    
    # Initialize database connection pool
    init_db_pool()
    
    # Import and register blueprints
    from .routes.dashboard import dashboard_bp
    from .routes.vehicles import vehicles_bp
    from .routes.owners import owners_bp
    from .routes.ownership import ownership_bp
    from .routes.licenses import licenses_bp
    from .routes.insurance import insurance_bp
    from .routes.permits import permits_bp
    from .routes.challans import challans_bp
    from .routes.wallets import wallets_bp
    from .routes.reports import reports_bp
    
    app.register_blueprint(dashboard_bp, url_prefix='/api/dashboard')
    app.register_blueprint(vehicles_bp, url_prefix='/api/vehicles')
    app.register_blueprint(owners_bp, url_prefix='/api/owners')
    app.register_blueprint(ownership_bp, url_prefix='/api/ownership')
    app.register_blueprint(licenses_bp, url_prefix='/api/licenses')
    app.register_blueprint(insurance_bp, url_prefix='/api/insurance')
    app.register_blueprint(permits_bp, url_prefix='/api/permits')
    app.register_blueprint(challans_bp, url_prefix='/api/challans')
    app.register_blueprint(wallets_bp, url_prefix='/api/wallets')
    app.register_blueprint(reports_bp, url_prefix='/api/reports')
    
    return app
