#!/usr/bin/env node

// Test script to verify the ROOSYNC_SHARED_PATH fix
const path = require('path');

// Clear ROOSYNC_SHARED_PATH from environment to test fallback
delete process.env.ROOSYNC_SHARED_PATH;

try {
    // Import the compiled module
    const sharedPathModule = require('./build/utils/shared-state-path.js');
    const getSharedStatePath = sharedPathModule.getSharedStatePath;

    // Test the function
    const sharedPath = getSharedStatePath();
    console.log('✅ SUCCESS: getSharedStatePath() returned:', sharedPath);

    // Verify it's the expected path
    if (sharedPath.includes('RooSync/.shared-state')) {
        console.log('✅ Path contains expected RooSync directory');
    } else {
        console.log('⚠️  Path does not contain expected RooSync directory');
    }

} catch (error) {
    console.error('❌ ERROR:', error.message);
    console.error('Stack:', error.stack);
    process.exit(1);
}