# Garde-Fous CI - Roo Code

## Regle

**AVANT de pousser des changements dans le submodule `mcps/internal`, VALIDER que le build et les tests CI passent.**

## Validation

```bash
cd mcps/internal/servers/roo-state-manager
npm run build && npx vitest run --config vitest.config.ci.ts
```

**Si ca echoue : NE PAS POUSSER.** Corriger d'abord.

## Contexte

Le CI utilise `vitest.config.ci.ts` (pas `vitest.config.ts`). La config CI exclut 32 tests qui dependent de Windows/PowerShell/GDrive.

Si tu ajoutes des tests, verifier qu'ils passent avec la config CI :
```bash
npx vitest run --config vitest.config.ci.ts tests/unit/ton-nouveau-test.test.ts
```
