# -*- coding: utf-8 -*-
"""
Seahub Extra Settings - OAuth/Authentik Configuration
This file is automatically loaded by Seafile after seahub_settings.py
Only settings that DIFFER from defaults are set here.
"""
import os

# =============================================================================
# Authentik OAuth Settings
# =============================================================================

ENABLE_OAUTH = True

def _read_secret(secret_name, default=''):
    """Read a Docker secret from /run/secrets/"""
    secret_path = f'/run/secrets/{secret_name}'
    try:
        with open(secret_path, 'r') as f:
            return f.read().strip()
    except FileNotFoundError:
        return default

OAUTH_CLIENT_ID = _read_secret('OAUTH_CLIENT_ID')
OAUTH_CLIENT_SECRET = _read_secret('OAUTH_CLIENT_SECRET')

_oauth_provider_domain = os.environ.get('OAUTH_PROVIDER_DOMAIN', 'https://authentik.example.com')
_seafile_protocol = os.environ.get('SEAFILE_SERVER_PROTOCOL', 'https')
_seafile_hostname = os.environ.get('SEAFILE_SERVER_HOSTNAME', 'seafile.example.com')
_seafile_url = f'{_seafile_protocol}://{_seafile_hostname}'

OAUTH_REDIRECT_URL = f'{_seafile_url}/oauth/callback/'
OAUTH_PROVIDER = 'authentik'
OAUTH_PROVIDER_DOMAIN = _oauth_provider_domain
OAUTH_AUTHORIZATION_URL = f'{_oauth_provider_domain}/application/o/authorize/'
OAUTH_TOKEN_URL = f'{_oauth_provider_domain}/application/o/token/'
OAUTH_USER_INFO_URL = f'{_oauth_provider_domain}/application/o/userinfo/'
OAUTH_SCOPE = ["openid", "profile", "email"]

OAUTH_ATTRIBUTE_MAP = {
    "sub": (True, "uid"),
    "email": (True, "contact_email"),
    "name": (False, "name"),
}

# =============================================================================
# SSO Login Settings
# =============================================================================

# Redirect to OAuth login page directly
LOGIN_URL = f'{_seafile_url}/oauth/login/'

# Desktop/Drive client SSO via system browser (supports hardware 2FA)
CLIENT_SSO_VIA_LOCAL_BROWSER = True

# Disable email/password login completely - SSO only (since 11.0.7)
DISABLE_ADFS_USER_PWD_LOGIN = True

# App-specific passwords for WebDAV/desktop clients (required with SSO-only)
ENABLE_APP_SPECIFIC_PASSWORD = True

# =============================================================================
# Access Control & Privacy
# =============================================================================

# Users can't see other users (default: True)
ENABLE_GLOBAL_ADDRESSBOOK = False

# Hide organization tab and global user list (default: False)
CLOUD_MODE = True

# =============================================================================
# Session Security
# =============================================================================

# Session expires when browser closes (default: False)
SESSION_EXPIRE_AT_BROWSER_CLOSE = True

# Max session lifetime for tabs that stay open (default: 2 weeks)
SESSION_COOKIE_AGE = 86400  # 24 hours

# Extend session on every request while user is active (default: False)
SESSION_SAVE_EVERY_REQUEST = True

# =============================================================================
# Login Security
# =============================================================================

# Freeze user account after too many failed attempts (default: False)
FREEZE_USER_ON_LOGIN_FAILED = True

# =============================================================================
# Password Policy (defense-in-depth for local admin accounts)
# =============================================================================

# Minimum password length (default: 6)
USER_PASSWORD_MIN_LENGTH = 12

# Require all 4 character types: uppercase, lowercase, digits, special (default: 3)
USER_PASSWORD_STRENGTH_LEVEL = 4

# Enforce complexity requirements (default: False)
USER_STRONG_PASSWORD_REQUIRED = True

# =============================================================================
# Share Link Security
# =============================================================================

# Force password on all share links (default: False)
SHARE_LINK_FORCE_USE_PASSWORD = True

# Minimum password length for share links (default: 8)
SHARE_LINK_PASSWORD_MIN_LENGTH = 10

# Maximum expiration days for share links (default: 0 = no limit)
SHARE_LINK_EXPIRE_DAYS_MAX = 90

# =============================================================================
# CSRF & Cookie Security
# =============================================================================

# CSRF trusted origins (required for Django 4.0+ with HTTPS)
CSRF_TRUSTED_ORIGINS = [f'{_seafile_protocol}://{_seafile_hostname}']

# Secure cookies - HTTPS only (default: False)
CSRF_COOKIE_SECURE = True
SESSION_COOKIE_SECURE = True

# =============================================================================
# Django Security
# =============================================================================

# Prevent HTTP Host header attacks (required for production)
ALLOWED_HOSTS = [_seafile_hostname]

# =============================================================================
# Upload & Download Limits
# =============================================================================

# Max upload file size in MB (default: 0 = unlimited)
MAX_UPLOAD_FILE_SIZE = int(os.environ.get('MAX_UPLOAD_FILE_SIZE', 0))

# Max number of files per upload (default: 1000)
MAX_NUMBER_OF_FILES_FOR_FILEUPLOAD = int(os.environ.get('MAX_NUMBER_OF_FILES_FOR_FILEUPLOAD', 500))

# =============================================================================
# Encrypted Libraries
# =============================================================================

# Minimum password length for encrypted libraries (default: 8)
REPO_PASSWORD_MIN_LENGTH = 12

# Use strongest encryption version (default: 2)
ENCRYPTED_LIBRARY_VERSION = 4

# =============================================================================
# File Locking
# =============================================================================

# Auto-unlock files after X days (default: 0 = never)
FILE_LOCK_EXPIRATION_DAYS = 7

# =============================================================================
# Admin
# =============================================================================

# Config-as-Code: disable settings changes via web UI (default: True)
ENABLE_SETTINGS_VIA_WEB = False
