"""Neo4j Knowledge Graph API Router

Provides HTTP endpoints for Neo4j Cypher queries.
Configurable via NEO4J_URL environment variable (default: http://localhost:7474/db/neo4j)
"""

from fastapi import APIRouter, HTTPException, Body
from typing import List, Dict, Any, Optional
import logging

from neo4j_tools import cypher, cypher_write, Transaction

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/neo4j",
    tags=["neo4j"],
    responses={500: {"description": "Neo4j server error"}},
)


@router.get("/health")
def health_check():
    """Check if Neo4j connection is working."""
    try:
        results = cypher("RETURN 1 as test")
        return {"status": "ok", "connected": True}
    except Exception as e:
        logger.error(f"Neo4j health check failed: {e}")
        raise HTTPException(status_code=503, detail=f"Neo4j unavailable: {str(e)}")


@router.post("/query")
def execute_query(
    query: str = Body(..., embed=True),
    parameters: Optional[Dict[str, Any]] = Body(default=None, embed=True),
):
    """
    Execute a single Cypher query.
    
    Parameters:
    - query: Cypher query string (e.g., "MATCH (n) RETURN count(n)")
    - parameters: Optional query parameters (e.g., {"name": "Alice"})
    
    Returns:
    - results: List of result rows
    
    Example:
    ```json
    {
      "query": "MATCH (p:Person {name: $name}) RETURN p",
      "parameters": {"name": "Alice"}
    }
    ```
    """
    try:
        results = cypher(query, parameters or {})
        return {"status": "ok", "results": results}
    except Exception as e:
        logger.error(f"Query execution error: {e}")
        raise HTTPException(status_code=400, detail=f"Query error: {str(e)}")


@router.post("/batch")
def execute_batch(
    statements: List[Dict[str, Any]] = Body(
        ...,
        example=[
            {"statement": "CREATE (p:Person {name: $name})", "parameters": {"name": "Alice"}},
            {"statement": "MATCH (p:Person) RETURN count(p)"},
        ],
    )
):
    """
    Execute multiple Cypher statements in a single atomic transaction.
    
    Parameters:
    - statements: List of {"statement": str, "parameters": dict} objects
    
    Returns:
    - results: List of results for each statement
    
    Example:
    ```json
    {
      "statements": [
        {
          "statement": "CREATE (p:Person {name: $name})",
          "parameters": {"name": "Alice"}
        },
        {
          "statement": "MATCH (p:Person) RETURN count(p)"
        }
      ]
    }
    ```
    """
    try:
        result = cypher_write(statements)
        return {"status": "ok", "results": result.get("results", [])}
    except Exception as e:
        logger.error(f"Batch execution error: {e}")
        raise HTTPException(status_code=400, detail=f"Batch error: {str(e)}")


@router.get("/stats")
def get_graph_stats():
    """
    Get basic statistics about the graph (node and relationship counts).
    
    Returns:
    - node_counts: Dict with counts per label
    - relationship_count: Total number of relationships
    """
    try:
        # Count nodes by label
        labels_query = """
        UNWIND db.labels() as label
        RETURN label, size(cypher.run('MATCH (n:' + label + ') RETURN count(*) as c').records[0].values[0]) as count
        """
        # Simpler approach: count total nodes
        total_nodes = cypher("MATCH (n) RETURN count(n) as total")
        total_rels = cypher("MATCH ()-[r]->() RETURN count(r) as total")
        
        return {
            "status": "ok",
            "node_count": total_nodes[0][0] if total_nodes else 0,
            "relationship_count": total_rels[0][0] if total_rels else 0,
        }
    except Exception as e:
        logger.error(f"Stats query error: {e}")
        raise HTTPException(status_code=500, detail=f"Stats error: {str(e)}")
