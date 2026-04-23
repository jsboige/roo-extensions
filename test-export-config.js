const { ExportConfigManager } = require('./mcps/internal/servers/roo-state-manager/src/services/ExportConfigManager');

async function test() {
  console.log('Testing ExportConfigManager with no storage...');

  // Mock the RooStorageDetector to return empty array
  const originalDetect = require('./mcps/internal/servers/roo-state-manager/src/utils/roo-storage-detector').RooStorageDetector.detectStorageLocations;
  require('./mcps/internal/servers/roo-state-manager/src/utils/roo-storage-detector').RooStorageDetector.detectStorageLocations = () => Promise.resolve([]);

  const manager = new ExportConfigManager();

  try {
    await manager.getConfig();
    console.log('ERROR: Should have thrown but didn\'t');
    return false;
  } catch (e) {
    console.log('SUCCESS: Threw as expected');
    console.log('Error code:', e.code);
    console.log('Error message:', e.message);
    return e.code === 'NO_STORAGE_DETECTED';
  }
}

test().then(success => {
  console.log('Test result:', success ? 'PASS' : 'FAIL');
  process.exit(success ? 0 : 1);
}).catch(err => {
  console.error('Test error:', err);
  process.exit(1);
});