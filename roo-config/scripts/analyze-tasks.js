#!/usr/bin/env node
/**
 * Analyze Roo task forensics for mode adjustment insights
 * Reads ui_messages.json to extract mode, token usage, subtask patterns
 */
const fs = require('fs');
const path = require('path');

const taskDir = 'C:/Users/MYIA/AppData/Roaming/Code/User/globalStorage/rooveterinaryinc.roo-cline/tasks';
const N = parseInt(process.argv[2] || '100', 10);
const VERBOSE = process.argv.includes('--verbose');

// Get tasks sorted by mtime
const allTasks = fs.readdirSync(taskDir)
  .filter(d => { try { return fs.statSync(path.join(taskDir, d)).isDirectory(); } catch { return false; } })
  .map(d => ({ id: d, mtime: fs.statSync(path.join(taskDir, d)).mtimeMs }))
  .sort((a, b) => b.mtime - a.mtime)
  .slice(0, N);

const modeStats = {};
let analyzed = 0;
const taskDetails = [];

for (const t of allTasks) {
  const uiPath = path.join(taskDir, t.id, 'ui_messages.json');
  const apiPath = path.join(taskDir, t.id, 'api_conversation_history.json');

  let msgs, apiMsgs;
  try {
    msgs = JSON.parse(fs.readFileSync(uiPath, 'utf8'));
  } catch { continue; }

  // Extract task text
  const firstText = msgs.find(m => m.type === 'say' && m.say === 'text');
  const taskText = firstText ? (firstText.text || '').substring(0, 120).replace(/\n/g, ' ') : '';

  // Extract mode from API conversation system prompt
  let mode = 'unknown';
  try {
    apiMsgs = JSON.parse(fs.readFileSync(apiPath, 'utf8'));
    // Look in first message for mode hint from system prompt or role definition
    if (apiMsgs.length > 0) {
      const firstContent = apiMsgs[0].content;
      if (Array.isArray(firstContent)) {
        for (const block of firstContent) {
          if (block.type === 'text') {
            // Check for mode slug patterns in system prompts
            const modeMatch = block.text.match(/You are (?:Roo |the )?(Code|Debug|Architect|Ask|Orchestrator|Manager)/i);
            if (modeMatch) {
              mode = modeMatch[1].toLowerCase();
              break;
            }
            // Check for explicit mode mention
            const slugMatch = block.text.match(/\bmode[:\s]+["']?(code|debug|architect|ask|orchestrator|manager)[-_]?(simple|complex)?["']?/i);
            if (slugMatch) {
              mode = slugMatch[1].toLowerCase() + (slugMatch[2] ? '-' + slugMatch[2].toLowerCase() : '');
              break;
            }
          }
        }
      }
    }
  } catch {}

  // Extract metrics from ui_messages
  let totalTokIn = 0, totalTokOut = 0, totalCost = 0;
  let apiReqs = 0, subtaskCount = 0, condensations = 0;
  let toolsUsed = {};
  let hasSwitchMode = false, hasNewTask = false;

  for (const m of msgs) {
    if (m.say === 'api_req_started' && m.text) {
      try {
        const info = JSON.parse(m.text);
        totalTokIn += info.tokensIn || 0;
        totalTokOut += info.tokensOut || 0;
        totalCost += info.cost || 0;
        apiReqs++;
      } catch {}
    }
    if (m.say === 'subtask_result') subtaskCount++;
    if (m.say === 'condense_context') condensations++;
  }

  // Extract tools from API conversation
  if (apiMsgs) {
    for (const msg of apiMsgs) {
      if (Array.isArray(msg.content)) {
        for (const block of msg.content) {
          if (block.type === 'tool_use') {
            toolsUsed[block.name] = (toolsUsed[block.name] || 0) + 1;
            if (block.name === 'switch_mode') hasSwitchMode = true;
            if (block.name === 'new_task') hasNewTask = true;
          }
        }
      }
    }
  }

  analyzed++;
  const detail = {
    id: t.id.substring(0, 12),
    date: new Date(t.mtime).toISOString().substring(0, 10),
    mode,
    task: taskText,
    apiReqs,
    tokIn: totalTokIn,
    tokOut: totalTokOut,
    subtasks: subtaskCount,
    condensations,
    toolsUsed,
    hasSwitchMode,
    hasNewTask,
    msgCount: msgs.length,
    totalToolUses: Object.values(toolsUsed).reduce((a, b) => a + b, 0)
  };
  taskDetails.push(detail);

  if (!modeStats[mode]) {
    modeStats[mode] = { count: 0, tokIn: 0, tokOut: 0, apiReqs: 0, subtasks: 0, condensations: 0, switchModes: 0, newTasks: 0, tools: {}, msgCounts: [], tokInList: [], tokOutList: [] };
  }
  const s = modeStats[mode];
  s.count++;
  s.tokIn += totalTokIn;
  s.tokOut += totalTokOut;
  s.apiReqs += apiReqs;
  s.subtasks += subtaskCount;
  s.condensations += condensations;
  if (hasSwitchMode) s.switchModes++;
  if (hasNewTask) s.newTasks++;
  s.msgCounts.push(msgs.length);
  s.tokInList.push(totalTokIn);
  s.tokOutList.push(totalTokOut);
  for (const [tool, count] of Object.entries(toolsUsed)) {
    s.tools[tool] = (s.tools[tool] || 0) + count;
  }
}

// Report
console.log('=== ROO TASK FORENSICS ===');
console.log('Analyzed: ' + analyzed + ' / ' + allTasks.length + ' tasks');
console.log('Date range: ' + (taskDetails[taskDetails.length - 1] ? taskDetails[taskDetails.length - 1].date : '?') + ' to ' + (taskDetails[0] ? taskDetails[0].date : '?'));

const totalTokIn = taskDetails.reduce((s, t) => s + t.tokIn, 0);
const totalTokOut = taskDetails.reduce((s, t) => s + t.tokOut, 0);
console.log('Total tokens: in=' + totalTokIn.toLocaleString() + ' out=' + totalTokOut.toLocaleString());

console.log('\n=== MODE DISTRIBUTION ===');
const sortedModes = Object.entries(modeStats).sort((a, b) => b[1].count - a[1].count);
for (const [mode, s] of sortedModes) {
  const avgMsgs = Math.round(s.msgCounts.reduce((a, b) => a + b, 0) / s.count);
  const avgTokIn = Math.round(s.tokIn / s.count);
  const avgTokOut = Math.round(s.tokOut / s.count);
  const topTools = Object.entries(s.tools).sort((a, b) => b[1] - a[1]).slice(0, 8).map(function(e) { return e[0] + '(' + e[1] + ')'; }).join(', ');

  console.log('\n  ' + mode + ' (' + s.count + ' tasks, ' + (s.count / analyzed * 100).toFixed(0) + '%)');
  console.log('    Avg: ' + avgMsgs + ' ui_msgs, ' + avgTokIn.toLocaleString() + ' tok_in, ' + avgTokOut.toLocaleString() + ' tok_out');
  console.log('    Subtasks: ' + s.subtasks + ' total (' + (s.subtasks / s.count).toFixed(1) + ' avg), Condensations: ' + s.condensations);
  console.log('    switch_mode: ' + s.switchModes + ', new_task: ' + s.newTasks);
  console.log('    Top tools: ' + topTools);

  // Percentiles
  var sorted = s.tokOutList.slice().sort((a, b) => a - b);
  if (sorted.length >= 3) {
    var p50 = sorted[Math.floor(sorted.length * 0.5)];
    var p90 = sorted[Math.floor(sorted.length * 0.9)];
    var max = sorted[sorted.length - 1];
    console.log('    tok_out: p50=' + p50.toLocaleString() + ' p90=' + p90.toLocaleString() + ' max=' + max.toLocaleString());
  }
  var sortedIn = s.tokInList.slice().sort((a, b) => a - b);
  if (sortedIn.length >= 3) {
    var p50i = sortedIn[Math.floor(sortedIn.length * 0.5)];
    var p90i = sortedIn[Math.floor(sortedIn.length * 0.9)];
    var maxi = sortedIn[sortedIn.length - 1];
    console.log('    tok_in:  p50=' + p50i.toLocaleString() + ' p90=' + p90i.toLocaleString() + ' max=' + maxi.toLocaleString());
  }
}

// Task complexity classification
console.log('\n=== TASK COMPLEXITY ANALYSIS ===');
var complexityBuckets = { tiny: [], small: [], medium: [], large: [], huge: [] };
for (var i = 0; i < taskDetails.length; i++) {
  var td = taskDetails[i];
  if (td.apiReqs <= 2) complexityBuckets.tiny.push(td);
  else if (td.apiReqs <= 10) complexityBuckets.small.push(td);
  else if (td.apiReqs <= 50) complexityBuckets.medium.push(td);
  else if (td.apiReqs <= 200) complexityBuckets.large.push(td);
  else complexityBuckets.huge.push(td);
}
for (var bucket of Object.keys(complexityBuckets)) {
  var bTasks = complexityBuckets[bucket];
  if (bTasks.length === 0) continue;
  var avgTokOutB = Math.round(bTasks.reduce(function(s, t) { return s + t.tokOut; }, 0) / bTasks.length);
  var avgSubtasksB = (bTasks.reduce(function(s, t) { return s + t.subtasks; }, 0) / bTasks.length).toFixed(1);
  var modesB = {};
  for (var bt of bTasks) modesB[bt.mode] = (modesB[bt.mode] || 0) + 1;
  var modeStr = Object.entries(modesB).sort((a, b) => b[1] - a[1]).map(function(e) { return e[0] + ':' + e[1]; }).join(' ');
  console.log('  ' + bucket.padEnd(7) + ' (' + String(bTasks.length).padStart(3) + ' tasks): avg tok_out=' + String(avgTokOutB).padStart(8) + ', subtasks=' + String(avgSubtasksB).padStart(5) + ', modes: ' + modeStr);
}

// Subtask patterns
console.log('\n=== SUBTASK / NEW_TASK PATTERNS ===');
var withSubtasks = taskDetails.filter(function(t) { return t.subtasks > 0; }).sort((a, b) => b.subtasks - a.subtasks);
console.log('Tasks with subtasks: ' + withSubtasks.length + '/' + analyzed);
for (var j = 0; j < Math.min(10, withSubtasks.length); j++) {
  var st = withSubtasks[j];
  console.log('  ' + st.date + ' ' + st.mode.padEnd(13) + ' subtasks=' + st.subtasks + ' reqs=' + st.apiReqs + ' | ' + st.task.substring(0, 80));
}

// Condensation patterns
console.log('\n=== CONTEXT CONDENSATIONS ===');
var withCondensations = taskDetails.filter(function(t) { return t.condensations > 0; }).sort((a, b) => b.condensations - a.condensations);
console.log('Tasks with condensations: ' + withCondensations.length + '/' + analyzed);
for (var k = 0; k < Math.min(10, withCondensations.length); k++) {
  var ct = withCondensations[k];
  console.log('  ' + ct.date + ' ' + ct.mode.padEnd(13) + ' condensations=' + ct.condensations + ' reqs=' + ct.apiReqs + ' tok_in=' + ct.tokIn.toLocaleString() + ' | ' + ct.task.substring(0, 80));
}

// Recent task listing
if (VERBOSE) {
  console.log('\n=== RECENT TASKS DETAIL ===');
  for (var v = 0; v < Math.min(30, taskDetails.length); v++) {
    var vt = taskDetails[v];
    var flags = [vt.hasSwitchMode ? 'SW' : '', vt.hasNewTask ? 'NT' : '', vt.subtasks > 0 ? 'sub=' + vt.subtasks : ''].filter(Boolean).join(' ');
    console.log('  ' + vt.date + ' ' + vt.mode.padEnd(13) + ' reqs=' + String(vt.apiReqs).padStart(4) + ' tok_out=' + String(vt.tokOut).padStart(7) + ' ' + flags.padEnd(10) + ' | ' + vt.task.substring(0, 70));
  }
}
