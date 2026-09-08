// resolve a translation conflict: development authoritative + PR's new keys appended.
import { execSync } from 'node:child_process';
import { writeFileSync } from 'node:fs';

const [, , devRef, wizardRef, outFile, file] = process.argv;

function readRef(ref) {
  return execSync(`git show ${ref}:${file}`, { encoding: 'utf8', maxBuffer: 10 * 1024 * 1024 });
}
function parseKeys(xml) {
  const keys = new Map();
  const re = /<text\s+name="([^"]+)"\s+text="([^"]*)"\s*\/>/g;
  let m;
  while ((m = re.exec(xml)) !== null) keys.set(m[1], m[2]);
  return keys;
}
const dev = readRef(devRef);
const wizard = readRef(wizardRef);
const devKeys = parseKeys(dev);
const wizardKeys = parseKeys(wizard);
const newKeys = [];
for (const [k, v] of wizardKeys) if (!devKeys.has(k)) newKeys.push({ k, v });

const closeIdx = dev.lastIndexOf('</l10n>');
let result = closeIdx !== -1 ? dev.slice(0, closeIdx) : dev;
for (const { k, v } of newKeys) {
  const escaped = v.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  result += `\n        <text name="${k}" text="${escaped}" />`;
}
if (closeIdx !== -1) result += '\n' + dev.slice(closeIdx);
writeFileSync(outFile, result, 'utf8');
console.log(`${file}: new keys added: ${newKeys.length}`);
for (const { k } of newKeys) console.log('  new: ' + k);
