const fs = require('fs');
const path = require('path');

const filePath = process.argv[2];

if (!filePath) {
    console.error("Usage: node read-file.js <file_path>");
    process.exit(1);
}

try {
    const content = fs.readFileSync(filePath, 'utf8');
    console.log(content);
} catch (err) {
    console.error(`Error reading file: ${err.message}`);
    process.exit(1);
}