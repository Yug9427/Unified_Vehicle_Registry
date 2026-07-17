from flask import Blueprint, request, jsonify
from app.services.wallet_service import (
    get_all_wallets, search_wallets, get_wallet_detail, add_funds, block_wallet
)

wallets_bp = Blueprint('wallets', __name__)

@wallets_bp.route('/', methods=['GET'])
def list():
    query = request.args.get('q', '')
    if query:
        wallets = search_wallets(query)
    else:
        wallets = get_all_wallets()
    return jsonify({
        'query': query,
        'wallets': wallets
    })

@wallets_bp.route('/<int:wallet_id>', methods=['GET'])
def detail(wallet_id):
    wallet, transactions = get_wallet_detail(wallet_id)
    if not wallet:
        return jsonify({'error': 'Wallet not found'}), 404
        
    return jsonify({
        'wallet': wallet,
        'transactions': transactions
    })

@wallets_bp.route('/<int:wallet_id>/add-funds', methods=['POST'])
def add_funds_route(wallet_id):
    data = request.json
    amount = float(data.get('amount', 0))
    success, message = add_funds(wallet_id, amount)
    
    if success:
        return jsonify({'message': message}), 200
    else:
        return jsonify({'error': message}), 400

@wallets_bp.route('/<int:wallet_id>/block', methods=['POST'])
def block_route(wallet_id):
    data = request.json
    reason = data.get('reason', 'Blocked via administrative action')
    success, message = block_wallet(wallet_id, reason)
    
    if success:
        return jsonify({'message': message}), 200
    else:
        return jsonify({'error': message}), 400
