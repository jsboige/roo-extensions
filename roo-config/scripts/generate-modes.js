#!/usr/bin/env node
/**
 * generate-modes.js - Generate .roomodes from config + template
 *
 * Reads:  roo-config/modes/modes-config.json (data)
 *         roo-config/modes/templates/commons/mode-instructions.md (template)
 * Writes: roo-config/modes/generated/simple-complex.roomodes
 */
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..', '..');
const CONFIG_PATH = path.join(ROOT, 'roo-config', 'modes', 'modes-config.json');
const TEMPLATE_PATH = path.join(ROOT, 'roo-config', 'modes', 'templates', 'commons', 'mode-instructions.md');
const DEFAULT_OUTPUT = path.join(ROOT, 'roo-config', 'modes', 'generated', 'simple-complex.roomodes');

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

// --- Main ---

function main() {
  var outputArg = process.argv.indexOf('--output');
  var outputPath = outputArg >= 0 ? process.argv[outputArg + 1] : DEFAULT_OUTPUT;

  // Load config and template
  var config = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
  var template = fs.readFileSync(TEMPLATE_PATH, 'utf8');

  console.log('Generating modes from config + template...\n');

  var modes = [];

  for (var family of Object.keys(config.families)) {
    var fam = config.families[family];

    for (var level of ['simple', 'complex']) {
      var levelDef = fam[level];

      // Detect capability groups (handle both string and array-with-options formats)
      var groupNames = fam.groups.map(function(g) { return Array.isArray(g) ? g[0] : g; });
      var hasCommand = groupNames.indexOf('command') >= 0;
      var hasEdit = groupNames.indexOf('edit') >= 0;

      var vars = {
        FAMILY: family,
        LEVEL: level,
        LEVEL_LABEL: capitalize(level),
        IS_SIMPLE: level === 'simple',
        IS_COMPLEX: level === 'complex',
        NO_COMMAND: !hasCommand,
        NO_EDIT: !hasEdit,
        ESCALATION_CRITERIA: levelDef.escalationCriteria || [],
        DEESCALATION_CRITERIA: levelDef.deescalationCriteria || [],
        ADDITIONAL_INSTRUCTIONS: fam.additionalInstructions || '',
      };

      var customInstructions = renderTemplate(template, vars);

      var mode = {
        slug: family + '-' + level,
        name: fam.emoji + ' ' + capitalize(family) + ' ' + capitalize(level),
        roleDefinition: levelDef.roleDefinition,
        description: levelDef.description || '',
        whenToUse: levelDef.whenToUse || '',
        groups: fam.groups,
        customInstructions: customInstructions,
      };

      console.log('  ' + mode.slug.padEnd(24) + ' ' + customInstructions.length + ' chars');
      modes.push(mode);
    }
  }

  var output = { customModes: modes };

  // Ensure output directory
  var outputDir = path.dirname(outputPath);
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  fs.writeFileSync(outputPath, JSON.stringify(output, null, 2), 'utf8');

  var totalKB = (Buffer.byteLength(JSON.stringify(output, null, 2), 'utf8') / 1024).toFixed(1);
  console.log('\nGenerated ' + modes.length + ' modes (' + Object.keys(config.families).length + ' families x 2 levels)');
  console.log('Total size: ' + totalKB + ' KB');
  console.log('Output: ' + outputPath);
}

main();
