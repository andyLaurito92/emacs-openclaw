"""
Tests for the refactored Google tools server.
Tests the router structure and endpoint routing.
"""

import pytest
from fastapi.testclient import TestClient
from unittest.mock import Mock, patch, MagicMock

from server import app


@pytest.fixture
def client():
    """Create a test client for the FastAPI app."""
    return TestClient(app)


class TestServerStructure:
    """Test that the server is properly structured with Google router."""

    def test_health_check(self, client):
        """Test /health endpoint is available."""
        response = client.get("/health")
        assert response.status_code == 200
        assert response.json()["status"] == "ok"
        assert "Tools" in response.json()["service"]

    def test_tools_endpoint(self, client):
        """Test /tools endpoint lists providers and endpoints."""
        response = client.get("/tools")
        assert response.status_code == 200
        data = response.json()
        assert "providers" in data
        assert "google" in data["providers"]
        assert "microsoft" in data["providers"]
        assert "emacs" in data["providers"]

    def test_tools_list_has_google_endpoints(self, client):
        """Test that /tools lists all Google endpoints with /google prefix."""
        response = client.get("/tools")
        data = response.json()
        tools = data["tools"]

        # Check that all Google tools have correct prefix
        google_tools = [t for t in tools if t["provider"] == "google"]
        assert len(google_tools) > 0

        for tool in google_tools:
            assert tool["endpoint"].startswith("/google/")
            assert tool["provider"] == "google"


class TestGoogleEmailRouting:
    """Test that Google email endpoints are correctly routed."""

    def test_list_emails_endpoint_exists(self, client):
        """Test /google/emails endpoint is accessible."""
        with patch("google_server.google_list_emails") as mock_list:
            mock_list.return_value = []
            response = client.get("/google/emails?limit=5")
            assert response.status_code == 200
            mock_list.assert_called_once_with(5)

    def test_search_emails_endpoint_exists(self, client):
        """Test /google/search-emails endpoint is accessible."""
        with patch("google_server.google_search_emails") as mock_search:
            mock_search.return_value = []
            response = client.get("/google/search-emails?query=from:test@example.com")
            assert response.status_code == 200
            mock_search.assert_called_once()

    def test_delete_email_endpoint_exists(self, client):
        """Test /google/email/{message_id} DELETE endpoint is accessible."""
        with patch("google_server.google_delete_email") as mock_delete:
            response = client.delete("/google/email/123")
            assert response.status_code == 200
            mock_delete.assert_called_once_with("123")

    def test_send_email_endpoint_exists(self, client):
        """Test /google/send-email POST endpoint is accessible."""
        with patch("google_server.google_send_email") as mock_send:
            response = client.post(
                "/google/send-email",
                json={"to": "test@example.com", "subject": "Test", "body": "Test body"},
            )
            assert response.status_code == 200
            mock_send.assert_called_once()


class TestGoogleCalendarRouting:
    """Test that Google calendar endpoints are correctly routed."""

    def test_create_calendar_event_endpoint_exists(self, client):
        """Test /google/calendar-event POST endpoint is accessible."""
        with patch("google_server.google_create_calendar_event") as mock_create:
            mock_create.return_value = {"id": "123", "htmlLink": "http://..."}
            response = client.post(
                "/google/calendar-event",
                json={
                    "summary": "Test Event",
                    "start_iso": "2026-02-10T10:00:00",
                    "end_iso": "2026-02-10T11:00:00",
                },
            )
            assert response.status_code == 200
            assert response.json()["status"] == "created"
            mock_create.assert_called_once()

    def test_delete_calendar_event_endpoint_exists(self, client):
        """Test /google/calendar-event/{event_id} DELETE endpoint is accessible."""
        with patch("google_server.google_delete_calendar_event") as mock_delete:
            response = client.delete("/google/calendar-event/event123")
            assert response.status_code == 200
            mock_delete.assert_called_once_with("event123")


