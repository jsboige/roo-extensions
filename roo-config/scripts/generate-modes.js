#!/usr/bin/env node
/**
 * generate-modes.js - Generate .roomodes from config + template
 *
 * Reads:  roo-config/modes/modes-config.json (data)
 *         roo-config/modes/templates/commons/mode-instructions.md (template)
 *         roo-config/model-configs.json (optional, for --profile)
 * Writes: roo-config/modes/generated/simple-complex.roomodes
 *
 * The level ladder is declared in modes-config.json levels[] (#4115): the generator
 * iterates that ordered declaration — one mode per family x level. Each level entry
 * carries a name (family key + slug suffix), a profileId (default model-configs
 * binding), and an escalationInstruction (toward the next rung; the last entry's
 * instruction escalates beyond the ladder, e.g. Claude CLI).
 *
 * Options:
 *   --output <path>      Output file path (default: simple-complex.roomodes)
 *   --config <path>      modes-config.json path (default: roo-config/modes/modes-config.json;
 *                        used for N-level dry-runs that must not touch the repo config)
 *   --profile <name>     Apply profile from model-configs.json (sets apiConfigId per mode;
 *                        profile.modeOverrides keys mode slugs, profile.levelOverrides keys
 *                        level names and expand to every family)
 *   --model-configs <path> Path to model-configs.json (default: roo-config/model-configs.json)
 *   --deploy             Also copy to .roomodes at project root
 *   --deploy-global      Also copy to the Roo/Zoo global custom_modes.yaml (#595)
 *   --global-path <path> Explicit target file for --deploy-global (default: VS Code globalStorage custom_modes.yaml)
 *   --target-extension <auto|roo|zoo> Extension whose globalStorage receives --deploy-global
 *                        (default: auto -- Zoo as soon as Zoo is installed, Roo otherwise;
 *                        explicit 'roo'/'zoo' overrides the probe)
 *   --format <json|yaml> Output format (default: json). YAML needed for Roo 3.51.1+ global deploy.
 */
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..', '..');
const CONFIG_PATH = path.join(ROOT, 'roo-config', 'modes', 'modes-config.json');
const TEMPLATE_PATH = path.join(ROOT, 'roo-config', 'modes', 'templates', 'commons', 'mode-instructions.md');
const DEFAULT_OUTPUT = path.join(ROOT, 'roo-config', 'modes', 'generated', 'simple-complex.roomodes');
const DEFAULT_MODEL_CONFIGS = path.join(ROOT, 'roo-config', 'model-configs.json');

// --- Template Engine ---

