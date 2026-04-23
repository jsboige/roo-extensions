#!/usr/bin/env node

// Direct test of the shared state path functionality
const { getSharedStatePath } = require('./build/utils/shared-state-path.js');

console.log('Testing getSharedStatePath()...\n');

// Test 1: With environment variable
process.env.ROOSYNC_SHARED_PATH = 'test-env-path';
try {
    const path1 = getSharedStatePath();
    console.log('✅ Test 1 (env var):', path1);
} catch (error) {
    console.log('❌ Test 1 failed:', error.message);
}

// Test 2: Without environment variable (should fallback to .env)
delete process.env.ROOSYNC_SHARED_PATH;
try {
    const path2 = getSharedStatePath();
    console.log('✅ Test 2 (fallback):', path2);
    console.log('✅ Fallback works correctly!');
} catch (error) {
    console.log('❌ Test 2 failed:', error.message);
    console.log('This would indicate the fix is not working properly.');
}