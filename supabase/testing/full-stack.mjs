import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { mkdtemp, readFile, readdir, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import assert from 'node:assert/strict';
import pg from 'pg';
import { runHttpSmoke } from './http-smoke.mjs';

const exec = promisify(execFile);
const cli = process.env.AJOPAY_SUPABASE_CLI || 'supabase';
const runtime = process.env.AJOPAY_TEST_RUNTIME || 'native';
assert.ok(['native', 'docker'].includes(runtime), 'Choose native or docker runtime');
const root = new URL('../', import.meta.url);
const workspace = await mkdtemp(join(tmpdir(), 'ajopay-integration-'));
// No inherited Supabase tokens, linked-project config, DB URLs or application .env.
const env = Object.fromEntries(['PATH', 'HOME', 'TMPDIR', 'SystemRoot'].filter(k => process.env[k]).map(k => [k, process.env[k]]));
env.SUPABASE_HOME = join(workspace, 'runtime');
env.SUPABASE_EXPERIMENTAL_STACK = '1';
let stage = 'CLI version';
let started = false;
let db;
async function command(args, timeout = 120000) {
  const heartbeat = timeout > 120000 ? setInterval(() => console.log(`Still running: ${stage}...`), 30000) : null;
  try {
    return (await exec(cli, [...args, '--workdir', workspace], { env, timeout, maxBuffer: 8 * 1024 * 1024 })).stdout;
  } catch {
    throw new Error(`Local CLI failed during ${stage}; output withheld because it can include local credentials`);
  } finally {
    if (heartbeat) clearInterval(heartbeat);
  }
}
function localUrl(value, protocols) {
  const url = new URL(value);
  assert.ok(protocols.includes(url.protocol) && ['127.0.0.1', 'localhost', '[::1]'].includes(url.hostname), 'Only loopback test services are allowed');
  assert.ok(!url.search && !url.hash, 'Endpoint query and fragment overrides are forbidden');
  return url;
}
try {
  const version = (await command(['--version'])).trim();
  assert.equal(version, '2.122.0', 'Use the pinned Supabase CLI 2.122.0');
  stage = 'initialize disposable project';
  await command(['init']);
  stage = 'start disposable services';
  started = true; // Also clean up a partially started stack.
  console.log('Starting disposable PostgreSQL, Auth, REST and Storage services...');
  await command(['stack', 'start', '--runtime', runtime, '--exclude', 'realtime,functions,studio,mail,analytics,pooler', '--eager'], 900000);
  stage = 'read local endpoints';
  const output = await command(['status', '--env', '--output-format', 'text']);
  const settings = Object.fromEntries(output.split('\n').flatMap(line => {
    const match = line.match(/^([A-Z_]+)="(.*)"$/);
    return match ? [[match[1], match[2]]] : [];
  }));
  const databaseUrl = localUrl(settings.DB_URL, ['postgresql:', 'postgres:']);
  const api = localUrl(settings.API_URL, ['http:']);
  assert.ok(!api.username && !api.password && api.pathname === '/', 'API must be a bare loopback origin');
  assert.ok(databaseUrl.pathname === '/postgres', 'Expected disposable postgres database');
  db = new pg.Client({ host: databaseUrl.hostname, port: Number(databaseUrl.port || 5432),
    database: 'postgres', user: decodeURIComponent(databaseUrl.username),
    password: decodeURIComponent(databaseUrl.password), ssl: false, connectionTimeoutMillis: 10000 });
  await db.connect();
  const files = ['bootstrap/000_profiles.sql', ...(await readdir(new URL('migrations/', root))).filter(f => f.endsWith('.sql')).sort().map(f => `migrations/${f}`)];
  for (const file of files) {
    stage = file;
    await db.query(await readFile(new URL(file, root), 'utf8'));
    console.log(`PASS ${file}`);
  }
  for (const file of (await readdir(new URL('tests/', root))).filter(f => f.endsWith('.sql')).sort()) {
    stage = `tests/${file}`;
    await db.query(await readFile(new URL(stage, root), 'utf8'));
    console.log(`PASS ${stage} on local Supabase PostgreSQL`);
  }
  stage = 'PostgREST schema readiness';
  // Probe schema visibility before running writes; no replay of HTTP smoke mutations.
  let ready = false;
  for (let attempt = 0; attempt < 30; attempt++) {
    const response = await fetch(`${settings.API_URL}/rest/v1/profiles?select=id&limit=0`, {
      headers: { apikey: settings.SERVICE_ROLE_KEY, Authorization: `Bearer ${settings.SERVICE_ROLE_KEY}` },
      redirect: 'error', signal: AbortSignal.timeout(5000),
    });
    ready = response.ok;
    await response.body?.cancel();
    if (ready) break;
    await new Promise(resolve => setTimeout(resolve, 1000));
  }
  assert.ok(ready, 'Local schema did not become visible');
  stage = 'real Auth/PostgREST profile smoke';
  await runHttpSmoke({ apiUrl: settings.API_URL, anonKey: settings.ANON_KEY, serviceKey: settings.SERVICE_ROLE_KEY });
  console.log('PASS real Auth sign-in, signup triggers, profile privacy and invalid-token denial');
} catch (error) {
  console.error(`FAIL ${stage}; ${error.code ?? error.name}. No credentials or response bodies printed.`);
  process.exitCode = 1;
} finally {
  await db?.end().catch(() => {});
  if (started) {
    stage = 'destroy disposable services';
    try {
      await command(['stack', 'destroy', '--yes']);
      await rm(workspace, { recursive: true, force: true });
      console.log('Removed disposable test stack.');
    } catch {
      console.error(`Cleanup incomplete. Disposable workspace retained: ${workspace}`);
      process.exitCode = 1;
    }
  } else {
    await rm(workspace, { recursive: true, force: true });
  }
}
