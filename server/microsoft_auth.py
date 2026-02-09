#!/usr/bin/env python3
"""
Microsoft OAuth authentication setup.
Run this once to authenticate and store the refresh token.
After this, microsoft_tools.py will use the refresh token automatically.
"""

import webbrowser
import requests
import json
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlencode, parse_qs, urlparse
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Azure AD configuration
TENANT_ID = "75c134e8-fab3-4579-9137-be61dce6b5d3"
CLIENT_ID = "7735546e-16e6-45a1-be7f-4d1968d8d5bb"
CLIENT_SECRET_PATH = "/Users/andreslaurito/.ssh/azure-openclaw-integration.txt"
REDIRECT_URI = "http://localhost:8080/callback"

# Scopes required for email and calendar access
SCOPES = "Mail.ReadWrite Mail.Send Calendars.ReadWrite offline_access"

# Global to store auth code from callback
auth_code = None
server = None


def _get_client_secret():
    """Load client secret from file."""
    try:
        with open(CLIENT_SECRET_PATH, 'r') as f:
            return f.read().strip()
    except FileNotFoundError:
        logger.error(f"Client secret not found at {CLIENT_SECRET_PATH}")
        raise


class CallbackHandler(BaseHTTPRequestHandler):
    """HTTP handler for OAuth callback."""
    
    def do_GET(self):
        global auth_code
        
        # Parse the callback URL
        parsed = urlparse(self.path)
        params = parse_qs(parsed.query)
        
        if 'code' in params:
            auth_code = params['code'][0]
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            response_html = """
                <html>
                <body>
                <h1>Authentication Successful!</h1>
                <p>You can close this window and return to the terminal.</p>
                </body>
                </html>
            """.encode('utf-8')
            self.wfile.write(response_html)
            logger.info("Authorization code received!")
        elif 'error' in params:
            error = params['error'][0]
            self.send_response(400)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            response_html = f"<h1>Error: {error}</h1>".encode('utf-8')
            self.wfile.write(response_html)
            logger.error(f"OAuth error: {error}")
        else:
            self.send_response(400)
            self.end_headers()
            logger.error("Callback received but no code or error found")
    
    def log_message(self, format, *args):
        """Suppress default logging."""
        pass


def authenticate():
    """Run the OAuth flow and save the token."""
    global auth_code, server
    
    try:
        client_secret = _get_client_secret()
        
        # Step 1: Generate authorization URL
        auth_url = f"https://login.microsoftonline.com/{TENANT_ID}/oauth2/v2.0/authorize"
        auth_params = {
            "client_id": CLIENT_ID,
            "redirect_uri": REDIRECT_URI,
            "response_type": "code",
            "scope": SCOPES,
            "prompt": "login"
        }
        auth_url_with_params = f"{auth_url}?{urlencode(auth_params)}"
        
        # Step 2: Start local server for callback
        server = HTTPServer(('localhost', 8080), CallbackHandler)
        logger.info("Starting local callback server on http://localhost:8080")
        
        # Step 3: Open browser for user to login
        logger.info("Opening browser for authentication...")
        webbrowser.open(auth_url_with_params)
        
        # Step 4: Wait for callback
        while auth_code is None:
            server.handle_request()
        
        logger.info("Got authorization code, exchanging for token...")
        
        # Step 5: Exchange code for token
        token_url = f"https://login.microsoftonline.com/{TENANT_ID}/oauth2/v2.0/token"
        token_payload = {
            "client_id": CLIENT_ID,
            "client_secret": client_secret,
            "code": auth_code,
            "redirect_uri": REDIRECT_URI,
            "grant_type": "authorization_code",
            "scope": "Mail.ReadWrite Mail.Send Calendars.ReadWrite offline_access"
        }
        
        response = requests.post(token_url, data=token_payload)
        response.raise_for_status()
        
        token_data = response.json()
        
        # Step 6: Save token
        with open("microsoft_token.json", 'w') as f:
            json.dump(token_data, f, indent=2)
        
        logger.info("✅ Authentication successful!")
        logger.info(f"Token saved to microsoft_token.json")
        logger.info(f"User: {token_data.get('id_token', 'N/A')}")
        
        print("\n" + "="*60)
        print("✅ Microsoft 365 Authentication Complete!")
        print("="*60)
        print(f"Token saved to: microsoft_token.json")
        print(f"Refresh token will be used automatically for subsequent calls.")
        print("="*60 + "\n")
        
        return True
    
    except Exception as e:
        logger.error(f"Authentication failed: {e}")
        print(f"\n❌ Authentication failed: {e}\n")
        return False
    
    finally:
        if server:
            server.server_close()


if __name__ == "__main__":
    print("\n" + "="*60)
    print("Microsoft 365 OAuth Authentication")
    print("="*60)
    print("This script will open your browser for you to log in.")
    print("After authentication, the refresh token will be saved.")
    print("="*60 + "\n")
    
    success = authenticate()
    sys.exit(0 if success else 1)
