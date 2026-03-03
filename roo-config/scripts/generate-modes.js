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

// --- CLI Argument Parsing ---

function parseArgs() {
  var args = {
    output: DEFAULT_OUTPUT,
    profile: null,
    modelConfigs: DEFAULT_MODEL_CONFIGS,
    deploy: false
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
      var hasEdit = groupNames.indexOf('edit') >= 0;
      var hasWinCli = levelDef.useWinCli === true && !hasCommand;

      var vars = {
        FAMILY: family,
        LEVEL: level,
        LEVEL_LABEL: capitalize(level),
        IS_SIMPLE: level === 'simple',
        IS_COMPLEX: level === 'complex',
        // NO_COMMAND: only show redirect message for pure-delegate modes (no win-cli)
        NO_COMMAND: !hasCommand && !hasWinCli,
        WIN_CLI_FALLBACK: hasWinCli,
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

  fs.writeFileSync(args.output, JSON.stringify(output, null, 2), 'utf8');

  var totalKB = (Buffer.byteLength(JSON.stringify(output, null, 2), 'utf8') / 1024).toFixed(1);
  console.log('\nGenerated ' + modes.length + ' modes (' + Object.keys(config.families).length + ' families x 2 levels)');
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
