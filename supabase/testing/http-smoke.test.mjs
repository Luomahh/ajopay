import test from 'node:test';
import assert from 'node:assert/strict';
import { runHttpSmoke } from './http-smoke.mjs';

test('HTTP integration guard rejects non-local targets before any request', async () => {
  const original = globalThis.fetch;
  let requests = 0;
  globalThis.fetch = async () => { requests++; throw new Error('Unexpected network'); };
  try {
    for (const apiUrl of ['https://project.supabase.co', 'http://127.0.0.1.example.com', 'https://localhost', 'http://user:pass@localhost', 'http://localhost/rest/v1', 'http://localhost?redirect=1']) {
      await assert.rejects(runHttpSmoke({ apiUrl, anonKey: 'dummy', serviceKey: 'dummy' }));
    }
    assert.equal(requests, 0);
  } finally {
    globalThis.fetch = original;
  }
});
