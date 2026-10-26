import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { PaystackSandbox, verifyWebhookSignature } from './paystack_sandbox.ts';
const secretKey = ['sk', 'test', 'offlinefixture'].join('_');
const p = { reference: 'ajo-test-001', amountKobo: 1000000, email: 'member@example.test' };
const success = { id: 123, domain: 'test', status: 'success', reference: p.reference, amount: p.amountKobo, currency: 'NGN', customer: { email: p.email } };
const response = data => new Response(JSON.stringify({status: true, data}));
const adapter = data => new PaystackSandbox({ secretKey, mode: 'test', fetch: async () => response(data) });
const rejects = (promise, code) => assert.rejects(promise, { code });
test('offline initialize -> verify: amount is kobo, credentials server-side, no credit side effects', async () => {
  const calls = [];
  const client = new PaystackSandbox({ secretKey, mode: 'test', fetch: async (url, init) => {
    calls.push(url);
    assert.equal(init.headers.Authorization, `Bearer ${secretKey}`);
    assert.equal(init.redirect, 'error');
    if (init.method === 'POST') {
      assert.deepEqual(JSON.parse(init.body), { email: p.email, amount: '1000000', currency: 'NGN', reference: p.reference });
      return response({ reference: p.reference, access_code: 'offline', authorization_url: 'https://checkout.paystack.com/offline' });
    }
    return response(success);
  }});
  assert.equal((await client.initialize(p)).reference, p.reference);
  assert.equal((await client.verify(p)).providerTransactionId, '123');
  assert.deepEqual(calls, ['https://api.paystack.co/transaction/initialize', 'https://api.paystack.co/transaction/verify/ajo-test-001']);
});
test('reject live keys/mode before transport', () => {
  assert.throws(() => new PaystackSandbox({secretKey: 'sk_live_fake', mode:'test'}), {code:'test_key_required'});
  assert.throws(() => new PaystackSandbox({secretKey, mode:'live'}), {code:'test_mode_required'});
});
for (const amountKobo of [0, -1, 1.5, NaN, Infinity, Number.MAX_SAFE_INTEGER + 1]) {
  test(`reject invalid amount ${amountKobo} before fetch`, async () => {
    const client = new PaystackSandbox({secretKey, mode:'test', fetch: async()=>{assert.fail('must not fetch');}});
    await rejects(client.initialize({...p, amountKobo}), 'invalid_amount');
  });
}
for (const [field, value, code] of [
  ['domain','live','test_transaction_required'], ['domain',undefined,'test_transaction_required'],
  ['reference','other','payment_mismatch'], ['amount',999,'payment_mismatch'],
  ['amount','1000000','payment_mismatch'], ['currency','USD','payment_mismatch'],
  ['customer',{email:'other@example.test'},'payment_mismatch'],
  ['status','pending','payment_not_successful'], ['id',0,'invalid_provider_response'],
]) test(`reject verification mismatch ${field}=${JSON.stringify(value)}`, async()=>{
  await rejects(adapter({...success,[field]:value}).verify(p), code);
});
test('reject forged checkout host and changed initialization reference', async()=>{
  await rejects(adapter({reference:p.reference,access_code:'x',authorization_url:'https://checkout.paystack.com.evil.test/x'}).initialize(p),'invalid_checkout_url');
  await rejects(adapter({reference:'other',access_code:'x',authorization_url:'https://checkout.paystack.com/x'}).initialize(p),'invalid_provider_response');
});
test('redact provider HTTP, rejection, malformed JSON and transport errors', async()=>{
  for (const [fetch,code] of [
    [async()=>new Response('sensitive',{status:500}),'provider_http_error'],
    [async()=>new Response(JSON.stringify({status:false,message:'sensitive'})),'provider_rejected'],
    [async()=>new Response('invalid'),'provider_unavailable'],
    [async()=>{throw Error('sensitive');},'provider_unavailable'],
  ]) await rejects(new PaystackSandbox({secretKey,mode:'test',fetch}).verify(p),code);
});
test('timeout aborts request without automatic retry', async()=>{
  let calls = 0;
  const client = new PaystackSandbox({secretKey,mode:'test',timeoutMs:5,fetch:async(_,init)=>{
    calls++;
    return new Promise((_,reject)=>init.signal.addEventListener('abort',()=>reject(new Error('aborted'))));
  }});
  await rejects(client.initialize(p),'provider_timeout');
  assert.equal(calls,1);
});
test('webhook verifies raw bytes; forged, altered, absent and malformed signatures fail', async()=>{
  const raw = new TextEncoder().encode('{"event":"charge.success","data":{"domain":"test"}}');
  const sig = createHmac('sha512', secretKey).update(raw).digest('hex');
  assert.equal(await verifyWebhookSignature(raw,sig,secretKey),true);
  for (const signature of [null,'','0'.repeat(128),'z'.repeat(128),sig.slice(2)]) assert.equal(await verifyWebhookSignature(raw,signature,secretKey),false);
  assert.equal(await verifyWebhookSignature(new TextEncoder().encode(' '+new TextDecoder().decode(raw)),sig,secretKey),false);
  assert.equal(await verifyWebhookSignature(new Uint8Array(1024*1024+1),sig,secretKey),false);
});
