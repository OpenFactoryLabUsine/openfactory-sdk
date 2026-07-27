const os = require('os');
const fs = require('fs');
const ip = Object.values(os.networkInterfaces()).flat().find(i => i.family === 'IPv4' && !i.internal).address;
fs.writeFileSync('.env', `HOST_IP=${ip}\n`);