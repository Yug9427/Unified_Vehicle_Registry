from flask import Blueprint, request, jsonify
from app.services.challan_service import (
    get_all_challans, search_challans, get_challan_detail, issue_challan, pay_challan
)

challans_bp = Blueprint('challans', __name__)

@challans_bp.route('/', methods=['GET'])
def list():
    query = request.args.get('q', '')
    filter_status = request.args.get('status', 'all')
    
    if query:
        challans_list = search_challans(query)
    else:
        status_arg = filter_status if filter_status in ('paid', 'unpaid') else None
        challans_list = get_all_challans(status_arg)
        
    return jsonify({
        'query': query,
        'filter_status': filter_status,
        'challans': challans_list
    })

@challans_bp.route('/<int:challan_id>', methods=['GET'])
def detail(challan_id):
    challan = get_challan_detail(challan_id)
    if not challan:
        return jsonify({'error': 'Challan not found'}), 404
    return jsonify(challan)

@challans_bp.route('/', methods=['POST'])
def issue():
    data = request.json
    success, message = issue_challan(data)
    
    if success:
        return jsonify({'message': message}), 201
    else:
        return jsonify({'error': message}), 400

@challans_bp.route('/<int:challan_id>/pay', methods=['POST'])
def pay(challan_id):
    # Fetch challan detail to get wallet_id
    challan = get_challan_detail(challan_id)
    if not challan:
        return jsonify({'error': 'Challan not found'}), 404
        
    if challan['is_paid']:
        return jsonify({'message': 'Challan is already paid'}), 400
        
    if not challan.get('wallet_id'):
        return jsonify({'error': 'Current owner has no wallet linked to this challan.'}), 400
        
    success, message = pay_challan(challan_id, challan['wallet_id'])
    if success:
        return jsonify({'message': message}), 200
    else:
        return jsonify({'error': message}), 400
