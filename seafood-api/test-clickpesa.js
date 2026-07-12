/**
 * Stage-1 smoke test — validates ClickPesa auth + checksum against the LIVE API.
 * Run from a whitelisted IP:  node --env-file=.env test-clickpesa.js
 * Safe: it only generates a checkout LINK (no charge, no payout).
 */
const axios = require('axios');
const crypto = require('crypto');

const API = 'https://api.clickpesa.com/third-parties';
const CLIENT_ID = process.env.CLICKPESA_CLIENT_ID;
const API_KEY = process.env.CLICKPESA_API_KEY;
const CHECKSUM_KEY = process.env.CLICKPESA_CHECKSUM_SECURITY;

function canonicalize(obj) {
  if (obj === null || typeof obj !== 'object') return obj;
  if (Array.isArray(obj)) return obj.map(canonicalize);
  return Object.keys(obj).sort().reduce((a, k) => ((a[k] = canonicalize(obj[k])), a), {});
}
const checksum = (payload) =>
  crypto.createHmac('sha256', CHECKSUM_KEY).update(JSON.stringify(canonicalize(payload))).digest('hex');

(async () => {
  try {
    console.log('1) Generating token (tests credentials + IP whitelist)…');
    const tokRes = await axios.post(`${API}/generate-token`, {}, {
      headers: { 'client-id': CLIENT_ID, 'api-key': API_KEY },
    });
    const token = tokRes.data?.token;
    if (!token) throw new Error('No token: ' + JSON.stringify(tokRes.data));
    console.log('   ✅ token OK (' + token.slice(0, 12) + '…)\n');

    const payload = {
      totalPrice: '1000',
      orderReference: 'SMOKETEST' + Date.now(),
      orderCurrency: 'TZS',
      description: 'ZanSeaFood smoke test',
      customerName: 'Test Customer',
    };
    const signed = { ...payload, checksum: checksum(payload) };
    console.log('2) Creating checkout link (tests checksum)…');
    console.log('   orderReference:', payload.orderReference);
    const authorization = token.startsWith('Bearer ') ? token : `Bearer ${token}`;
    const coRes = await axios.post(`${API}/checkout-link/generate-checkout-url`, signed, {
      headers: { Authorization: authorization, 'Content-Type': 'application/json' },
    });
    console.log('   ✅ checkoutLink:', coRes.data?.checkoutLink || JSON.stringify(coRes.data));
    console.log('\nALL GOOD ✅  auth + checksum + checkout all work.');
  } catch (e) {
    const status = e.response?.status;
    const data = e.response?.data;
    console.error('\n❌ FAILED' + (status ? ` (HTTP ${status})` : ''));
    console.error('   ', JSON.stringify(data || e.message));
    if (status === 403) console.error('   → likely: IP not whitelisted, or tokens need regenerating after enabling checksum.');
    if (data && /checksum/i.test(JSON.stringify(data))) console.error('   → checksum rejected: the checksum key or algorithm is off.');
    process.exit(1);
  }
})();