class TestGoogleDriveRouting:
    """Test that Google Drive endpoints are correctly routed."""

    def test_list_drive_files_endpoint_exists(self, client):
        """Test /google/drive/files GET endpoint is accessible."""
        with patch("google_server.google_list_drive_files") as mock_list:
            mock_list.return_value = []
            response = client.get("/google/drive/files?limit=10")
            assert response.status_code == 200
            mock_list.assert_called_once()

    def test_search_drive_files_endpoint_exists(self, client):
        """Test /google/drive/search GET endpoint is accessible."""
        with patch("google_server.google_search_drive_files") as mock_search:
            mock_search.return_value = []
            response = client.get("/google/drive/search?query=test")
            assert response.status_code == 200
            mock_search.assert_called_once()

    def test_get_drive_file_endpoint_exists(self, client):
        """Test /google/drive/file/{file_id} GET endpoint is accessible."""
        with patch("google_server.google_get_drive_file") as mock_get:
            mock_get.return_value = {"id": "file123", "name": "test.txt"}
            response = client.get("/google/drive/file/file123")
            assert response.status_code == 200
            mock_get.assert_called_once_with("file123")

    def test_read_drive_file_endpoint_exists(self, client):
        """Test /google/drive/file/{file_id}/read GET endpoint is accessible."""
        with patch("google_server.google_read_drive_file") as mock_read:
            mock_read.return_value = "File content"
            response = client.get("/google/drive/file/file123/read")
            assert response.status_code == 200
            mock_read.assert_called_once_with("file123")

    def test_create_drive_file_endpoint_exists(self, client):
        """Test /google/drive/file POST endpoint is accessible."""
        with patch("google_server.google_create_drive_file") as mock_create:
            mock_create.return_value = {"id": "new_file", "name": "test.txt"}
            response = client.post(
                "/google/drive/file",
                json={"name": "test.txt", "content": "Hello world"},
            )
            assert response.status_code == 200
            mock_create.assert_called_once()

    def test_create_drive_folder_endpoint_exists(self, client):
        """Test /google/drive/folder POST endpoint is accessible."""
        with patch("google_server.google_create_drive_folder") as mock_create:
            mock_create.return_value = {"name": "test_folder"}
            response = client.post("/google/drive/folder", json={"name": "test_folder"})
            assert response.status_code == 200
            mock_create.assert_called_once()

    def test_update_drive_file_endpoint_exists(self, client):
        """Test /google/drive/file/{file_id} PUT endpoint is accessible."""
        with patch("google_server.google_update_drive_file") as mock_update:
            mock_update.return_value = {"id": "file123", "name": "test.txt"}
            response = client.put(
                "/google/drive/file/file123", json={"content": "Updated content"}
            )
            assert response.status_code == 200
            mock_update.assert_called_once()

    def test_delete_drive_file_endpoint_exists(self, client):
        """Test /google/drive/file/{file_id} DELETE endpoint is accessible."""
        with patch("google_server.google_delete_drive_file") as mock_delete:
            response = client.delete("/google/drive/file/file123")
            assert response.status_code == 200
            mock_delete.assert_called_once_with("file123")

    def test_share_drive_file_endpoint_exists(self, client):
        """Test /google/drive/file/{file_id}/share POST endpoint is accessible."""
        with patch("google_server.google_share_drive_file") as mock_share:
            mock_share.return_value = {"id": "perm123"}
            response = client.post(
                "/google/drive/file/file123/share?email=test@example.com&role=reader"
            )
            assert response.status_code == 200
            mock_share.assert_called_once()


class TestGoogleToolsFunctionPrefix:
    """Test that google_tools module has properly prefixed functions."""

    def test_google_tools_exports_prefixed_functions(self):
        """Test that google_tools exports google_* prefixed functions."""
        import google_tools

        # Check for key functions with google_ prefix
        expected_functions = [
            "google_send_email",
            "google_list_emails",
            "google_search_emails",
            "google_delete_email",
            "google_create_calendar_event",
            "google_delete_calendar_event",
            "google_list_drive_files",
            "google_search_drive_files",
            "google_get_drive_file",
            "google_read_drive_file",
            "google_create_drive_file",
            "google_create_drive_folder",
            "google_update_drive_file",
            "google_delete_drive_file",
            "google_share_drive_file",
        ]

        for func_name in expected_functions:
            assert hasattr(
                google_tools, func_name
            ), f"Missing {func_name} in google_tools"
            assert callable(getattr(google_tools, func_name))


class TestErrorHandling:
    """Test error handling in the refactored structure."""

    def test_list_emails_error_handling(self, client):
        """Test that errors are properly handled and return 500."""
        with patch("google_server.google_list_emails") as mock_list:
            mock_list.side_effect = Exception("API Error")
            response = client.get("/google/emails")
            assert response.status_code == 500
            assert "detail" in response.json()

    def test_send_email_invalid_request(self, client):
        """Test that invalid requests return appropriate errors."""
        response = client.post(
            "/google/send-email",
            json={
                "to": "invalid-email",  # Invalid email format
                "subject": "Test",
                "body": "Test",
            },
        )
        # Should fail validation
        assert response.status_code == 422  # Unprocessable Entity


