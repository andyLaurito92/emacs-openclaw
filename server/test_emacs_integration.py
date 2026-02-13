#!/usr/bin/env python3
"""
Integration test for Emacs buffer management API.

This script tests the Emacs buffer endpoints by making HTTP requests
to the FastAPI server. It requires:
1. The server to be running on localhost:3333
2. Emacs to be running in server mode (M-x server-start)
3. emacsclient to be available in PATH

Run with: python3 test_emacs_integration.py
"""

import requests
import sys
import subprocess
import time


def check_emacs_server():
    """Check if Emacs server is running."""
    try:
        result = subprocess.run(
            ["emacsclient", "--eval", "(+ 1 1)"],
            capture_output=True,
            text=True,
            timeout=2
        )
        return result.returncode == 0
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False


def test_list_buffers():
    """Test listing buffers."""
    print("Testing: List buffers...")
    response = requests.get("http://localhost:3333/emacs/buffers")
    assert response.status_code == 200, f"Expected 200, got {response.status_code}"
    data = response.json()
    assert "buffers" in data, "Response should contain 'buffers' key"
    print(f"✓ Found {len(data['buffers'])} buffers")
    return data["buffers"]


def test_create_buffer():
    """Test creating a buffer."""
    print("Testing: Create buffer...")
    response = requests.post(
        "http://localhost:3333/emacs/buffer",
        json={"name": "test-openclaw-integration"}
    )
    assert response.status_code == 200, f"Expected 200, got {response.status_code}"
    data = response.json()
    assert data["status"] == "created", "Buffer should be created"
    assert data["buffer_name"] == "test-openclaw-integration"
    print("✓ Buffer created successfully")


def test_set_buffer_content():
    """Test setting buffer content."""
    print("Testing: Set buffer content...")
    test_content = "Hello from OpenClaw integration test!\nLine 2\nLine 3"
    response = requests.put(
        "http://localhost:3333/emacs/buffer/test-openclaw-integration/content",
        json={"content": test_content}
    )
    assert response.status_code == 200, f"Expected 200, got {response.status_code}"
    data = response.json()
    assert data["status"] == "success", "Content should be set successfully"
    print("✓ Buffer content set successfully")
    return test_content


def test_get_buffer_content(expected_content):
    """Test getting buffer content."""
    print("Testing: Get buffer content...")
    response = requests.get(
        "http://localhost:3333/emacs/buffer/test-openclaw-integration/content"
    )
    assert response.status_code == 200, f"Expected 200, got {response.status_code}"
    data = response.json()
    assert data["buffer_name"] == "test-openclaw-integration"
    assert "content" in data
    actual_content = data["content"]
    assert actual_content == expected_content, f"Content mismatch: expected {repr(expected_content)}, got {repr(actual_content)}"
    print(f"✓ Buffer content retrieved correctly ({len(actual_content)} chars)")


def test_delete_buffer():
    """Test deleting a buffer."""
    print("Testing: Delete buffer...")
    response = requests.delete(
        "http://localhost:3333/emacs/buffer/test-openclaw-integration"
    )
    assert response.status_code == 200, f"Expected 200, got {response.status_code}"
    data = response.json()
    assert data["status"] == "deleted", "Buffer should be deleted"
    print("✓ Buffer deleted successfully")


def test_server_health():
    """Test server health endpoint."""
    print("Testing: Server health check...")
    response = requests.get("http://localhost:3333/health")
    assert response.status_code == 200, f"Expected 200, got {response.status_code}"
    data = response.json()
    assert data["status"] == "ok", "Server should be healthy"
    print("✓ Server is healthy")


def test_tools_endpoint():
    """Test that tools endpoint lists emacs provider."""
    print("Testing: Tools endpoint...")
    response = requests.get("http://localhost:3333/tools")
    assert response.status_code == 200, f"Expected 200, got {response.status_code}"
    data = response.json()
    assert "emacs" in data["providers"], "Emacs should be in providers list"
    
    # Count emacs tools
    emacs_tools = [t for t in data["tools"] if t["provider"] == "emacs"]
    # 5 basic (list, create, get, set, delete) + 7 advanced (append, info, region get/set, replace, mode, eval) = 12
    assert len(emacs_tools) == 12, f"Expected 12 emacs tools, got {len(emacs_tools)}"
    print(f"✓ Found {len(emacs_tools)} Emacs tools in /tools endpoint")


def main():
    """Run all integration tests."""
    print("=" * 60)
    print("Emacs Buffer Management API - Integration Tests")
    print("=" * 60)
    print()
    
    # Check prerequisites
    print("Checking prerequisites...")
    
    # Check if emacsclient is available
    if not check_emacs_server():
        print("❌ Emacs server is not running or emacsclient is not available!")
        print("   Please start Emacs and run: M-x server-start")
        sys.exit(1)
    print("✓ Emacs server is running")
    
    # Check if FastAPI server is running
    try:
        response = requests.get("http://localhost:3333/health", timeout=2)
        if response.status_code != 200:
            raise Exception("Server not healthy")
    except Exception as e:
        print("❌ FastAPI server is not running on localhost:3333!")
        print("   Please start the server with: cd server && python3 -m uvicorn server:app --host 127.0.0.1 --port 3333")
        sys.exit(1)
    print("✓ FastAPI server is running")
    print()
    
    # Run tests
    try:
        test_server_health()
        test_tools_endpoint()
        buffers = test_list_buffers()
        test_create_buffer()
        content = test_set_buffer_content()
        test_get_buffer_content(content)
        test_delete_buffer()
        
        print()
        print("=" * 60)
        print("✅ All integration tests passed!")
        print("=" * 60)
        
    except AssertionError as e:
        print()
        print("=" * 60)
        print(f"❌ Test failed: {e}")
        print("=" * 60)
        sys.exit(1)
    except Exception as e:
        print()
        print("=" * 60)
        print(f"❌ Unexpected error: {e}")
        print("=" * 60)
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
