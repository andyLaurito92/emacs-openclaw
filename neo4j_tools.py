"""Neo4j Knowledge Graph Tools - HTTP Transactional API

A generic, configurable client for Neo4j HTTP transactions.
Configure the base URL and other settings via environment variables or constructor.

Configuration (in order of precedence):
1. Constructor parameters
2. Environment variables: NEO4J_URL (base URL)
3. Default: http://localhost:7474/db/neo4j
"""

import os
import requests
from typing import Any, Dict, List, Optional


class Transaction:
    """Manages a Neo4j transaction via the HTTP API."""
    
    def __init__(self, base_url: Optional[str] = None):
        self.base_url = base_url or os.getenv("NEO4J_URL", "http://localhost:7474/db/neo4j")
        self.tx_url = None
        self.commit_url = None
        self.statements = []
    
    def add_statement(self, statement: str, parameters: Optional[Dict[str, Any]] = None):
        """Add a Cypher statement to the transaction."""
        if parameters is None:
            parameters = {}
        self.statements.append({
            "statement": statement,
            "parameters": parameters
        })
    
    def execute(self) -> Dict[str, Any]:
        """Execute all statements in a single transaction and commit immediately."""
        if not self.statements:
            return {"results": []}
        
        # Start transaction
        response = requests.post(
            f"{self.base_url}/tx",
            json={"statements": self.statements}
        )
        data = response.json()
        
        if data.get("errors"):
            raise Exception(f"Neo4j Error: {data['errors']}")
        
        self.tx_url = data.get("transaction", {}).get("string")
        self.commit_url = data.get("commit")
        results = data.get("results", [])
        
        # Commit immediately to ensure persistence
        if self.commit_url:
            commit_response = requests.post(self.commit_url, json={"statements": []})
            commit_data = commit_response.json()
            if commit_data.get("errors"):
                raise Exception(f"Neo4j Commit Error: {commit_data['errors']}")
        
        return {"results": results}
    
    def close(self):
        """Reset transaction state."""
        self.statements = []
        self.tx_url = None
        self.commit_url = None


def cypher(query: str, params: Optional[Dict[str, Any]] = None, base_url: Optional[str] = None) -> List[List[Any]]:
    """
    Execute a Cypher query and return results as list of rows.
    
    Args:
        query: Cypher query string
        params: Query parameters (optional)
        base_url: Neo4j base URL (optional, uses NEO4J_URL env var or default)
    
    Returns:
        List of result rows, each row is a list of values
    
    Example:
        results = cypher("MATCH (p:Person {name: $name}) RETURN p", {"name": "Alice"})
    """
    if params is None:
        params = {}
    
    tx = Transaction(base_url)
    tx.add_statement(query, params)
    result = tx.execute()
    tx.close()
    
    records = result.get("results", [{}])[0].get("data", [])
    return [record.get("row", []) for record in records]


def cypher_write(statements: List[Dict[str, Any]], base_url: Optional[str] = None) -> Dict[str, Any]:
    """
    Execute multiple statements in a single atomic transaction.
    
    Args:
        statements: List of {"statement": str, "parameters": dict} dicts
        base_url: Neo4j base URL (optional, uses NEO4J_URL env var or default)
    
    Returns:
        Dict with "results" key containing list of results for each statement
    
    Example:
        cypher_write([
            {"statement": "CREATE (p:Person {name: $name})", "parameters": {"name": "Alice"}},
            {"statement": "MATCH (p:Person {name: $name}) RETURN p", "parameters": {"name": "Alice"}}
        ])
    """
    tx = Transaction(base_url)
    for stmt in statements:
        tx.add_statement(stmt["statement"], stmt.get("parameters", {}))
    result = tx.execute()
    tx.close()
    return result