class TestRouterIsolation:
    """Test that Google router is properly isolated and namespaced."""

    def test_old_paths_dont_exist(self, client):
        """Test that old non-prefixed paths no longer exist."""
        # Old paths like /emails should not exist anymore
        response = client.get("/emails")
        assert response.status_code == 404

        response = client.get("/drive/files")
        assert response.status_code == 404

    def test_all_google_paths_have_prefix(self, client):
        """Test that all Google endpoints are under /google prefix."""
        # Test that /google prefix is required
        with patch("google_server.google_list_emails") as mock_list:
            mock_list.return_value = []

            # Should work with /google prefix
            response = client.get("/google/emails")
            assert response.status_code == 200

            # Should fail without prefix
            response = client.get("/emails")
            assert response.status_code == 404


class TestEmacsBufferRouting:
    """Test that Emacs buffer endpoints are correctly routed."""

    def test_tools_list_has_emacs_endpoints(self, client):
        """Test that /tools lists all Emacs endpoints with /emacs prefix."""
        response = client.get("/tools")
        data = response.json()
        tools = data["tools"]

        # Check that all Emacs tools have correct prefix
        emacs_tools = [t for t in tools if t["provider"] == "emacs"]
        assert len(emacs_tools) == 5  # list, create, get, set, delete

        for tool in emacs_tools:
            assert tool["endpoint"].startswith("/emacs/")
            assert tool["provider"] == "emacs"

    def test_list_buffers_endpoint_exists(self, client):
        """Test /emacs/buffers endpoint is accessible."""
        with patch("emacs_server.emacs_list_buffers") as mock_list:
            mock_list.return_value = ["*scratch*", "test.txt"]
            response = client.get("/emacs/buffers")
            assert response.status_code == 200
            data = response.json()
            assert "buffers" in data
            assert data["buffers"] == ["*scratch*", "test.txt"]
            mock_list.assert_called_once()

    def test_create_buffer_endpoint_exists(self, client):
        """Test /emacs/buffer POST endpoint is accessible."""
        with patch("emacs_server.emacs_create_buffer") as mock_create:
            mock_create.return_value = "test-buffer"
            response = client.post("/emacs/buffer", json={"name": "test-buffer"})
            assert response.status_code == 200
            data = response.json()
            assert data["status"] == "created"
            assert data["buffer_name"] == "test-buffer"
            mock_create.assert_called_once_with("test-buffer")

    def test_get_buffer_content_endpoint_exists(self, client):
        """Test /emacs/buffer/{buffer_name}/content GET endpoint is accessible."""
        with patch("emacs_server.emacs_get_buffer_content") as mock_get:
            mock_get.return_value = "Buffer content here"
            response = client.get("/emacs/buffer/test.txt/content")
            assert response.status_code == 200
            data = response.json()
            assert data["buffer_name"] == "test.txt"
            assert data["content"] == "Buffer content here"
            mock_get.assert_called_once_with("test.txt")

    def test_set_buffer_content_endpoint_exists(self, client):
        """Test /emacs/buffer/{buffer_name}/content PUT endpoint is accessible."""
        with patch("emacs_server.emacs_set_buffer_content") as mock_set:
            mock_set.return_value = True
            response = client.put(
                "/emacs/buffer/test.txt/content?content=New+content"
            )
            assert response.status_code == 200
            data = response.json()
            assert data["status"] == "success"
            assert data["buffer_name"] == "test.txt"
            mock_set.assert_called_once()

    def test_delete_buffer_endpoint_exists(self, client):
        """Test /emacs/buffer/{buffer_name} DELETE endpoint is accessible."""
        with patch("emacs_server.emacs_delete_buffer") as mock_delete:
            mock_delete.return_value = True
            response = client.delete("/emacs/buffer/test.txt")
            assert response.status_code == 200
            data = response.json()
            assert data["status"] == "deleted"
            assert data["buffer_name"] == "test.txt"
            mock_delete.assert_called_once_with("test.txt")

    def test_emacs_error_handling(self, client):
        """Test that Emacs errors are properly handled and return 500."""
        with patch("emacs_server.emacs_list_buffers") as mock_list:
            mock_list.side_effect = RuntimeError("emacsclient not found")
            response = client.get("/emacs/buffers")
            assert response.status_code == 500
            assert "detail" in response.json()


class TestEmacsToolsPrefix:
    """Test that emacs_tools module has properly prefixed functions."""

    def test_emacs_tools_exports_prefixed_functions(self):
        """Test that emacs_tools exports emacs_* prefixed functions."""
        import emacs_tools

        # Check for key functions with emacs_ prefix
        expected_functions = [
            "emacs_list_buffers",
            "emacs_create_buffer",
            "emacs_get_buffer_content",
            "emacs_set_buffer_content",
            "emacs_delete_buffer",
        ]

        for func_name in expected_functions:
            assert hasattr(
                emacs_tools, func_name
            ), f"Missing {func_name} in emacs_tools"
            assert callable(getattr(emacs_tools, func_name))

