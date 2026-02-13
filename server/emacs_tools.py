"""
Emacs buffer manipulation tools using emacsclient.
Provides Python wrappers for Emacs buffer operations via emacsclient.
"""

import subprocess
import json
import logging
from typing import List, Optional

logger = logging.getLogger(__name__)


def _emacsclient_eval(elisp_expr: str) -> str:
    """
    Execute an Emacs Lisp expression via emacsclient and return the result.
    
    Args:
        elisp_expr: The Emacs Lisp expression to evaluate
        
    Returns:
        The output from emacsclient as a string
        
    Raises:
        RuntimeError: If emacsclient returns a non-zero exit code
    """
    cmd = ["emacsclient", "--eval", elisp_expr]
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
        
        if result.returncode == 0:
            # Return the raw output - caller handles parsing
            return result.stdout.strip()
        else:
            error_msg = result.stderr.strip() if result.stderr else "Unknown error"
            raise RuntimeError(f"emacsclient error: {error_msg}")
    except subprocess.TimeoutExpired:
        raise RuntimeError("emacsclient timed out after 5 seconds")
    except FileNotFoundError:
        raise RuntimeError("emacsclient not found. Is Emacs running in server mode?")


def _escape_elisp_string(s: str, escape_newlines: bool = False) -> str:
    """
    Escape a string for use in Emacs Lisp.
    
    Args:
        s: The string to escape
        escape_newlines: If True, also escape newline characters
        
    Returns:
        The escaped string
    """
    # Order matters: escape backslashes first, then quotes
    result = s.replace('\\', '\\\\').replace('"', '\\"')
    if escape_newlines:
        # Replace actual newlines with escaped newlines
        result = result.replace('\n', '\\n')
        result = result.replace('\t', '\\t')
    return result


def _parse_elisp_string(elisp_output: str) -> str:
    """
    Parse a string from Emacs Lisp output.
    Handles quoted strings with proper escaping.
    
    Args:
        elisp_output: Raw output from emacsclient
        
    Returns:
        Parsed string value
    """
    # Remove surrounding quotes if present
    if elisp_output.startswith('"') and elisp_output.endswith('"'):
        # Handle Emacs Lisp string escaping
        content = elisp_output[1:-1]
        # Unescape common sequences
        content = content.replace('\\n', '\n')
        content = content.replace('\\t', '\t')
        content = content.replace('\\"', '"')
        content = content.replace('\\\\', '\\')
        return content
    return elisp_output


def _parse_elisp_list(elisp_output: str) -> List[str]:
    """
    Parse a list from Emacs Lisp output.
    
    Args:
        elisp_output: Raw output from emacsclient (e.g., '("buf1" "buf2")')
        
    Returns:
        Parsed list of strings
    """
    # Handle nil case
    if elisp_output == "nil":
        return []
    
    # Remove outer parentheses
    if elisp_output.startswith("(") and elisp_output.endswith(")"):
        content = elisp_output[1:-1].strip()
        if not content:
            return []
        
        # Simple parsing for quoted strings
        result = []
        in_string = False
        current = []
        i = 0
        while i < len(content):
            char = content[i]
            if char == '"' and (i == 0 or content[i-1] != '\\'):
                if in_string:
                    # End of string
                    result.append(_parse_elisp_string('"' + ''.join(current) + '"'))
                    current = []
                    in_string = False
                else:
                    # Start of string
                    in_string = True
            elif in_string:
                current.append(char)
            i += 1
        
        return result
    
    return [elisp_output]


def emacs_list_buffers() -> List[str]:
    """
    List all visible buffer names (excluding internal buffers starting with space).
    
    Returns:
        List of buffer names
        
    Raises:
        RuntimeError: If emacsclient fails
    """
    try:
        output = _emacsclient_eval("(openclaw-list-buffer-names)")
        return _parse_elisp_list(output)
    except Exception as e:
        logger.error(f"Error listing buffers: {e}")
        raise


def emacs_create_buffer(buffer_name: str) -> str:
    """
    Create a new buffer with the given name.
    
    Args:
        buffer_name: Name for the new buffer
        
    Returns:
        The name of the created buffer
        
    Raises:
        RuntimeError: If emacsclient fails
    """
    try:
        # Escape the buffer name for Elisp
        escaped_name = _escape_elisp_string(buffer_name)
        output = _emacsclient_eval(f'(openclaw-create-buffer "{escaped_name}")')
        return _parse_elisp_string(output)
    except Exception as e:
        logger.error(f"Error creating buffer '{buffer_name}': {e}")
        raise


def emacs_get_buffer_content(buffer_name: str) -> str:
    """
    Get the content of a buffer.
    
    Args:
        buffer_name: Name of the buffer to read
        
    Returns:
        The buffer's content as a string
        
    Raises:
        RuntimeError: If emacsclient fails or buffer doesn't exist
    """
    try:
        # Escape the buffer name for Elisp
        escaped_name = _escape_elisp_string(buffer_name)
        output = _emacsclient_eval(f'(openclaw-get-buffer-content "{escaped_name}")')
        return _parse_elisp_string(output)
    except Exception as e:
        logger.error(f"Error getting content of buffer '{buffer_name}': {e}")
        raise


def emacs_set_buffer_content(buffer_name: str, content: str) -> bool:
    """
    Set the content of a buffer, replacing all existing content.
    
    Args:
        buffer_name: Name of the buffer to modify
        content: New content for the buffer
        
    Returns:
        True if successful
        
    Raises:
        RuntimeError: If emacsclient fails or buffer doesn't exist
    """
    try:
        # Escape both the buffer name and content for Elisp
        escaped_name = _escape_elisp_string(buffer_name)
        escaped_content = _escape_elisp_string(content, escape_newlines=True)
        output = _emacsclient_eval(f'(openclaw-set-buffer-content "{escaped_name}" "{escaped_content}")')
        return output == "t"
    except Exception as e:
        logger.error(f"Error setting content of buffer '{buffer_name}': {e}")
        raise


