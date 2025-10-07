#!/usr/bin/env python3
"""Test d'installation du serveur MCP Jupyter Python/Papermill"""

try:
    import papermill
    print(f"✅ Papermill {papermill.__version__} OK")
except ImportError as e:
    print(f"❌ Erreur import Papermill: {e}")

try:
    import mcp
    print(f"✅ MCP OK")
except ImportError as e:
    print(f"❌ Erreur import MCP: {e}")

try:
    import jupyter_client
    print(f"✅ Jupyter Client {jupyter_client.__version__} OK")
except ImportError as e:
    print(f"❌ Erreur import Jupyter Client: {e}")

try:
    from papermill_mcp.main_fastmcp import mcp as fastmcp_instance
    print(f"✅ FastMCP Server OK")
except ImportError as e:
    print(f"❌ Erreur import FastMCP Server: {e}")

print("\n🎯 Test d'installation terminé")