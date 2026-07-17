from flask import Blueprint, request, jsonify
from app.services.ownership_service import transfer_ownership

ownership_bp = Blueprint('ownership', __name__)

@ownership_bp.route('/transfer', methods=['POST'])
def transfer():
    data = request.json
    success, message = transfer_ownership(data.get('vehicle_id'), data.get('new_owner_id'))
    
    if success:
        return jsonify({'message': message}), 200
    else:
        return jsonify({'error': message}), 400
