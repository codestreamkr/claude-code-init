#!/usr/bin/env node
// Claude Code StatusLine - Author: codestream
const { execSync } = require('child_process');
const path = require('path');

let raw = '';
process.stdin.on('data', chunk => raw += chunk);
process.stdin.on('end', () => {
    let data = {};
    try { data = JSON.parse(raw); } catch {}

    const sessionId = (data.session_id || '').slice(0, 8);
    const cwd = data.workspace?.current_dir || data.cwd || '';
    const model = data.model?.display_name || '';
    const style = data.output_style?.name || '';
    const pct = Math.floor(data.context_window?.used_percentage || 0);

    let branch = '';
    try {
        branch = execSync('git branch --show-current', {
            cwd: cwd || undefined,
            encoding: 'utf8',
            stdio: ['pipe', 'pipe', 'ignore']
        }).trim();
    } catch {}

    const gitInfo = branch ? `(${branch})` : '';
    process.stdout.write(`[${sessionId}] ${cwd} ${gitInfo} | ${model} | ${style} | ctx:${pct}%`);
});
