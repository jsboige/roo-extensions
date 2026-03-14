#!/usr/bin/env node
/**
 * Token Usage Report Generator (#677)
 *
 * Aggregates token consumption from Claude Code JSONL session files.
 * Produces a report by model, machine, and time period.
 *
 * Usage:
 *   node scripts/monitoring/token-usage-report.js [--days 7] [--machine myia-po-2025]
 *
 * Output: Markdown report to stdout (or --output <file>)
 */

import fs from 'fs';
import path from 'path';
import os from 'os';
import { globSync } from 'fs'; // Node 22+ has globSync; fallback below

// ── Cost per 1M tokens (USD) — approximate, update as needed ──────────────────
const PRICING = {
    // Anthropic Claude
    'claude-opus-4-6':             { input: 15.00, output: 75.00 },
    'claude-sonnet-4-6':           { input:  3.00, output: 15.00 },
    'claude-sonnet-4-5-20250929':  { input:  3.00, output: 15.00 },
    'claude-haiku-4-5-20251001':   { input:  0.80, output:  4.00 },
    // z.ai / GLM
    'glm-5':                       { input:  0.70, output:  2.80 },
    'glm-4.7':                     { input:  0.14, output:  0.56 },
    'glm-4.7-flash':               { input:  0.07, output:  0.28 },
    'glm-4.5-air':                 { input:  0.07, output:  0.14 },
};

const DEFAULT_PRICE = { input: 1.00, output: 3.00 }; // fallback

function getPrice(model) {
    // Exact match
    if (PRICING[model]) return PRICING[model];
    // Prefix match
    for (const [key, price] of Object.entries(PRICING)) {
        if (model.startsWith(key.split('-').slice(0, 2).join('-'))) return price;
    }
    return DEFAULT_PRICE;
}

// ── Argument parsing ───────────────────────────────────────────────────────────
const args = process.argv.slice(2);

function getArg(name) {
    const idx = args.indexOf(name);
    return idx !== -1 ? args[idx + 1] || null : null;
}

const days = parseInt(getArg('--days') || '7', 10);
const machineFilter = getArg('--machine');
const outputFile = getArg('--output');
const cutoffMs = Date.now() - days * 24 * 60 * 60 * 1000;

// ── Discover Claude project directories ───────────────────────────────────────
function getClaudeProjectDirs() {
    const homeDir = os.homedir();
    const projectsRoot = path.join(homeDir, '.claude', 'projects');
    if (!fs.existsSync(projectsRoot)) return [];

    return fs.readdirSync(projectsRoot)
        .map(d => path.join(projectsRoot, d))
        .filter(d => fs.statSync(d).isDirectory());
}

// ── Parse a single JSONL file ──────────────────────────────────────────────────
function parseJsonlFile(filePath) {
    const stats = fs.statSync(filePath);
    const fileMs = stats.mtimeMs;
    if (fileMs < cutoffMs) return null; // Skip old files

    const lines = fs.readFileSync(filePath, 'utf-8').split('\n');
    const sessions = [];
    let currentModel = null;
    let sessionTokens = { input: 0, output: 0, cache_read: 0, cache_write: 0 };
    let sessionStart = fileMs;
    let apiCalls = 0;

    for (const line of lines) {
        if (!line.trim()) continue;
        let obj;
        try { obj = JSON.parse(line); } catch { continue; }

        if (obj.type === 'assistant' && obj.message) {
            const msg = obj.message;
            const model = msg.model || currentModel;
            const usage = msg.usage || {};

            if (model) currentModel = model;

            if (usage.input_tokens !== undefined || usage.output_tokens !== undefined) {
                apiCalls++;
                sessionTokens.input      += (usage.input_tokens || 0);
                sessionTokens.output     += (usage.output_tokens || 0);
                sessionTokens.cache_read += (usage.cache_read_input_tokens || 0);
                sessionTokens.cache_write += (usage.cache_creation_input_tokens || 0);
            }
        } else if (obj.type === 'system' && obj.timestamp) {
            // Session boundary marker
            sessionStart = new Date(obj.timestamp).getTime() || sessionStart;
        }
    }

    if (apiCalls === 0 || !currentModel) return null;

    return {
        file: filePath,
        model: currentModel,
        tokens: sessionTokens,
        apiCalls,
        fileMs,
    };
}

