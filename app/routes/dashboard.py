from flask import Blueprint, jsonify
from app.services.dashboard_service import get_dashboard_stats, get_fuel_distribution

dashboard_bp = Blueprint('dashboard', __name__)

@dashboard_bp.route('/', methods=['GET'])
def index():
    stats = get_dashboard_stats()
    fuel_dist = get_fuel_distribution()
    return jsonify({
        'stats': stats,
        'fuel_distribution': fuel_dist
    })
