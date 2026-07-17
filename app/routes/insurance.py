from flask import Blueprint, request, jsonify
from app.services.insurance_service import get_all_insurance, search_insurance, renew_insurance

insurance_bp = Blueprint('insurance', __name__)

@insurance_bp.route('/', methods=['GET'])
def list():
    query = request.args.get('q', '')
    if query:
        insurances = search_insurance(query)
    else:
        insurances = get_all_insurance()
    return jsonify({
        'query': query,
        'insurances': insurances
    })

@insurance_bp.route('/renew', methods=['POST'])
def renew():
    data = request.json
    success, message = renew_insurance(data)
    
    if success:
        return jsonify({'message': message}), 200
    else:
        return jsonify({'error': message}), 400
