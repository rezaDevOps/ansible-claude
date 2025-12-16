#!/usr/bin/env python3
"""
Simple Flask Application
Deployed and managed by Ansible
"""

from flask import Flask, jsonify, request
import os
import socket
import logging
from datetime import datetime

app = Flask(__name__)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


@app.route('/')
def home():
    """Home page endpoint"""
    return jsonify({
        'message': 'Hello from Flask on EC2!',
        'status': 'running',
        'timestamp': datetime.utcnow().isoformat(),
        'hostname': socket.gethostname()
    })


@app.route('/health')
def health():
    """Health check endpoint for monitoring"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat()
    }), 200


@app.route('/info')
def info():
    """Application information endpoint"""
    return jsonify({
        'app_name': 'Flask Demo Application',
        'version': '1.0.0',
        'python_version': os.sys.version,
        'hostname': socket.gethostname(),
        'environment': os.environ.get('FLASK_ENV', 'production')
    })


@app.route('/api/echo', methods=['POST'])
def echo():
    """Echo endpoint - returns posted JSON data"""
    try:
        data = request.get_json()
        logger.info(f"Received echo request: {data}")
        return jsonify({
            'echo': data,
            'timestamp': datetime.utcnow().isoformat()
        })
    except Exception as e:
        logger.error(f"Error processing echo request: {str(e)}")
        return jsonify({
            'error': 'Invalid JSON data'
        }), 400


@app.errorhandler(404)
def not_found(error):
    """Custom 404 handler"""
    return jsonify({
        'error': 'Not found',
        'message': 'The requested resource was not found on this server'
    }), 404


@app.errorhandler(500)
def internal_error(error):
    """Custom 500 handler"""
    logger.error(f"Internal server error: {str(error)}")
    return jsonify({
        'error': 'Internal server error',
        'message': 'An unexpected error occurred'
    }), 500


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    host = os.environ.get('HOST', '127.0.0.1')

    logger.info(f"Starting Flask application on {host}:{port}")

    # Run the application
    # In production, this is managed by systemd and gunicorn
    app.run(host=host, port=port, debug=False)
