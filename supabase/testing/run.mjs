import { PGlite } from '@electric-sql/pglite';
import { readFile, readdir } from 'node:fs/promises';
import assert from 'node:assert/strict';

// In-memory only: no connection URL, .env, credentials, or hosted database.
const root = new URL('../', import.meta.url);
const db = new PGlite();
let stage = 'initialization';
async function apply(path) {
  stage = path;
  await db.exec(await readFile(new URL(path, root), 'utf8'));
  console.log(`PASS ${path}`);
}
async function snapshot() {
  const { rows } = await db.query(`select schemaname, tablename from pg_tables
    where schemaname in ('public','auth','storage') order by 1,2`);
  const result = {};
  for (const { schemaname, tablename } of rows) {
    const quote = value => '"' + value.replaceAll('"', '""') + '"';
    const data = await db.query(`select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text),'[]'::jsonb) as data from ${quote(schemaname)}.${quote(tablename)} t`);
    result[`${schemaname}.${tablename}`] = data.rows[0].data;
  }
  return result;
}
try {
  await apply('testing/platform.sql');
  await apply('bootstrap/000_profiles.sql');
  const migrations = (await readdir(new URL('migrations/', root))).filter(x => x.endsWith('.sql')).sort();
  assert.ok(migrations.length > 0);
  for (const file of migrations) await apply(`migrations/${file}`);
  const baseline = await snapshot();
  const suites = (await readdir(new URL('tests/', root))).filter(x => x.endsWith('.sql')).sort();
  assert.ok(suites.includes('profile_baseline.sql'));
  for (const file of suites) {
    const sql = await readFile(new URL(`tests/${file}`, root), 'utf8');
    assert.match(sql, /\brollback\s*;/i, `${file} must roll back`);
    await apply(`tests/${file}`);
    assert.deepEqual(await snapshot(), baseline, `${file} leaked fixture rows`);
    const { rows } = await db.query('select current_user = session_user as reset');
    assert.equal(rows[0].reset, true, `${file} leaked role`);
  }
  console.log(`PASS fresh baseline + ${migrations.length} migrations + ${suites.length} rollback suites (local platform fixture)`);
} catch (error) {
  // Avoid dumping SQL, fixture payloads or connection-like values from driver errors.
  console.error(`FAIL ${stage}; ${error.code ?? error.name}. Inspect this file locally for details.`);
  process.exitCode = 1;
} finally {
  await db.close();
}
