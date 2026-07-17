from flask import Blueprint, request, jsonify
from app.services.vehicle_service import search_vehicles, get_vehicle_profile, get_ownership_history, get_insurance_history, get_puc_history, get_permit_history, get_challans, register_vehicle

vehicles_bp = Blueprint('vehicles', __name__)

@vehicles_bp.route('/', methods=['GET'])
def search():
    query = request.args.get('q', '')
    vehicles = search_vehicles(query)
    return jsonify({
        'query': query,
        'vehicles': vehicles
    })

@vehicles_bp.route('/<vehicle_id>', methods=['GET'])
def detail(vehicle_id):
    vehicle = get_vehicle_profile(vehicle_id)
    if not vehicle:
        return jsonify({'error': 'Vehicle not found'}), 404
        
    owners = get_ownership_history(vehicle_id)
    insurances = get_insurance_history(vehicle_id)
    pucs = get_puc_history(vehicle_id)
    permits = get_permit_history(vehicle_id)
    challans = get_challans(vehicle_id)
        
    return jsonify({
        'vehicle': vehicle,
        'owners': owners,
        'insurances': insurances,
        'pucs': pucs,
        'permits': permits,
        'challans': challans
    })

@vehicles_bp.route('/', methods=['POST'])
def register():
    data = request.json
    success, message = register_vehicle(data)
    
    if success:
        return jsonify({'message': message}), 201
    else:
        return jsonify({'error': message}), 400
