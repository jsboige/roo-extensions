#!/usr/bin/env node
/**
 * generate-modes.js - Generate .roomodes from config + template
 *
 * Reads:  roo-config/modes/modes-config.json (data)
 *         roo-config/modes/templates/commons/mode-instructions.md (template)
 *         roo-config/model-configs.json (optional, for --profile)
 * Writes: roo-config/modes/generated/simple-complex.roomodes
 *
 * Options:
 *   --output <path>      Output file path (default: simple-complex.roomodes)
 *   --profile <name>     Apply profile from model-configs.json (sets apiConfigId per mode)
 *   --model-configs <path> Path to model-configs.json (default: roo-config/model-configs.json)
 *   --deploy             Also copy to .roomodes at project root
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
    profile: null,
    modelConfigs: DEFAULT_MODEL_CONFIGS,
    deploy: false,
    format: 'json'
  };

  for (var i = 2; i < process.argv.length; i++) {
    if (process.argv[i] === '--output' && i + 1 < process.argv.length) {
      args.output = process.argv[++i];
    } else if (process.argv[i] === '--profile' && i + 1 < process.argv.length) {
      args.profile = process.argv[++i];
    } else if (process.argv[i] === '--model-configs' && i + 1 < process.argv.length) {
      args.modelConfigs = process.argv[++i];
    } else if (process.argv[i] === '--deploy') {
      args.deploy = true;
    } else if (process.argv[i] === '--format' && i + 1 < process.argv.length) {
      args.format = process.argv[++i];
      if (args.format !== 'json' && args.format !== 'yaml') {
        console.error('ERROR: --format must be "json" or "yaml"');
        process.exit(1);
      }
    }
  }

  return args;
}

// --- Main ---

function main() {
  var args = parseArgs();

  // Load config and template
  var config = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
  var template = fs.readFileSync(TEMPLATE_PATH, 'utf8');

  // Load model-configs if profile specified
  var modeApiConfigs = null;
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
      // modeApiConfigs comes from profile.modeOverrides
      modeApiConfigs = profile.modeOverrides || {};
      console.log('Mode overrides: ' + Object.keys(modeApiConfigs).length + ' modes');
    } catch (e) {
      console.error('ERROR: Failed to load model-configs.json: ' + e.message);
      process.exit(1);
    }
  }

  console.log('\nGenerating modes from config + template...\n');

  var modes = [];

  for (var family of Object.keys(config.families)) {
    var fam = config.families[family];

    for (var level of ['simple', 'complex']) {
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
      // #725: code and debug families always have win-cli (even with native command group)
      // This provides SSH tools that native terminal doesn't have
      var winCliFamilies = ['code', 'debug'];
      var familyUsesWinCli = winCliFamilies.indexOf(family) >= 0 && levelDef.useWinCli !== false;
      var hasWinCli = familyUsesWinCli || (levelDef.useWinCli === true && !hasCommand);

      // #725: BOTH_TERMINALS = mode has both native terminal AND win-cli (for SSH tools)
      var bothTerminals = hasCommand && hasWinCli;
      // #725: ONLY_WIN_CLI = mode has win-cli ONLY (no native terminal)
      var onlyWinCli = hasWinCli && !hasCommand;

      var vars = {
        FAMILY: family,
        LEVEL: level,
        LEVEL_LABEL: capitalize(level),
        IS_SIMPLE: level === 'simple',
        IS_COMPLEX: level === 'complex',
        // NO_COMMAND: only show redirect message for pure-delegate modes (no win-cli)
        NO_COMMAND: !hasCommand && !hasWinCli,
        WIN_CLI_FALLBACK: hasWinCli,
        ONLY_WIN_CLI: onlyWinCli,
        BOTH_TERMINALS: bothTerminals,
        NO_EDIT: !hasEdit,
        ESCALATION_CRITERIA: levelDef.escalationCriteria || [],
        DEESCALATION_CRITERIA: levelDef.deescalationCriteria || [],
        ADDITIONAL_INSTRUCTIONS: fam.additionalInstructions || '',
        COMPLEX_ESCALATION: config.complexEscalationInstructions || '',
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

      // Add apiConfigId if profile is specified
      if (modeApiConfigs) {
        var apiConfigId = modeApiConfigs[mode.slug];
        if (apiConfigId) {
          mode.apiConfigId = apiConfigId;
          console.log('    -> apiConfigId: ' + apiConfigId);
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
  console.log('\nGenerated ' + modes.length + ' modes (' + Object.keys(config.families).length + ' families x 2 levels)');
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
}

main();
