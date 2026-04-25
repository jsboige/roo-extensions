# MCP Diagnosis — Invalid Diagnostic Patterns

**Version:** 1.0.0
**MAJ:** 2026-04-25

---

## Regle Absolue

**"La session a demarre avant que le MCP soit pret" n'est JAMAIS un diagnostic valide.**

Le protocole MCP fonctionne ainsi : soit le serveur repond au handshake dans le timeout, soit il ne repond pas. Il n'existe pas d'etat intermediaire "pas encore pret".

### Implications

- Si le MCP fonctionne dans un terminal autonome (JSON-RPC handshake OK, tools/list repond) mais pas dans Claude Code → le probleme est dans la configuration ou le processus hote, PAS un timing de demarrage.
- Si le MCP ne repond pas en standalone non plus → le serveur est en panne. Diagnostic: crash, .env manquant, build casse, port conflict.
- Un restart VS Code / Claude Code qui "resout" le probleme signifie que le processus precedent etait dans un etat corrompu ou que la config a ete rechargee — pas que le timing etait en cause.

### Origine

Incident 2026-04-25 (ai-01 + po-2023) : MCP roo-state-manager ne se chargeait pas dans Claude Code alors qu'il fonctionnait parfaitement en standalone (41 outils, 652 skeletons, Qdrant connecte). Le diagnostic "session started before MCP ready" a ete propose et rejete par l'utilisateur : "Ca n'a jamais ete vrai. Soit le MCP revient dans ta session, soit il ne fonctionne nulle part."

### Actions quand le MCP ne charge pas

1. **Tester en standalone** : `echo '{"jsonrpc":"2.0","method":"initialize","id":1}' | node build/index.js` — si OK, le serveur fonctionne
2. **Verifier la config** : `~/.claude.json` section mcpServers (command, args, cwd, env)
3. **Verifier le build** : `npm run build` dans le dossier du serveur
4. **Verifier les processus** : le processus node est-il lance ? Utilise-il le bon binaire ?
5. **Restart VS Code** : dernier recours, pas un diagnostic

---

**Principe condense** : *"Pas de timing fantasy. Le MCP repond ou il crash. Pas de demipression."*
