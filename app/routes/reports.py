from flask import Blueprint, jsonify
from app.services.report_service import (
    refresh_materialized_views, get_compliance_summary, get_revenue_by_state,
    get_insurance_market_share, get_rto_statistics, get_top_defaulters, get_monthly_challan_trend
)

reports_bp = Blueprint('reports', __name__)

@reports_bp.route('/', methods=['GET'])
def index():
    compliance = get_compliance_summary()
    revenue = get_revenue_by_state()
    insurance = get_insurance_market_share()
    rto = get_rto_statistics()
    defaulters = get_top_defaulters()
    trend = get_monthly_challan_trend()
    
    return jsonify({
        'compliance': compliance,
        'revenue': revenue,
        'insurance': insurance,
        'rto': rto,
        'defaulters': defaulters,
        'trend': trend
    })

@reports_bp.route('/refresh', methods=['POST'])
def refresh():
    try:
        refresh_materialized_views()
        return jsonify({'message': 'All materialized views have been refreshed successfully.'}), 200
    except Exception as e:
        return jsonify({'error': f'Error refreshing views: {str(e)}'}), 500
