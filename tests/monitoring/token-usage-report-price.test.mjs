/**
 * getPrice() unit tests — scripts/monitoring/token-usage-report.js (#4348)
 *
 * Run (zero dependencies, Node >= 20):
 *   node --test tests/monitoring/token-usage-report-price.test.mjs
 *
 * Not picked up by the root vitest config (its include pattern only matches
 * .ts files under tests/ — see vitest.config.ts: the root has no runnable
 * vitest suite, hence node:test).
 */
import test from 'node:test';
import assert from 'node:assert/strict';
import { getPrice } from '../../scripts/monitoring/token-usage-report.js';

test('current 5-5 model ids are priced from their own rows (#4348)', () => {
    assert.deepEqual(getPrice('claude-opus-5-5'),   { input: 4.00, output: 20.00 });
    assert.deepEqual(getPrice('claude-sonnet-5-5'), { input: 2.00, output: 10.00 });
    assert.deepEqual(getPrice('claude-haiku-5-5'),  { input: 0.10, output: 0.50 });
    // regression guard: must NOT resolve to the 4-x generation via the old
    // two-token prefix fallback (those rows: opus-4-6 15/75, sonnet-4-6 3/15,
    // haiku-4-5 0.80/4)
    assert.notDeepEqual(getPrice('claude-haiku-5-5'),  { input: 0.80, output: 4.00 });
    assert.notDeepEqual(getPrice('claude-opus-5-5'),   { input: 15.00, output: 75.00 });
    assert.notDeepEqual(getPrice('claude-sonnet-5-5'), { input: 3.00, output: 15.00 });
});

test('trailing [...] suffix (e.g. [1m]) is stripped before lookup', () => {
    assert.deepEqual(getPrice('claude-haiku-5-5[1m]'), { input: 0.10, output: 0.50 });
    assert.deepEqual(getPrice('claude-opus-5-5[1m]'),  { input: 4.00, output: 20.00 });
    assert.deepEqual(getPrice('claude-sonnet-5-5[1m]'),{ input: 2.00, output: 10.00 });
});

test('unknown ids return null — never priced silently from a sibling', () => {
    // unknown generation: the old code matched the 'claude-opus' prefix and
    // billed it at the opus-4-6 rate
    assert.equal(getPrice('claude-opus-9-9'), null);
    assert.equal(getPrice('claude-haiku-7-2'), null);
    // entirely unknown vendor/model
    assert.equal(getPrice('some-future-model'), null);
    // unknown id WITH suffix stays unknown. Synthetic id on purpose: asserting
    // null for a REAL current id (claude-fable-5-1 was the first version) locks
    // its absence, so adding its PRICING row tomorrow would read as a test
    // regression (po-2023 review, 25/10 04:20Z — the lock had to be broken
    // whichever option was chosen).
    assert.equal(getPrice('claude-future-9[1m]'), null);
});

test('existing exact rows keep working (caller contract)', () => {
    assert.deepEqual(getPrice('claude-sonnet-4-5-20250929'), { input: 3.00, output: 15.00 });
    assert.deepEqual(getPrice('glm-5'),                      { input: 0.70, output: 2.80 });
    assert.deepEqual(getPrice('glm-4.7'),                    { input: 0.14, output: 0.56 });
});