function renderTemplate(template, vars) {
  var result = template;

  // Replace {{VAR}} with values
  for (var key of Object.keys(vars)) {
    var val = vars[key];
    var rx = new RegExp('\\{\\{' + key + '\\}\\}', 'g');
    if (Array.isArray(val)) {
      result = result.replace(rx, val.map(function(v) { return '- ' + v; }).join('\n'));
    } else if (val === null || val === undefined) {
      result = result.replace(rx, '');
    } else {
      result = result.replace(rx, String(val));
    }
  }

  // Process {{#if VAR}}...{{else}}...{{/if}}
  result = result.replace(
    /\{\{#if\s+(\w+)\}\}([\s\S]*?)(?:\{\{else\}\}([\s\S]*?))?\{\{\/if\}\}/g,
    function(_, cond, then_, else_) {
      return vars[cond] ? then_.trim() : (else_ ? else_.trim() : '');
    }
  );

  return result.replace(/\n{3,}/g, '\n\n').trim();
}

function capitalize(s) {
  return s.charAt(0).toUpperCase() + s.slice(1);
}

// --- YAML Serializer for customModes (no dependencies) ---
// Purpose-built for the { customModes: [...] } structure.
// Critical: empty arrays MUST serialize as "[]", NOT as null/empty.

function yamlEscape(str) {
  if (str === '') return '""';
  if (/[:{}\[\],&*?|>!'"%@`#]/.test(str) || /^[\s-]/.test(str) || /\s$/.test(str) ||
      str === 'true' || str === 'false' || str === 'null' || str === 'yes' || str === 'no' ||
      /^\d/.test(str)) {
    return '"' + str.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n') + '"';
  }
  return str;
}

function serializeGroups(groups, indent) {
  var pad = '  '.repeat(indent);
  // CRITICAL: empty arrays must be "[]", not null
  if (!groups || groups.length === 0) return '[]';
  var lines = [];
  groups.forEach(function(g) {
    if (typeof g === 'string') {
      lines.push(pad + '- ' + g);
    } else if (Array.isArray(g) && g.length >= 2) {
      // Tuple like ["edit", { fileRegex: "...", description: "..." }]
      lines.push(pad + '- - ' + yamlEscape(String(g[0])));
      if (typeof g[1] === 'object' && g[1] !== null) {
        var kvs = Object.keys(g[1]).map(function(k) {
          return k + ': ' + yamlEscape(String(g[1][k]));
        });
        lines.push(pad + '  - {' + kvs.join(', ') + '}');
      }
    }
  });
  return '\n' + lines.join('\n');
}

function serializeMultilineString(str, indent) {
  var pad = '  '.repeat(indent);
  if (str.indexOf('\n') >= 0) {
    var lines = ['|'];
    str.split('\n').forEach(function(line) {
      lines.push(pad + line);
    });
    return lines.join('\n');
  }
  return yamlEscape(str);
}

function jsonToYaml(obj) {
  var lines = ['customModes:'];
  obj.customModes.forEach(function(mode) {
    // slug (first key, on same line as dash)
    lines.push('  - slug: ' + yamlEscape(mode.slug));
    // name
    lines.push('    name: ' + yamlEscape(mode.name));
    // roleDefinition (multiline)
    lines.push('    roleDefinition: ' + serializeMultilineString(mode.roleDefinition, 3));
    // optional fields
    if (mode.description) {
      lines.push('    description: ' + yamlEscape(mode.description));
    }
    if (mode.whenToUse) {
      lines.push('    whenToUse: ' + yamlEscape(mode.whenToUse));
    }
    // customInstructions (multiline)
    if (mode.customInstructions) {
      lines.push('    customInstructions: ' + serializeMultilineString(mode.customInstructions, 3));
    }
    // groups
    lines.push('    groups: ' + serializeGroups(mode.groups, 3));
    // apiConfigId (optional, from --profile)
    if (mode.apiConfigId) {
      lines.push('    apiConfigId: ' + yamlEscape(mode.apiConfigId));
    }
  });
  return lines.join('\n') + '\n';
}

// --- CLI Argument Parsing ---

function parseArgs() {
  var args = {
    output: DEFAULT_OUTPUT,
    config: CONFIG_PATH,
    profile: null,
    modelConfigs: DEFAULT_MODEL_CONFIGS,
    deploy: false,
    deployGlobal: false,
    globalPath: null,
    targetExtension: 'auto',
    format: 'json'
  };

  for (var i = 2; i < process.argv.length; i++) {
    if (process.argv[i] === '--output' && i + 1 < process.argv.length) {
      args.output = process.argv[++i];
    } else if (process.argv[i] === '--config' && i + 1 < process.argv.length) {
      args.config = process.argv[++i];
    } else if (process.argv[i] === '--profile' && i + 1 < process.argv.length) {
      args.profile = process.argv[++i];
    } else if (process.argv[i] === '--model-configs' && i + 1 < process.argv.length) {
      args.modelConfigs = process.argv[++i];
    } else if (process.argv[i] === '--deploy') {
      args.deploy = true;
    } else if (process.argv[i] === '--deploy-global') {
      args.deployGlobal = true;
    } else if (process.argv[i] === '--global-path' && i + 1 < process.argv.length) {
      args.globalPath = process.argv[++i];
    } else if (process.argv[i] === '--target-extension' && i + 1 < process.argv.length) {
      args.targetExtension = process.argv[++i];
    } else if (process.argv[i] === '--format' && i + 1 < process.argv.length) {
      args.format = process.argv[++i];
      if (args.format !== 'json' && args.format !== 'yaml') {
        console.error('ERROR: --format must be "json" or "yaml"');
        process.exit(1);
      }
    }
  }

  // #595: the Roo 3.51.1+ global modes file is YAML only. Validated after the
  // loop so flag order (--format yaml before or after --deploy-global) does not matter.
  if (args.deployGlobal && args.format !== 'yaml') {
    console.error('ERROR: --deploy-global requires --format yaml (Roo 3.51.1+ global custom_modes.yaml is YAML).');
    process.exit(1);
  }

  // #595 phase 3: validated after the loop too, so flag order does not matter.
  // hasOwnProperty guard (ai-01 review point 4): 'constructor'/'__proto__' pass
  // !EXTENSION_IDS[x] through the prototype chain, and the script would later
  // die in TypeError AFTER --output was already written.
  args.targetExtension = String(args.targetExtension).toLowerCase();
  if (args.targetExtension !== 'auto' &&
      !Object.prototype.hasOwnProperty.call(EXTENSION_IDS, args.targetExtension)) {
    console.error('ERROR: --target-extension must be "auto", "roo" or "zoo" (got "' + args.targetExtension + '").');
    process.exit(1);
  }

  return args;
}

// --- Global deploy path resolution (#595, #595 phase 3) ---

// #595 phase 3: the destination used to be the Roo globalStorage id HARDCODED,
// while Zoo is the only extension on ai-01 and po-2025 -- the global deploy then
// wrote where the running extension never reads. Both ids now live here, and the
// target is resolved (auto) or selected (--target-extension).
var EXTENSION_IDS = {
  roo: 'rooveterinaryinc.roo-cline',
  zoo: 'zoocodeorganization.zoo-code'
};

function globalStorageBase() {
  if (process.platform === 'win32') {
    return path.join(process.env.APPDATA || '', 'Code', 'User', 'globalStorage');
  }
  var configBase = process.env.XDG_CONFIG_HOME || path.join(process.env.HOME || '', '.config');
  return path.join(configBase, 'Code', 'User', 'globalStorage');
}

function extensionInstalled(id) {
  // Installed = the extension's globalStorage directory exists, or its extension
  // directory under ~/.vscode/extensions does (an installed but never-activated
  // extension has no globalStorage yet).
  if (fs.existsSync(path.join(globalStorageBase(), id))) {
    return true;
  }
  var home = process.env.USERPROFILE || process.env.HOME || '';
  if (!home) {
    return false;
  }
  var extRoot = path.join(home, '.vscode', 'extensions');
  var entries;
  try {
    entries = fs.readdirSync(extRoot);
  } catch (e) {
    return false;
  }
  return entries.some(function(entry) { return entry.indexOf(id + '-') === 0; });
}

function resolveExtensionId(requested) {
  if (requested && requested !== 'auto') {
    return EXTENSION_IDS[requested];
  }
  // #595 phase 3, review point 1: for the MODES deploy, Zoo wins as soon as Zoo is
  // INSTALLED. Roo recreates its settings/mcp_settings.json at every startup
  // (roo-code McpHub.ts) and migrate-roo-to-zoo.ps1 COPIES it to Zoo instead of
  // moving it, so a migrated or dual host has both files and the mcp_settings.json
  // probe (Get-ActiveExtension, #3135 -- contract unchanged for its other callers)
  // resolves it back to Roo: modes deployed to Roo stay invisible, the exact
  // defect #595 fixes.
  if (extensionInstalled(EXTENSION_IDS.zoo)) {
    return EXTENSION_IDS.zoo;
  }
  if (extensionInstalled(EXTENSION_IDS.roo)) {
    return EXTENSION_IDS.roo;
  }
  // #595 review follow-up (ai-01, 2026-10-10 afternoon queue): the Roo fallback used
  // to CREATE the Roo globalStorage on hosts with no extension at all -- a directory
  // nothing reads, and one that answers "installed" to every later probe. Refuse
  // instead (#3639 precedent: exit 2). An explicit --target-extension returns early
  // above and bypasses this resolution by design; --global-path never gets here.
  console.error('ERROR: neither Roo Code nor Zoo Code is installed on this host.');
  console.error('A global deploy would create a globalStorage no extension reads -- and one that answers "installed" to every later probe.');
  console.error('Install one of them first, or pass --target-extension explicitly to force.');
  process.exit(2);
}

function resolveGlobalModesPath(explicit, targetExtension) {
  if (explicit) {
    return explicit;
  }
  // Roo/Zoo 3.51.1+ global modes file lives in the VS Code extension globalStorage.
  var id = resolveExtensionId(targetExtension);
  return path.join(globalStorageBase(), id, 'settings', 'custom_modes.yaml');
}

// --- Main ---

// --- Levels ladder (#4115) ---
// Ordered declaration in modes-config.json. Each entry: name (key inside each
// family + slug suffix), profileId (default binding), escalationInstruction.
// The LAST entry is the terminal rung: its instruction escalates beyond the
// ladder (today: Claude CLI). Replaces the hardcoded ['simple','complex'].

function loadLevels(config) {
  var levels = config.levels;
  if (!Array.isArray(levels) || levels.length === 0) {
    console.error('ERROR: modes-config.json must declare an ordered "levels" array (at least 1 entry).');
    process.exit(1);
  }
  var seen = {};
  for (var i = 0; i < levels.length; i++) {
    var l = levels[i];
    if (!l || typeof l.name !== 'string' || !l.name) {
      console.error('ERROR: levels[' + i + '] is missing a non-empty "name".');
      process.exit(1);
    }
    if (seen[l.name]) {
      console.error('ERROR: duplicate level name "' + l.name + '" in levels[].');
      process.exit(1);
    }
    seen[l.name] = true;
  }
  return levels;
}

function main() {
  var args = parseArgs();

  // Load config and template
  var config = JSON.parse(fs.readFileSync(args.config, 'utf8'));
  var template = fs.readFileSync(TEMPLATE_PATH, 'utf8');

  var levels = loadLevels(config);
  var familyNames = Object.keys(config.families);

  // Every family must define one block per declared level (families[level.name]).
  for (var fi = 0; fi < familyNames.length; fi++) {
    var famName = familyNames[fi];
    for (var li = 0; li < levels.length; li++) {
      if (!config.families[famName][levels[li].name]) {
        console.error('ERROR: family "' + famName + '" has no "' + levels[li].name + '" block (levels[] declares it).');
        process.exit(1);
      }
    }
  }

  var levelSuffixes = levels.map(function(l) { return '-' + l.name; }).join(' ou ');
  var modeList = familyNames.reduce(function(acc, f) {
    return acc.concat(levels.map(function(l) { return f + '-' + l.name; }));
  }, []).join(', ');
  var firstLevelName = levels[0].name;

  // Load model-configs if profile specified
  var modeApiConfigs = null;
  var levelApiConfigs = null;
  if (args.profile) {
    console.log('Loading profile: ' + args.profile);
    try {
      var modelConfigsData = JSON.parse(fs.readFileSync(args.modelConfigs, 'utf8'));
      var profile = modelConfigsData.profiles.find(function(p) { return p.name === args.profile; });
      if (!profile) {
        console.error('ERROR: Profile "' + args.profile + '" not found in ' + args.modelConfigs);
        console.error('Available profiles: ' + modelConfigsData.profiles.map(function(p) { return p.name; }).join(', '));
        process.exit(1);
      }
      console.log('Profile found: ' + profile.name);
      console.log('Description: ' + (profile.description || 'N/A'));
      modeApiConfigs = profile.modeOverrides || {};
      levelApiConfigs = profile.levelOverrides || {};
      console.log('Mode overrides: ' + Object.keys(modeApiConfigs).length + ' modes'
        + (Object.keys(levelApiConfigs).length ? ', level overrides: ' + Object.keys(levelApiConfigs).join(', ') : ''));
    } catch (e) {
      console.error('ERROR: Failed to load model-configs.json: ' + e.message);
      process.exit(1);
    }
  }

  console.log('\nGenerating modes from config + template...\n');

  var modes = [];

  for (var family of familyNames) {
    var fam = config.families[family];

    for (var li = 0; li < levels.length; li++) {
      var level = levels[li].name;
      var isTerminal = li === levels.length - 1;
      var nextLevelName = isTerminal ? null : levels[li + 1].name;
      // Pre-render the level's escalation instruction ({{FAMILY}}/{{NEXT_LEVEL}}
      // are resolved here, not by renderTemplate, so instruction text cannot be
      // re-processed by a later variable pass).
      var escalationText = String(levels[li].escalationInstruction || '')
        .replace(/\{\{FAMILY\}\}/g, family)
        .replace(/\{\{NEXT_LEVEL\}\}/g, nextLevelName || '');
      var levelDef = fam[level];

      // Detect capability groups (per-level override or family-level fallback)
      var effectiveGroups = levelDef.groups || fam.groups;
      var groupNames = effectiveGroups.map(function(g) { return Array.isArray(g) ? g[0] : g; });
      var hasCommand = groupNames.indexOf('command') >= 0;
      // #1482: Anti-regression — NO mode should ever have native terminal (command group).
      // All terminal access goes through win-cli MCP. If this fires, modes-config.json
      // or a level override accidentally added "command" to the groups array.
      if (hasCommand) {
        console.error('ERROR: Mode ' + family + '-' + level + ' has "command" in groups (' + JSON.stringify(effectiveGroups) + ').');
        console.error('Per #1482, ALL Roo modes must use win-cli exclusively. Remove "command" from groups.');
        process.exit(1);
      }
      var hasEdit = groupNames.indexOf('edit') >= 0;
      // #725: code and debug families always have win-cli (even without native command group)
      // win-cli provides shell access (PowerShell, GitBash, CMD) for all modes
      var winCliFamilies = ['code', 'debug'];
      var familyUsesWinCli = winCliFamilies.indexOf(family) >= 0 && levelDef.useWinCli !== false;
      var hasWinCli = familyUsesWinCli || (levelDef.useWinCli === true && !hasCommand);

      // #725: BOTH_TERMINALS = mode has both native terminal AND win-cli (for shell access)
      var bothTerminals = hasCommand && hasWinCli;
      // #725: ONLY_WIN_CLI = mode has win-cli ONLY (no native terminal)
      var onlyWinCli = hasWinCli && !hasCommand;

      var vars = {
        FAMILY: family,
        LEVEL: level,
        LEVEL_LABEL: capitalize(level),
        // Ladder position, not level name: every non-terminal rung gets the
        // economical block, the last rung gets the powerful/terminal one.
        IS_ECONOMICAL: !isTerminal,
        IS_TERMINAL: isTerminal,
        NEXT_LEVEL_NAME: nextLevelName,
        FIRST_LEVEL_NAME: firstLevelName,
        LEVEL_SUFFIXES: levelSuffixes,
        MODE_LIST: modeList,
        // NO_COMMAND: only show redirect message for pure-delegate modes (no win-cli)
        NO_COMMAND: !hasCommand && !hasWinCli,
        WIN_CLI_FALLBACK: hasWinCli,
        ONLY_WIN_CLI: onlyWinCli,
        BOTH_TERMINALS: bothTerminals,
        NO_EDIT: !hasEdit,
        ESCALATION_CRITERIA: levelDef.escalationCriteria || [],
        DEESCALATION_CRITERIA: levelDef.deescalationCriteria || [],
        ADDITIONAL_INSTRUCTIONS: fam.additionalInstructions || '',
        // Instruction-derived vars LAST: renderTemplate substitutes in insertion
        // order, so a value must never be re-processed by a later key's pass.
        ESCALATION_INSTRUCTION: isTerminal ? '' : escalationText,
        TERMINAL_ESCALATION: isTerminal ? escalationText : '',
      };

      var customInstructions = renderTemplate(template, vars);

      var mode = {
        slug: family + '-' + level,
        name: fam.emoji + ' ' + capitalize(family) + ' ' + capitalize(level),
        roleDefinition: levelDef.roleDefinition,
        description: levelDef.description || '',
        whenToUse: levelDef.whenToUse || '',
        groups: effectiveGroups,
        customInstructions: customInstructions,
      };

      // Add apiConfigId if profile is specified (slug override wins over level override)
      if (modeApiConfigs) {
        var apiConfigId = modeApiConfigs[mode.slug] || levelApiConfigs[level];
        if (apiConfigId) {
          mode.apiConfigId = apiConfigId;
          console.log('    -> apiConfigId: ' + apiConfigId);
        } else {
          console.warn('WARNING: profile has no binding for ' + mode.slug + ' (neither modeOverrides["' + mode.slug + '"] nor levelOverrides["' + level + '"]).');
        }
      }
      console.log('  ' + mode.slug.padEnd(24) + ' ' + customInstructions.length + ' chars');
      modes.push(mode);
    }
  }

  var output = { customModes: modes };

  // Ensure output directory
  var outputDir = path.dirname(args.output);
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  var outputContent;
  if (args.format === 'yaml') {
    outputContent = jsonToYaml(output);
  } else {
    outputContent = JSON.stringify(output, null, 2);
  }

  fs.writeFileSync(args.output, outputContent, 'utf8');

  var totalKB = (Buffer.byteLength(outputContent, 'utf8') / 1024).toFixed(1);
  console.log('\nGenerated ' + modes.length + ' modes (' + familyNames.length + ' families x ' + levels.length + ' levels)');
  console.log('Format: ' + args.format.toUpperCase());
  if (args.profile) {
    console.log('With profile: ' + args.profile);
  }
  console.log('Total size: ' + totalKB + ' KB');
  console.log('Output: ' + args.output);

  // Deploy to .roomodes if requested
  if (args.deploy) {
    var roomodesPath = path.join(ROOT, '.roomodes');
    fs.copyFileSync(args.output, roomodesPath);
    console.log('Deployed to: ' + roomodesPath);
  }

  // Deploy to the Roo/Zoo global custom_modes.yaml if requested (#595, #595 phase 3)
  if (args.deployGlobal) {
    var globalModesPath = resolveGlobalModesPath(args.globalPath, args.targetExtension);
    var globalModesDir = path.dirname(globalModesPath);
    if (!fs.existsSync(globalModesDir)) {
      fs.mkdirSync(globalModesDir, { recursive: true });
    }
    fs.copyFileSync(args.output, globalModesPath);
    // #595 phase 3: name the resolution in the log -- a wrong pick (Zoo installed,
    // Roo globalStorage left over) used to be invisible: the deploy succeeded and
    // the modes simply never appeared.
    console.log('Target: ' + (args.globalPath
      ? 'explicit --global-path'
      : '--target-extension ' + args.targetExtension));
    console.log('Deployed to global: ' + globalModesPath);
  }
}

main();
