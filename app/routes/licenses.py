from flask import Blueprint, request, jsonify
from app.services.license_service import get_all_licenses, search_licenses, issue_license

licenses_bp = Blueprint('licenses', __name__)

@licenses_bp.route('/', methods=['GET'])
def list():
    query = request.args.get('q', '')
    if query:
        licenses = search_licenses(query)
    else:
        licenses = get_all_licenses()
    return jsonify({
        'query': query,
        'licenses': licenses
    })

@licenses_bp.route('/', methods=['POST'])
def issue():
    data = request.json
    success, message = issue_license(data)
    
    if success:
        return jsonify({'message': message}), 201
    else:
        return jsonify({'error': message}), 400
