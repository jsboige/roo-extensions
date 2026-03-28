import asyncio
import sys
sys.path.insert(0, 'D:/dev/roo-extensions/mcps/internal/servers/sk-agent')

async def test():
    from sk_agent import list_agents, list_models, call_agent
    
    # Test list_agents
    agents = await list_agents()
    print(f"AGENTS: {len(agents)}")
    for agent in agents[:5]:
        print(f"  - {agent}")
    
    # Test list_models
    models = await list_models()
    print(f"\nMODELS: {len(models)}")
    for model in models:
        print(f"  - {model}")
    
    # Test call_agent (analyst, simple prompt)
    print("\nTesting call_agent(analyst)...")
    try:
        result = await call_agent("analyst", "What is 2+2?")
        print(f"RESULT: {result[:200]}...")
    except Exception as e:
        print(f"ERROR: {e}")

asyncio.run(test())