// ── Aggregate data ─────────────────────────────────────────────────────────────
function aggregate() {
    const projectDirs = getClaudeProjectDirs();
    const byModel = {};

    let totalFiles = 0;
    let parsedFiles = 0;

    for (const projDir of projectDirs) {
        const files = fs.readdirSync(projDir)
            .filter(f => f.endsWith('.jsonl'))
            .map(f => path.join(projDir, f));

        for (const file of files) {
            totalFiles++;
            try {
                const result = parseJsonlFile(file);
                if (!result) continue;
                parsedFiles++;

                const model = result.model;
                if (!byModel[model]) {
                    byModel[model] = { sessions: 0, apiCalls: 0, input: 0, output: 0, cache_read: 0, cache_write: 0 };
                }
                byModel[model].sessions++;
                byModel[model].apiCalls += result.apiCalls;
                byModel[model].input    += result.tokens.input;
                byModel[model].output   += result.tokens.output;
                byModel[model].cache_read  += result.tokens.cache_read;
                byModel[model].cache_write += result.tokens.cache_write;
            } catch (e) {
                // Skip unreadable files
            }
        }
    }

    return { byModel, totalFiles, parsedFiles };
}

// ── Format numbers ─────────────────────────────────────────────────────────────
function fmtNum(n) {
    if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
    if (n >= 1_000) return `${(n / 1_000).toFixed(0)}K`;
    return String(n);
}

function fmtCost(usd) {
    if (usd < 0.01) return '<$0.01';
    return `$${usd.toFixed(2)}`;
}

// ── Generate report ────────────────────────────────────────────────────────────
function generateReport(data) {
    const { byModel, totalFiles, parsedFiles } = data;
    const machine = os.hostname();
    const now = new Date().toISOString().slice(0, 10);

    const lines = [];
    lines.push(`# Token Usage Report — ${machine}`);
    lines.push(`**Period:** Last ${days} days (since ${new Date(cutoffMs).toISOString().slice(0, 10)})`);
    lines.push(`**Generated:** ${now}`);
    lines.push(`**Source:** Claude Code JSONL sessions (${parsedFiles}/${totalFiles} files parsed)`);
    lines.push('');
    lines.push('## By Model');
    lines.push('');
    lines.push('| Model | Sessions | API Calls | Input | Output | Cache Read | Cost (est.) |');
    lines.push('|-------|----------|-----------|-------|--------|------------|-------------|');

    let grandCost = 0;
    let grandInput = 0;
    let grandOutput = 0;

    // Compute costs first, then sort by cost descending
    const modelEntries = Object.entries(byModel)
        .filter(([model]) => model !== '<synthetic>' && model !== 'unknown')
        .map(([model, stats]) => {
            const price = getPrice(model);
            // Cache reads billed at ~10% of input price
            const cost = ((stats.input / 1e6) * price.input)
                       + ((stats.output / 1e6) * price.output)
                       + ((stats.cache_read / 1e6) * price.input * 0.1);
            return { model, stats, price, cost };
        })
        .sort((a, b) => b.cost - a.cost);

    for (const { model, stats, cost } of modelEntries) {
        grandCost += cost;
        grandInput += stats.input;
        grandOutput += stats.output;

        lines.push(
            `| \`${model}\` | ${stats.sessions} | ${stats.apiCalls} | ${fmtNum(stats.input)} | ${fmtNum(stats.output)} | ${fmtNum(stats.cache_read)} | ${fmtCost(cost)} |`
        );
    }

    lines.push('');
    lines.push('## Summary');
    lines.push('');
    lines.push(`- **Total input tokens:** ${fmtNum(grandInput)}`);
    lines.push(`- **Total output tokens:** ${fmtNum(grandOutput)}`);
    lines.push(`- **Estimated cost:** ${fmtCost(grandCost)}`);
    lines.push('');
    lines.push('## Notes');
    lines.push('');
    lines.push('- **Cache reads** are counted per API call: a 100K-token context makes 100 calls = 10M cache read tokens counted');
    lines.push('- Cache read pricing: ~10% of input price (e.g., $1.50/MTok for Opus vs $15/MTok input)');
    lines.push('- **All Claude Code projects** on this machine are included, not just roo-extensions');
    lines.push('- z.ai / GLM sessions not captured here (Roo Code uses different trace format)');
    lines.push('- Cross-machine aggregation requires running this script on each machine separately');
    lines.push('- For Anthropic billing verification: console.anthropic.com/usage');
    lines.push('');
    lines.push('---');
    lines.push(`*Generated by scripts/monitoring/token-usage-report.js — Issue #677*`);

    return lines.join('\n');
}

// ── Main ───────────────────────────────────────────────────────────────────────
const data = aggregate();
const report = generateReport(data);

if (outputFile) {
    fs.writeFileSync(outputFile, report, 'utf-8');
    console.error(`Report written to ${outputFile}`);
} else {
    process.stdout.write(report + '\n');
}
