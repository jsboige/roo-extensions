#!/usr/bin/env node

// Simple test to verify getSharedStatePath works
import { getSharedStatePath } from './mcps/internal/servers/roo-state-manager/build/src/utils/shared-state-path.js';

try {
    const path = getSharedStatePath();
    console.log('✅ SUCCESS: getSharedStatePath() returned:', path);
} catch (error) {
    console.error('❌ ERROR:', error.message);
    process.exit(1);
}