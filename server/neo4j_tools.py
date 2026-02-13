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


# ============================================================================
# USER-SPECIFIC HELPERS (for your workflow, not included in the package)
# ============================================================================

def initialize_graph(base_url: Optional[str] = None):
    """
    Initialize Andres's knowledge graph with test data.
    This is user-specific and should NOT be in the package distribution.
    """
    statements = [
        {'statement': 'MERGE (p:Person {name: "Andres"}) ON CREATE SET p.created = datetime(), p.context = "CS background, pair programming focus"'},
        {'statement': 'MERGE (p:Project {name: "emacs-openclaw"}) ON CREATE SET p.created = datetime(), p.description = "WebSocket chat integration for Emacs", p.status = "active"'},
        {'statement': 'MERGE (p:Project {name: "Gmail API Tools"}) ON CREATE SET p.created = datetime(), p.description = "Email management and batch operations", p.status = "active"'},
        {'statement': 'MERGE (t:Task {title: "Add knowledge graph"}) ON CREATE SET t.created = datetime(), t.description = "Issue #28 - knowledge graph for fast memory access", t.status = "open"'},
        {'statement': 'MERGE (t:Task {title: "Batch delete emails"}) ON CREATE SET t.created = datetime(), t.description = "Investigation and implementation", t.status = "in-progress"'},
        {'statement': 'MERGE (c:Concept {name: "WebSocket Protocol"}) ON CREATE SET c.created = datetime(), c.definition = "Real-time bidirectional communication"'},
        {'statement': 'MERGE (c:Concept {name: "Neo4j Cypher"}) ON CREATE SET c.created = datetime(), c.definition = "Graph query language"'},
        {'statement': 'MERGE (c:Concept {name: "Knowledge Graph"}) ON CREATE SET c.created = datetime(), c.definition = "Structured representation of knowledge"'},
        {'statement': 'MATCH (p:Person {name: "Andres"}) MATCH (pr:Project {name: "emacs-openclaw"}) MERGE (p)-[r:WORKED_ON {date: "2026-02-09"}]->(pr)'},
        {'statement': 'MATCH (p:Person {name: "Andres"}) MATCH (pr:Project {name: "Gmail API Tools"}) MERGE (p)-[r:WORKED_ON {date: "2026-02-12"}]->(pr)'},
        {'statement': 'MATCH (p:Person {name: "Andres"}) MATCH (t:Task {title: "Add knowledge graph"}) MERGE (p)-[r:WORKING_ON]->(t)'},
        {'statement': 'MATCH (p:Person {name: "Andres"}) MATCH (t:Task {title: "Batch delete emails"}) MERGE (p)-[r:WORKING_ON]->(t)'},
        {'statement': 'MATCH (t:Task {title: "Add knowledge graph"}) MATCH (p:Project {name: "emacs-openclaw"}) MERGE (t)-[r:BELONGS_TO]->(p)'},
        {'statement': 'MATCH (t:Task {title: "Batch delete emails"}) MATCH (p:Project {name: "Gmail API Tools"}) MERGE (t)-[r:BELONGS_TO]->(p)'},
        {'statement': 'MATCH (p:Project {name: "emacs-openclaw"}) MATCH (c:Concept {name: "WebSocket Protocol"}) MERGE (p)-[r:USES_CONCEPT]->(c)'},
        {'statement': 'MATCH (p:Project {name: "emacs-openclaw"}) MATCH (c:Concept {name: "Neo4j Cypher"}) MERGE (p)-[r:USES_CONCEPT]->(c)'},
    ]
    cypher_write(statements, base_url)


if __name__ == "__main__":
    # User-specific test/initialization (not for package distribution)
    try:
        print("Initializing knowledge graph...")
        initialize_graph()
        
        print("✓ Graph initialized!\n")
        print("Stats:")
        person_count = cypher('MATCH (p:Person) RETURN count(p)')
        project_count = cypher('MATCH (pr:Project) RETURN count(pr)')
        task_count = cypher('MATCH (t:Task) RETURN count(t)')
        concept_count = cypher('MATCH (c:Concept) RETURN count(c)')
        
        stats = {
            "Person": person_count[0][0] if person_count else 0,
            "Project": project_count[0][0] if project_count else 0,
            "Task": task_count[0][0] if task_count else 0,
            "Concept": concept_count[0][0] if concept_count else 0,
        }
        for node_type, count in stats.items():
            print(f"  {node_type}: {count}")
            
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
