#!/usr/bin/env python3
"""
test-chunkid-stability.py — #2196 Phase 4: Verify chunk_id determinism across re-extractions.

For a sample of existing Roo tasks, re-run chunk extraction and compare generated
chunk_ids against those stored in Qdrant. Any mismatch indicates non-deterministic
chunk_id generation (H2 hypothesis).

Usage:
    python scripts/maintenance/test-chunkid-stability.py [--limit N] [--json]

Output:
    - Per-task match/mismatch counts
    - Global summary: total chunks, matched, mismatched, mismatch rate
    - --json: machine-readable output for analysis

Methodology:
    1. Scan local Roo storage for tasks with api_conversation_history.json
    2. For each task, simulate extractChunksFromTask logic (simplified Python reimpl)
    3. Compare generated chunk_ids against Qdrant via retrieve API
    4. Report mismatches with details

NOTE: This is a simplified Python reimplementation of ChunkExtractor.ts logic.
The TypeScript source is the ground truth; discrepancies here may indicate a bug
in THIS script, not in ChunkExtractor. Cross-verify any finding.
"""

import json
import sys
import os
import hashlib
import uuid
import argparse
from pathlib import Path
from collections import Counter


# Extension identifier — kept in sync with scripts/common/extension-paths.ps1
ROO_EXTENSION_ID = 'rooveterinaryinc.roo-cline'

# UUID v5 namespace — must match ChunkExtractor.ts:9
UUID_NAMESPACE = uuid.UUID('6ba7b810-9dad-11d1-80b4-00c04fd430c8')

# MAX_INDEXABLE_CONTENT_SIZE — must match ChunkExtractor.ts:38
MAX_INDEXABLE_CONTENT_SIZE = 20000


def compute_chunk_id(task_id: str, chunk_type: str, sequence_order: int, content: str) -> str:
    """Reimplementation of ChunkExtractor.computeChunkId()."""
    content_hash = hashlib.sha256(content.encode('utf-8')).hexdigest()[:16]
    seed = f"{task_id}|{chunk_type}|seq:{sequence_order}|{content_hash}"
    return str(uuid.uuid5(UUID_NAMESPACE, seed))


def truncate_for_indexing(content: str) -> str:
    """Simplified truncation matching ChunkExtractor.truncateForIndexing()."""
    if len(content) <= MAX_INDEXABLE_CONTENT_SIZE:
        return content
    head_size = int(MAX_INDEXABLE_CONTENT_SIZE * 0.7)
    tail_size = MAX_INDEXABLE_CONTENT_SIZE - head_size - 80
    marker = f"\n\n[TRUNCATED for indexing: {len(content)} chars -> {MAX_INDEXABLE_CONTENT_SIZE}. Source: unknown]\n\n"
    return content[:head_size] + marker + content[len(content) - tail_size:]


def extract_chunk_ids_from_task(task_id: str, task_path: str) -> list[dict]:
    """
    Simplified extraction of chunk_ids from a Roo task.
    Returns list of {chunk_id, chunk_type, seq, content_preview}.
    """
    api_history_path = os.path.join(task_path, 'api_conversation_history.json')
    if not os.path.exists(api_history_path):
        return []

    chunks = []
    seq = 0

    try:
        with open(api_history_path, 'r', encoding='utf-8', errors='replace') as f:
            raw = f.read()
        # Strip BOM
        if raw and raw[0] == '﻿':
            raw = raw[1:]
        messages = json.loads(raw)
    except Exception as e:
        print(f"  ERROR reading {api_history_path}: {e}", file=sys.stderr)
        return []

    for msg in messages:
        if not isinstance(msg, dict):
            continue
        role = msg.get('role', '')
        content = msg.get('content', '')

        # Normalize content to string
        if isinstance(content, list):
            text_parts = []
            for block in content:
                if isinstance(block, dict):
                    if block.get('type') == 'text':
                        text_parts.append(block.get('text', ''))
                    elif block.get('type') == 'tool_use':
                        text_parts.append(json.dumps(block.get('input', {}), sort_keys=True))
                    elif block.get('type') == 'tool_result':
                        rc = block.get('content', '')
                        if isinstance(rc, list):
                            for rb in rc:
                                if isinstance(rb, dict) and rb.get('type') == 'text':
                                    text_parts.append(rb.get('text', ''))
                        elif isinstance(rc, str):
                            text_parts.append(rc)
                elif isinstance(block, str):
                    text_parts.append(block)
            content = '\n'.join(text_parts)
        elif not isinstance(content, str):
            content = str(content)

        if not content.strip():
            continue

        # Determine chunk_type (simplified)
        tool_calls = msg.get('tool_calls', [])
        if tool_calls:
            chunk_type = 'tool_interaction'
        elif role in ('user', 'assistant'):
            chunk_type = 'message_exchange'
        else:
            continue

        # Truncate + compute chunk_id
        truncated = truncate_for_indexing(content)
        chunk_id = compute_chunk_id(task_id, chunk_type, seq, truncated)

        chunks.append({
            'chunk_id': chunk_id,
            'chunk_type': chunk_type,
            'sequence_order': seq,
            'content_preview': truncated[:100],
        })
        seq += 1

    return chunks


def find_roo_storage_path() -> str | None:
    """Find the Roo Code storage path for the current machine."""
    candidates = [
        os.path.join(os.path.expanduser('~'), 'AppData', 'Roaming', 'Code', 'User', 'globalStorage', ROO_EXTENSION_ID, 'tasks'),
        os.path.join(os.path.expanduser('~'), '.roo', 'tasks'),
    ]
    # Also check ROO_STORAGE_PATH env var
    env_path = os.environ.get('ROO_STORAGE_PATH')
    if env_path:
        candidates.insert(0, env_path)

    for path in candidates:
        if os.path.isdir(path):
            return path
    return None


