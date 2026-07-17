from flask import Blueprint, request, jsonify
from app.services.owner_service import search_owners, get_owner_profile, get_owner_vehicles, get_owner_licenses, add_user

owners_bp = Blueprint('owners', __name__)

@owners_bp.route('/', methods=['GET'])
def list_owners():
    query = request.args.get('q', '')
    owners = search_owners(query)
    return jsonify({
        'query': query,
        'owners': owners
    })

@owners_bp.route('/<user_id>', methods=['GET'])
def detail(user_id):
    owner = get_owner_profile(user_id)
    if not owner:
        return jsonify({'error': 'Owner not found'}), 404
        
    vehicles = get_owner_vehicles(user_id)
    licenses = get_owner_licenses(user_id)
        
    return jsonify({
        'owner': owner,
        'vehicles': vehicles,
        'licenses': licenses
    })

@owners_bp.route('/', methods=['POST'])
def add():
    data = request.json
    success, message = add_user(data)
    
    if success:
        return jsonify({'message': message}), 201
    else:
        return jsonify({'error': message}), 400
