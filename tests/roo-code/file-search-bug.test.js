const path = require('path');
const fs = require('fs');
const { spawn } = require('child_process');

console.log('--- File Search Bug Verification Script ---');

const rootDir = path.resolve(__dirname, '..', '..');
const testDir = path.join(rootDir, 'tests', 'temp test dir');

// Function to find ripgrep executable
async function findRipgrep() {
    const rgPath = "C:/Program Files/Microsoft VS Code/resources/app/node_modules/@vscode/ripgrep/bin/rg.exe";
    console.log(`\n1. Using rg path: ${rgPath}`);

    if (fs.existsSync(rgPath)) {
        console.log(`   [SUCCESS] Found at: ${rgPath}`);
        return rgPath;
    }
    
    console.error(`   [FAILURE] Could not find rg.exe at the specified path.`);
    return null;
}

// Function to run the search test
async function runSearchTest() {
    const rgPath = await findRipgrep();
    if (!rgPath) {
        process.exit(1);
    }
    
    if (!fs.existsSync(testDir)) {
        console.error(`\n[FATAL] Test directory not found at: ${testDir}`);
        process.exit(1);
    }
    console.log(`\n2. Test directory found at: ${testDir}`);

    const args = [
        '--files',
        '--follow',
        '--hidden',
        testDir
    ];

    console.log(`\n3. Executing ripgrep...`);
    console.log(`   Command: "${rgPath}" ${args.map(a => `'${a}'`).join(' ')}`);

    const rgProcess = spawn(rgPath, args);

    let stdout = '';
    let stderr = '';
    
    rgProcess.stdout.on('data', (data) => { stdout += data.toString(); });
    rgProcess.stderr.on('data', (data) => { stderr += data.toString(); });

    rgProcess.on('close', (code) => {
        console.log(`\n4. Ripgrep process exited with code ${code}.`);
        
        if (stderr) {
            console.error(`   STDERR:\n${stderr}`);
        }

        const expectedFile = `un fichier avec accent é.txt`;
        const normalizedStdout = stdout.trim().replace(/\\/g, '/');
        const normalizedExpected = path.join(testDir, expectedFile).replace(/\\/g, '/');

        console.log(`   STDOUT:\n   ${normalizedStdout || '(No output)'}`);

        console.log('\n5. Verifying results...');
        if (normalizedStdout.includes(normalizedExpected)) {
            console.log("   [✅ SUCCESS] The test file was found in the output.");
        } else {
            console.error(`   [❌ FAILURE] The test file was NOT found.`);
            console.error(`     - Searched for: "${normalizedExpected}"`);
            console.error(`     - In output:    "${normalizedStdout}"`);
            process.exit(1);
        }
    });

    rgProcess.on('error', (err) => {
        console.error('   [FATAL] Failed to start ripgrep process.', err);
        process.exit(1);
    });
}

runSearchTest();