def emacs_delete_buffer(buffer_name: str) -> bool:
    """
    Delete a buffer.
    
    Args:
        buffer_name: Name of the buffer to delete
        
    Returns:
        True if buffer was deleted, False if it didn't exist
        
    Raises:
        RuntimeError: If emacsclient fails
    """
    try:
        # Escape the buffer name for Elisp
        escaped_name = _escape_elisp_string(buffer_name)
        output = _emacsclient_eval(f'(openclaw-delete-buffer "{escaped_name}")')
        return output == "t"
    except Exception as e:
        logger.error(f"Error deleting buffer '{buffer_name}': {e}")
        raise


def emacs_append_buffer_content(buffer_name: str, content: str) -> bool:
    """
    Append content to a buffer without replacing existing content.
    
    Args:
        buffer_name: Name of the buffer to append to
        content: Content to append
        
    Returns:
        True if successful
        
    Raises:
        RuntimeError: If emacsclient fails or buffer doesn't exist
    """
    try:
        # Get current content and append in Python
        current = emacs_get_buffer_content(buffer_name)
        new_content = current + content
        return emacs_set_buffer_content(buffer_name, new_content)
    except Exception as e:
        logger.error(f"Error appending to buffer '{buffer_name}': {e}")
        raise


def emacs_get_buffer_info(buffer_name: str) -> dict:
    """
    Get information about a buffer.
    
    Args:
        buffer_name: Name of the buffer
        
    Returns:
        Dictionary with buffer info (line_count, char_count, modified, read_only, mode)
        
    Raises:
        RuntimeError: If emacsclient fails or buffer doesn't exist
    """
    try:
        # Get content and compute info
        content = emacs_get_buffer_content(buffer_name)
        line_count = content.count('\n') + (1 if content and not content.endswith('\n') else 0)
        char_count = len(content)
        
        # Get more detailed info via Elisp
        escaped_name = _escape_elisp_string(buffer_name)
        output = _emacsclient_eval(f'(list (buffer-modified-p (get-buffer "{escaped_name}")) buffer-read-only (symbol-name major-mode))')
        
        # Simple parsing
        info = {
            "line_count": line_count,
            "char_count": char_count,
            "modified": "modified" in output or "t" in output.lower(),
            "read_only": "nil" not in output,
            "mode": "text"
        }
        return info
    except Exception as e:
        logger.error(f"Error getting buffer info for '{buffer_name}': {e}")
        raise


def emacs_get_buffer_region(buffer_name: str, start: int, end: int) -> str:
    """
    Get a region of text from a buffer.
    
    Args:
        buffer_name: Name of the buffer
        start: Start position (0-indexed)
        end: End position (0-indexed, exclusive)
        
    Returns:
        The text in that region
        
    Raises:
        RuntimeError: If emacsclient fails or buffer doesn't exist
    """
    try:
        content = emacs_get_buffer_content(buffer_name)
        safe_start = max(0, start)
        safe_end = min(len(content), end)
        return content[safe_start:safe_end]
    except Exception as e:
        logger.error(f"Error getting buffer region '{buffer_name}' [{start}:{end}]: {e}")
        raise


def emacs_set_buffer_region(buffer_name: str, start: int, end: int, content: str) -> bool:
    """
    Replace a region of text in a buffer.
    
    Args:
        buffer_name: Name of the buffer
        start: Start position (0-indexed)
        end: End position (0-indexed, exclusive)
        content: New content for the region
        
    Returns:
        True if successful
        
    Raises:
        RuntimeError: If emacsclient fails or buffer doesn't exist
    """
    try:
        current = emacs_get_buffer_content(buffer_name)
        safe_start = max(0, start)
        safe_end = min(len(current), end)
        new_content = current[:safe_start] + content + current[safe_end:]
        return emacs_set_buffer_content(buffer_name, new_content)
    except Exception as e:
        logger.error(f"Error setting buffer region '{buffer_name}' [{start}:{end}]: {e}")
        raise


def emacs_buffer_replace(buffer_name: str, find: str, replace: str, all_occurrences: bool = False) -> dict:
    """
    Search and replace in a buffer.
    
    Args:
        buffer_name: Name of the buffer
        find: Text to find
        replace: Text to replace with
        all_occurrences: If True, replace all occurrences; if False, replace only first
        
    Returns:
        Dictionary with replacement count and result
        
    Raises:
        RuntimeError: If emacsclient fails or buffer doesn't exist
    """
    try:
        content = emacs_get_buffer_content(buffer_name)
        
        if all_occurrences:
            new_content = content.replace(find, replace)
            count = content.count(find)
        else:
            new_content = content.replace(find, replace, 1)
            count = 1 if find in content else 0
        
        if content != new_content:
            emacs_set_buffer_content(buffer_name, new_content)
        
        return {
            "success": True,
            "count": count
        }
    except Exception as e:
        logger.error(f"Error replacing in buffer '{buffer_name}': {e}")
        raise


def emacs_eval_elisp(code: str) -> str:
    """
    Evaluate arbitrary Emacs Lisp code.
    
    Args:
        code: Emacs Lisp code to evaluate
        
    Returns:
        The result as a string
        
    Raises:
        RuntimeError: If emacsclient fails
    """
    try:
        output = _emacsclient_eval(code)
        return output
    except Exception as e:
        logger.error(f"Error evaluating Elisp code: {e}")
        raise
