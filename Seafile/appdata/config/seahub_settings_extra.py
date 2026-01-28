# -*- coding: utf-8 -*-
"""
Seahub Extra Settings - OAuth/Authentik Configuration
This file is automatically loaded by Seafile after seahub_settings.py
"""
import os

# =============================================================================
# Authentik OAuth Settings
# =============================================================================

# Enable OAuth authentication
ENABLE_OAUTH = True

# User creation and activation policies
OAUTH_CREATE_UNKNOWN_USER = True      # Create user on first login
OAUTH_ACTIVATE_USER_AFTER_CREATION = True  # Auto-activate new users

# OAuth Client Credentials (loaded from Docker secrets)
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

# OAuth URLs - constructed from environment variables
_oauth_provider_domain = os.environ.get('OAUTH_PROVIDER_DOMAIN', 'https://authentik.example.com')
_seafile_url = f"{os.environ.get('SEAFILE_SERVER_PROTOCOL', 'https')}://{os.environ.get('SEAFILE_SERVER_HOSTNAME', 'seafile.example.com')}"

OAUTH_REDIRECT_URL = f'{_seafile_url}/oauth/callback/'

# Authentik Provider Configuration
OAUTH_PROVIDER = 'authentik'
OAUTH_PROVIDER_DOMAIN = _oauth_provider_domain
OAUTH_AUTHORIZATION_URL = f'{_oauth_provider_domain}/application/o/authorize/'
OAUTH_TOKEN_URL = f'{_oauth_provider_domain}/application/o/token/'
OAUTH_USER_INFO_URL = f'{_oauth_provider_domain}/application/o/userinfo/'

# OAuth Scopes
OAUTH_SCOPE = ["openid", "profile", "email"]

# Attribute mapping from OAuth provider to Seafile
OAUTH_ATTRIBUTE_MAP = {
    "email": (True, "email"),   # Required: email address
    "name": (False, "name"),    # Optional: display name
    "sub": (False, "uid"),      # Optional: unique identifier
}

# =============================================================================
# SSO Login Settings
# =============================================================================

# Redirect to OAuth login page (comment out to show both login options)
LOGIN_URL = f'{_seafile_url}/oauth/login/'

# Enable system browser for SSO (supports hardware 2FA)
# Requires: Seafile 11.0.0+, sync client 9.0.5+, drive client 3.0.8+
CLIENT_SSO_VIA_LOCAL_BROWSER = True

# Force SSO login - disable email/password login completely (since 11.0.7)
# Users can ONLY login via OAuth/Authentik
DISABLE_ADFS_USER_PWD_LOGIN = True

# =============================================================================
# User Registration & Access Control
# =============================================================================

# Disable self-registration (users created only via OAuth or admin)
ENABLE_SIGNUP = False

# Disable global address book (users can't see other users)
ENABLE_GLOBAL_ADDRESSBOOK = False

# =============================================================================
# Session Security
# =============================================================================

# Session expires when browser closes
SESSION_EXPIRE_AT_BROWSER_CLOSE = True

# Session cookie age in seconds (default: 2 weeks = 1209600)
# SESSION_COOKIE_AGE = 86400  # 24 hours - uncomment to override

# Update session on every request (extends session while active)
SESSION_SAVE_EVERY_REQUEST = True

# =============================================================================
# Login Security
# =============================================================================

# Max failed login attempts before CAPTCHA (default: 3)
LOGIN_ATTEMPT_LIMIT = 5

# Freeze/deactivate user after too many failed attempts
FREEZE_USER_ON_LOGIN_FAILED = True

# =============================================================================
# Password Policy (for local users if any remain)
# =============================================================================

# Minimum password length
USER_PASSWORD_MIN_LENGTH = 12

# Password strength level (1-4, how many character types required)
# 3 = at least 3 of: uppercase, lowercase, digits, special chars
USER_PASSWORD_STRENGTH_LEVEL = 3

# Require strong passwords
USER_STRONG_PASSWORD_REQUIRED = True

# =============================================================================
# Share Link Security
# =============================================================================

# Force password on all share links
SHARE_LINK_FORCE_USE_PASSWORD = False  # Set True for stricter security

# Minimum password length for share links
SHARE_LINK_PASSWORD_MIN_LENGTH = 10

# Maximum expiration days for share links (0 = no limit)
SHARE_LINK_EXPIRE_DAYS_MAX = 90

# =============================================================================
# Two-Factor Authentication
# =============================================================================

# Disabled - 2FA is handled by Authentik SSO
# Enable only if you have local users that need Seafile-native 2FA
ENABLE_TWO_FACTOR_AUTH = False

# =============================================================================
# CSRF & Cookie Security
# =============================================================================

# CSRF Protection - Add your domain(s) here
# Django 4.0+ requires full URL with scheme (https://)
_seafile_protocol = os.environ.get('SEAFILE_SERVER_PROTOCOL', 'https')
_seafile_hostname = os.environ.get('SEAFILE_SERVER_HOSTNAME', 'seafile.example.com')
CSRF_TRUSTED_ORIGINS = [f'{_seafile_protocol}://{_seafile_hostname}']

# Secure cookies (requires HTTPS)
CSRF_COOKIE_SECURE = True
SESSION_COOKIE_SECURE = True

# SameSite cookie policy
CSRF_COOKIE_SAMESITE = 'Strict'
SESSION_COOKIE_SAMESITE = 'Lax'

# =============================================================================
# WebDAV / App Passwords
# =============================================================================

# Allow users to generate app-specific passwords for WebDAV, desktop clients, etc.
# Required when DISABLE_ADFS_USER_PWD_LOGIN is True
ENABLE_APP_SPECIFIC_PASSWORD = True

# =============================================================================
# Admin Settings
# =============================================================================

# Disable changing settings via web UI (use config files only)
# ENABLE_SETTINGS_VIA_WEB = False

# Allow admin to view unencrypted libraries (set False for privacy)
# ENABLE_SYS_ADMIN_VIEW_REPO = False
