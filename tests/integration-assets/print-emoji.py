import sys

# Force UTF-8 for stdout if not already set (though environment variables should handle this)
# This script is designed to test if the environment correctly handles UTF-8 output
# without explicit encoding manipulation inside the script if possible, 
# but for robustness in testing, we ensure we are emitting UTF-8 bytes.

try:
    # Emojis: Rocket, Check Mark, Cross Mark, Sparkles
    emojis = "🚀 ✅ ❌ ✨"
    print(f"Emojis: {emojis}")
    print("Accents: é à è ê î ô û ç")
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)