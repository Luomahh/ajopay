/** Server-only test adapter. No endpoint, balance updates, or automatic retries. */
export type ExpectedPayment = { reference: string; amountKobo: number; email: string };
export class PaymentError extends Error {
  code: string;
  constructor(code: string) { super(code); this.name = 'PaymentError'; this.code = code; }
}
type Json = Record<string, unknown>;
function object(value: unknown): Json {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new PaymentError('invalid_provider_response');
  return value as Json;
}
function validate(p: ExpectedPayment) {
  if (!Number.isSafeInteger(p.amountKobo) || p.amountKobo <= 0) throw new PaymentError('invalid_amount');
  if (!/^[a-zA-Z0-9.=-]{1,100}$/.test(p.reference)) throw new PaymentError('invalid_reference');
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(p.email)) throw new PaymentError('invalid_email');
}
function testKey(key: string) {
  if (!/^sk_test_[a-zA-Z0-9]+$/.test(key)) throw new PaymentError('test_key_required');
}
export class PaystackSandbox {
  #key: string;
  #fetch: typeof fetch;
  #timeout: number;
  constructor(options: { secretKey: string; mode: 'test'; fetch?: typeof fetch; timeoutMs?: number }) {
    if (options.mode !== 'test') throw new PaymentError('test_mode_required');
    testKey(options.secretKey);
    this.#key = options.secretKey;
    this.#fetch = options.fetch ?? fetch;
    this.#timeout = options.timeoutMs ?? 10000;
    if (!Number.isFinite(this.#timeout) || this.#timeout < 1 || this.#timeout > 30000) throw new PaymentError('invalid_timeout');
  }
  async #request(path: string, body?: Json): Promise<Json> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.#timeout);
    try {
      const response = await this.#fetch(`https://api.paystack.co${path}`, {
        method: body ? 'POST' : 'GET', redirect: 'error', signal: controller.signal,
        headers: { Authorization: `Bearer ${this.#key}`, 'Content-Type': 'application/json' },
        ...(body ? { body: JSON.stringify(body) } : {}),
      });
      if (!response.ok) throw new PaymentError('provider_http_error');
      const payload = object(await response.json());
      if (payload.status !== true) throw new PaymentError('provider_rejected');
      return object(payload.data);
    } catch (error) {
      if (controller.signal.aborted) throw new PaymentError('provider_timeout');
      if (error instanceof PaymentError) throw error;
      throw new PaymentError('provider_unavailable');
    } finally { clearTimeout(timer); }
  }
  async initialize(p: ExpectedPayment) {
    validate(p);
    const data = await this.#request('/transaction/initialize', { email: p.email, amount: String(p.amountKobo), currency: 'NGN', reference: p.reference });
    if (data.reference !== p.reference || typeof data.access_code !== 'string' || !data.access_code) throw new PaymentError('invalid_provider_response');
    let url: URL;
    try { url = new URL(String(data.authorization_url)); } catch { throw new PaymentError('invalid_checkout_url'); }
    if (url.origin !== 'https://checkout.paystack.com' || url.username || url.password) throw new PaymentError('invalid_checkout_url');
    return { reference: p.reference, authorizationUrl: url.href, accessCode: data.access_code };
  }
  async verify(p: ExpectedPayment) {
    validate(p);
    const data = await this.#request(`/transaction/verify/${encodeURIComponent(p.reference)}`);
    if (data.domain !== 'test') throw new PaymentError('test_transaction_required');
    if (data.reference !== p.reference || data.amount !== p.amountKobo || data.currency !== 'NGN') throw new PaymentError('payment_mismatch');
    const customer = object(data.customer);
    if (typeof customer.email !== 'string' || customer.email.toLowerCase() !== p.email.toLowerCase()) throw new PaymentError('payment_mismatch');
    if (!Number.isSafeInteger(data.id) || Number(data.id) <= 0) throw new PaymentError('invalid_provider_response');
    if (data.status !== 'success') throw new PaymentError('payment_not_successful');
    // Evidence only; a durable idempotent transaction must separately post to a ledger.
    return { providerTransactionId: String(data.id), reference: p.reference, amountKobo: p.amountKobo, currency: 'NGN' as const, mode: 'test' as const };
  }
}
/** Exact raw bytes, before JSON parsing. Authentication alone must never credit funds. */
export async function verifyWebhookSignature(raw: Uint8Array, signature: string | null, secretKey: string): Promise<boolean> {
  testKey(secretKey);
  if (raw.byteLength > 1024 * 1024 || !signature || !/^[a-fA-F0-9]{128}$/.test(signature)) return false;
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secretKey), { name: 'HMAC', hash: 'SHA-512' }, false, ['verify']);
  const bytes = Uint8Array.from(signature.match(/../g)!, (pair) => parseInt(pair, 16));
  // Native verification avoids an early-exit JavaScript string comparison.
  return crypto.subtle.verify('HMAC', key, bytes, raw);
}
