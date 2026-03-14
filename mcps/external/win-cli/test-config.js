#!/usr/bin/env node
import { loadConfig } from './server/dist/utils/config.js';

const config = loadConfig('C:\\dev\\roo-extensions\\mcps\\external\\win-cli\\unrestricted-config.json');

console.log('=== Loaded Config ===');
console.log('enableInjectionProtection:', config.security.enableInjectionProtection);
console.log('powershell.blockedOperators:', config.shells.powershell.blockedOperators);
console.log('cmd.blockedOperators:', config.shells.cmd.blockedOperators);
console.log('===================');
