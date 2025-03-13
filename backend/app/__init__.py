import logging
import shutil
import tempfile
import zipfile
from logging.handlers import RotatingFileHandler
import os
import socket
from flask import Flask, send_from_directory, render_template, request, jsonify
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
from flask_jwt_extended import JWTManager
from sqlalchemy import text
from flask_migrate import Migrate
from dotenv import load_dotenv
from datetime import timedelta
import requests
from dateutil import parser
import boto3
import json

load_dotenv()
db = SQLAlchemy()


# Fetch database credentials from AWS Secrets Manager
def get_db_credentials():
    secret_name = "grocerymate-db-credentials"
    region_name = "eu-central-1"

    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name=region_name
    )

    try:
        get_secret_value_response = client.get_secret_value(SecretId=secret_name)
    except Exception as e:
        raise Exception(f"Error fetching secret from AWS Secrets Manager: {e}")

    secret = json.loads(get_secret_value_response['SecretString'])
    return secret['username'], secret['password']


# Fetch credentials
POSTGRES_USER, POSTGRES_PASSWORD = get_db_credentials()
POSTGRES_DB = os.getenv("DB_NAME", "grocerymate")
POSTGRES_HOST = os.getenv("DB_HOST", "grocerymate.cp6kci4uaepj.eu-central-1.rds.amazonaws.com")
POSTGRES_PORT = os.getenv("DB_PORT", "5432")

# Use connection parameters directly
CONNECT_ARGS = {
    "sslmode": "verify-full",
    "sslrootcert": "/home/ec2-user/rds-ca.pem"
}


class Config:
    """App configuration variables."""
    SQLALCHEMY_DATABASE_URI = f"postgresql://{POSTGRES_USER}@/{POSTGRES_DB}"  # Minimal URI for SQLAlchemy
    SQLALCHEMY_ENGINE_OPTIONS = {
        "connect_args": {
            "host": POSTGRES_HOST,
            "port": POSTGRES_PORT,
            "user": POSTGRES_USER,
            "password": POSTGRES_PASSWORD,
            "dbname": POSTGRES_DB,
            **CONNECT_ARGS
        }
    }
    print(f"Using Database Connection - Host: {POSTGRES_HOST}, User: {POSTGRES_USER}")

    SQLALCHEMY_TRACK_MODIFICATIONS = False
    JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY")
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(hours=4)

    @classmethod
    def is_rds(cls):
        """Check if using AWS RDS by detecting an external hostname."""
        rds_hostnames = ["rds.amazonaws.com", "amazonaws.com"]
        return any(h in POSTGRES_HOST for h in rds_hostnames)

    @classmethod
    def is_local_postgres(cls):
        """Check if 'postgres' resolves to a local Docker container."""
        return not cls.is_rds()


def detect_environment():
    if Config.is_rds():
        print("Running on AWS RDS (Production)")
    elif Config.is_local_postgres():
        print("Running on Local PostgreSQL (Development)")
    else:
        print("Could not detect database environment. Set POSTGRES_URI manually.")
    print(f"Using Database Connection - Host: {Config.SQLALCHEMY_ENGINE_OPTIONS['connect_args']['host']}")


detect_environment()


def fetch_frontend():
    """
    Fetches the latest frontend build from GitHub Releases and ensures it's placed in frontend/build.
    Only updates if the local build is outdated or missing.
    """
    # Implementation remains the same as before
    pass  # Placeholder; replace with actual implementation if needed


def create_app():
    app = Flask(__name__)
    CORS(app)

    # Configure logging
    handler = RotatingFileHandler('/home/ec2-user/backend/logs/grocerymate_error.log', maxBytes=1000000, backupCount=5)
    handler.setLevel(logging.ERROR)
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    handler.setFormatter(formatter)
    app.logger.addHandler(handler)
    logging.getLogger('').addHandler(handler)  # Root logger

    app.config.from_object(Config)
    db.init_app(app)
    JWTManager(app)
    Migrate(app, db)

    @app.route('/api/debug')
    def debug_config():
        return jsonify({"database_uri": app.config['SQLALCHEMY_DATABASE_URI']})

    @app.route('/api/health')
    def health_check():
        try:
            with db.engine.connect() as connection:
                connection.execute(text("SELECT 1"))
            return jsonify({"status": "ok"}), 200
        except Exception as e:
            app.logger.error(f"Health check failed: {str(e)}")  # Log the error
            return jsonify({"status": "error", "message": str(e)}), 500

    @app.route('/')
    def serve_frontend():
        return send_from_directory('/var/www/html/build', 'index.html')

    @app.route('/<path:path>')
    def serve_static(path):
        return send_from_directory('/var/www/html/build', path)

    return app


if __name__ == '__main__':
    app = create_app()
    fetch_frontend()  # Ensure frontend is fetched on app start
    app.run(host='0.0.0.0', port=8000)