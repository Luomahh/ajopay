import assert from 'node:assert/strict';
import { randomUUID, randomBytes } from 'node:crypto';

// Local Supabase HTTP exercise. No response bodies, tokens or passwords are logged.
export async function runHttpSmoke({ apiUrl, anonKey, serviceKey }) {
  const base = new URL(apiUrl);
  assert.ok(base.protocol === 'http:' && ['127.0.0.1', 'localhost'].includes(base.hostname), 'HTTP smoke requires a loopback HTTP API');
  assert.ok(!base.username && !base.password && !base.search && !base.hash && (base.pathname === '/' || base.pathname === ''), 'API URL must be a bare origin');
  assert.ok(typeof anonKey === 'string' && anonKey.length > 0 && typeof serviceKey === 'string' && serviceKey.length > 0, 'Local API credentials required');
  const origin = base.origin;
  const users = [];
  let failure;
  async function request(path, { token = anonKey, key = anonKey, method = 'GET', body, expected, label } = {}) {
    let response;
    try {
      response = await fetch(`${origin}${path}`, {
        method,
        headers: { apikey: key, Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: body === undefined ? undefined : JSON.stringify(body),
        redirect: 'error',
        signal: AbortSignal.timeout(15000),
      });
    } catch {
      throw new Error(`${label}: local HTTP request failed`);
    }
    if (expected && !expected.includes(response.status)) {
      await response.body?.cancel();
      throw new Error(`${label}: unexpected HTTP status ${response.status}`);
    }
    return response;
  }
  async function json(response, label) {
    try { return await response.json(); } catch { throw new Error(`${label}: invalid JSON response`); }
  }
  try {
    for (let i = 0; i < 2; i++) {
      const email = `http-smoke-${randomUUID()}@example.invalid`;
      const password = randomBytes(32).toString('base64url');
      const created = await json(await request('/auth/v1/admin/users', {
        token: serviceKey, key: serviceKey, method: 'POST', expected: [200, 201], label: 'Create synthetic user',
        body: { email, password, email_confirm: true, user_metadata: { full_name: `HTTP Test Member ${i}`, contact_phone: '+2348012345678', trust_score: 100 } },
      }), 'Create synthetic user');
      assert.ok(typeof created.id === 'string' && /^[0-9a-f-]{36}$/i.test(created.id), 'Synthetic user ID missing');
      users.push({ id: created.id });
      const session = await json(await request('/auth/v1/token?grant_type=password', {
        method: 'POST', expected: [200], label: 'Password sign-in', body: { email, password },
      }), 'Password sign-in');
      assert.ok(typeof session.access_token === 'string' && session.access_token.length > 0, 'Sign-in token missing');
      users[i].token = session.access_token;
    }
    for (const user of users) {
      const rows = await json(await request('/rest/v1/profiles?select=id,full_name,phone,trust_score', {
        token: user.token, expected: [200], label: 'Own profile query',
      }), 'Own profile query');
      assert.ok(Array.isArray(rows) && rows.length === 1 && rows[0].id === user.id, 'Profiles must expose only the authenticated owner');
      assert.ok(rows[0].phone === '+2348012345678' && rows[0].trust_score === 0, 'Signup profile defaults incorrect');
      const contact = await json(await request('/rest/v1/member_profiles?select=user_id,display_name,phone,share_phone', {
        token: user.token, expected: [200], label: 'Own contact profile query',
      }), 'Own contact profile query');
      assert.ok(Array.isArray(contact) && contact.length === 1 && contact[0].user_id === user.id && contact[0].phone === '+2348012345678' && contact[0].share_phone === false, 'Signup contact trigger or own-profile scope failed');
      const protectedWrite = await request(`/rest/v1/profiles?id=eq.${user.id}`, {
        token: user.token, method: 'PATCH', body: { trust_score: 100 }, expected: [401, 403], label: 'Protected score update',
      });
      await protectedWrite.body?.cancel();
    }
    const anonymous = await request('/rest/v1/profiles?select=id', { expected: [401, 403], label: 'Anonymous profiles denial' });
    await anonymous.body?.cancel();
    const invalid = await request('/rest/v1/profiles?select=id', { token: 'invalid-token-for-local-smoke', expected: [401, 403], label: 'Invalid token denial' });
    await invalid.body?.cancel();
  } catch {
    // Never propagate provider responses, JWTs or assert actual-value payloads.
    failure = new Error('Local auth/profile HTTP smoke failed; inspect local service health and schema without logging credentials');
  } finally {
    let cleanupFailed = false;
    for (const user of users.reverse()) {
      try {
        // member_profiles has a non-cascading FK in existing migrations.
        const contacts = await request(`/rest/v1/member_profiles?user_id=eq.${user.id}`, {
          token: serviceKey, key: serviceKey, method: 'DELETE', expected: [200, 204], label: 'Synthetic contact cleanup',
        });
        await contacts.body?.cancel();
      } catch { cleanupFailed = true; }
      try {
        const removed = await request(`/auth/v1/admin/users/${user.id}`, {
          token: serviceKey, key: serviceKey, method: 'DELETE', expected: [200, 204], label: 'Synthetic auth cleanup',
        });
        await removed.body?.cancel();
      } catch { cleanupFailed = true; }
    }
    if (cleanupFailed) failure = new Error('Local auth/profile HTTP smoke cleanup failed; remove synthetic http-smoke users from the isolated local stack');
  }
  if (failure) throw failure;
  return { passed: true, checks: ['password sign-in', 'both signup triggers', 'own profile isolation', 'server-owned score', 'anonymous denial', 'invalid token denial', 'fixture cleanup'] };
}
