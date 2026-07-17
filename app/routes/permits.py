from flask import Blueprint, request, jsonify
from app.services.permit_service import get_all_permits, search_permits, issue_permit

permits_bp = Blueprint('permits', __name__)

@permits_bp.route('/', methods=['GET'])
def list():
    query = request.args.get('q', '')
    if query:
        permits = search_permits(query)
    else:
        permits = get_all_permits()
    return jsonify({
        'query': query,
        'permits': permits
    })

@permits_bp.route('/', methods=['POST'])
def issue():
    data = request.json
    success, message = issue_permit(data)
    
    if success:
        return jsonify({'message': message}), 201
    else:
        return jsonify({'error': message}), 400
