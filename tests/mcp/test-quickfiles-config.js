const { spawn } = require('child_process');
const path = require('path');

const serverPath = path.join(__dirname, '../../mcps/internal/servers/quickfiles-server/build/index.js');

// Test case: Verify exclusions
const env = {
  ...process.env,
  QUICKFILES_EXCLUDES: 'node_modules,.git,dist,build,coverage,excluded_dir',
  QUICKFILES_MAX_DEPTH: '2'
};

console.log('Starting Quickfiles server with config:', {
  QUICKFILES_EXCLUDES: env.QUICKFILES_EXCLUDES,
  QUICKFILES_MAX_DEPTH: env.QUICKFILES_MAX_DEPTH
});

const server = spawn('node', [serverPath], { env });

server.stdout.on('data', (data) => {
  console.log(`[Server stdout] ${data}`);
});

server.stderr.on('data', (data) => {
  console.error(`[Server stderr] ${data}`);
});

// Wait for server to start (naive)
setTimeout(() => {
  // Send a list_directory_contents request
  const request = {
    jsonrpc: '2.0',
    id: 1,
    method: 'tools/call',
    params: {
      name: 'list_directory_contents',
      arguments: {
        paths: ['.'], // Current directory (d:/roo-extensions)
        recursive: true
      }
    }
  };

  console.log('Sending request:', JSON.stringify(request, null, 2));
  server.stdin.write(JSON.stringify(request) + '\n');
}, 2000);

server.stdout.on('data', (data) => {
  const str = data.toString();
  if (str.includes('jsonrpc')) {
    try {
      const response = JSON.parse(str);
      if (response.result) {
        const content = response.result.content[0].text;
        console.log('Response received.');

        // Check if excluded_dir is present (it shouldn't be if we create it)
        // But first let's just see if node_modules is there (it should be excluded by default but also by our config)
        if (content.includes('node_modules')) {
          console.error('FAIL: node_modules found in output');
        } else {
          console.log('PASS: node_modules not found');
        }

        // Check depth? Hard to verify without specific structure.
        // Let's just print a summary.
        console.log('Output length:', content.length);

        server.kill();
        process.exit(0);
      }
    } catch (e) {
      // ignore partial chunks
    }
  }
});