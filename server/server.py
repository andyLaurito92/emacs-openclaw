from google_auth_oauthlib.flow import InstalledAppFlow
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request

from fastapi import FastAPI
import logging
import os

from google_server import router as google_router
from microsoft_server import router as microsoft_router
from emacs_server import router as emacs_router
from neo4j_server import router as neo4j_router
from tools_registry import get_all_tools, get_providers

# Setup logging to file and console
log_file = "logs.txt"
logging.basicConfig(
    level=logging.DEBUG,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[logging.FileHandler(log_file), logging.StreamHandler()],
)
logger = logging.getLogger(__name__)
logger.info("Server starting up...")

SCOPES = [
    "https://www.googleapis.com/auth/calendar.events",
    "https://www.googleapis.com/auth/gmail.modify",
    "https://www.googleapis.com/auth/drive",
]

# Configuration constants
CLIENT_SECRET_PATH = os.getenv("OPENCLAW_CLIENT_SECRET", "client_secret.json")
TOKEN_PATH = "token.json"


app = FastAPI(
    title="OpenClaw Tools",
    version="1.0.0",
)


# =========================
# Mount Routers
# =========================

app.include_router(google_router)
app.include_router(microsoft_router)
app.include_router(emacs_router)
app.include_router(neo4j_router)


# =========================
# Meta Endpoints
# =========================


@app.get("/health")
def health_check():
    """Health check endpoint to verify server is running."""
    return {"status": "ok", "service": "OpenClaw Tools Server", "version": "1.0.0"}



@app.get("/tools")
def list_tools():
    """List available tools and their descriptions."""
    return {
        "providers": get_providers(),
        "tools": get_all_tools(),
    }


if __name__ == "__main__":
    import uvicorn

    # Run OAuth flow if token doesn't exist
    if not os.path.exists(TOKEN_PATH):
        logger.info("token.json not found, starting OAuth flow...")
        if not os.path.exists(CLIENT_SECRET_PATH):
            logger.error(
                f"client_secret.json not found at {CLIENT_SECRET_PATH}! Cannot authenticate."
            )
            raise FileNotFoundError(
                f"client_secret.json is required for OAuth authentication. "
                f"Expected at: {CLIENT_SECRET_PATH} "
                f"Please follow the setup instructions in README-SERVER.md"
            )

        flow = InstalledAppFlow.from_client_secrets_file(CLIENT_SECRET_PATH, SCOPES)
        creds = flow.run_local_server(port=8080, open_browser=True)

        with open(TOKEN_PATH, "w") as f:
            f.write(creds.to_json())

        logger.info("OAuth complete, token saved to token.json")
    else:
        logger.info("Found existing token.json, skipping OAuth flow")

    uvicorn.run(app, host="127.0.0.1", port=3333)