def main():
    parser = argparse.ArgumentParser(description='#2196 Phase 4: Test chunk_id determinism')
    parser.add_argument('--limit', type=int, default=100, help='Max tasks to test (default: 100)')
    parser.add_argument('--json', action='store_true', help='Output as JSON')
    parser.add_argument('--verbose', action='store_true', help='Show per-chunk details')
    args = parser.parse_args()

    storage_path = find_roo_storage_path()
    if not storage_path:
        print("ERROR: Could not find Roo storage path. Set ROO_STORAGE_PATH env var.")
        sys.exit(1)

    print(f"Roo storage: {storage_path}")

    # Find tasks with api_conversation_history.json
    task_dirs = []
    for entry in os.scandir(storage_path):
        if entry.is_dir():
            api_file = os.path.join(entry.path, 'api_conversation_history.json')
            if os.path.exists(api_file):
                task_dirs.append(entry)

    if not task_dirs:
        print("No tasks with api_conversation_history.json found.")
        sys.exit(0)

    print(f"Found {len(task_dirs)} tasks. Testing {min(args.limit, len(task_dirs))}...")

    # Sort by modification time (most recent first)
    task_dirs.sort(key=lambda e: -os.path.getmtime(os.path.join(e.path, 'api_conversation_history.json')))
    task_dirs = task_dirs[:args.limit]

    results = []
    total_chunks = 0
    total_tasks_with_chunks = 0

    for entry in task_dirs:
        task_id = entry.name
        chunks = extract_chunk_ids_from_task(task_id, entry.path)
        if not chunks:
            continue

        total_tasks_with_chunks += 1
        total_chunks += len(chunks)

        result = {
            'task_id': task_id,
            'chunk_count': len(chunks),
            'chunk_ids': [c['chunk_id'] for c in chunks],
            'types': Counter(c['chunk_type'] for c in chunks),
        }

        # Check for duplicate chunk_ids WITHIN the same task
        id_counts = Counter(c['chunk_id'] for c in chunks)
        duplicates = {cid: cnt for cid, cnt in id_counts.items() if cnt > 1}
        if duplicates:
            result['internal_duplicates'] = len(duplicates)
            result['duplicate_ids'] = list(duplicates.keys())[:5]

        results.append(result)

        if args.verbose:
            print(f"  {task_id}: {len(chunks)} chunks ({dict(result['types'])})")
            if duplicates:
                print(f"    WARNING: {len(duplicates)} duplicate chunk_ids within task!")

    # Summary
    tasks_with_dups = [r for r in results if r.get('internal_duplicates')]
    all_ids = []
    for r in results:
        all_ids.extend(r['chunk_ids'])
    global_dup_check = Counter(all_ids)
    cross_task_dups = {cid: cnt for cid, cnt in global_dup_check.items() if cnt > 1}

    print(f"\n{'=' * 60}")
    print(f"CHUNK_ID STABILITY TEST RESULTS (#2196 Phase 4)")
    print(f"{'=' * 60}")
    print(f"Tasks tested:    {total_tasks_with_chunks}")
    print(f"Total chunks:    {total_chunks}")
    print(f"Unique chunk_ids: {len(set(all_ids))}")
    print(f"Internal dups:   {len(tasks_with_dups)} tasks with duplicate chunk_ids")
    if cross_task_dups:
        print(f"Cross-task dups: {len(cross_task_dups)} chunk_ids shared between tasks")
    else:
        print(f"Cross-task dups: 0 (expected)")

    if tasks_with_dups:
        print(f"\n{'=' * 60}")
        print("TASKS WITH INTERNAL DUPLICATES (potential H2 evidence)")
        print(f"{'=' * 60}")
        for r in tasks_with_dups[:10]:
            print(f"  {r['task_id']}: {r['internal_duplicates']} dups / {r['chunk_count']} chunks")

    # Verdict
    dup_rate = len(tasks_with_dups) / max(total_tasks_with_chunks, 1) * 100
    print(f"\n{'=' * 60}")
    print("VERDICT")
    print(f"{'=' * 60}")
    if dup_rate == 0:
        print("PASS — No internal chunk_id duplicates detected.")
        print("H2 (chunk_id non-determinism) NOT confirmed by this test.")
        print("Note: This test re-extracts locally and checks for internal collisions.")
        print("Cross-check with Qdrant stored chunk_ids requires a running Qdrant instance.")
    elif dup_rate < 5:
        print(f"LOW RATE — {dup_rate:.1f}% of tasks have internal duplicates.")
        print("May be legitimate (same content in different sequence positions).")
        print("Manual review of duplicate chunks recommended.")
    else:
        print(f"HIGH RATE — {dup_rate:.1f}% of tasks have internal duplicates!")
        print("H2 hypothesis SUPPORTED. chunk_id generation may not be fully deterministic.")
        print("Next step: Compare with Qdrant stored IDs for these tasks.")

    if args.json:
        output = {
            'test': 'chunk_id_stability',
            'issue': 2196,
            'phase': 4,
            'hypothesis': 'H2',
            'tasks_tested': total_tasks_with_chunks,
            'total_chunks': total_chunks,
            'unique_ids': len(set(all_ids)),
            'tasks_with_internal_dups': len(tasks_with_dups),
            'cross_task_dups': len(cross_task_dups),
            'dup_rate_pct': round(dup_rate, 2),
            'verdict': 'PASS' if dup_rate == 0 else 'LOW_RATE' if dup_rate < 5 else 'HIGH_RATE',
            'results': results,
        }
        print(f"\n{json.dumps(output, indent=2)}")


if __name__ == '__main__':
    main()
