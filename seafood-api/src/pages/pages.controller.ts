import { Controller, Get, Query, Res } from '@nestjs/common';
import { Response } from 'express';

/**
 * Landing pages for ClickPesa hosted checkout. After the customer pays on the
 * ClickPesa page, their browser is redirected to the Return URL configured in
 * the dashboard. This is UX only — the actual order confirmation happens via the
 * webhook. The page just tells the customer to return to the app.
 */
@Controller()
export class PagesController {
  @Get('payment-complete')
  paymentComplete(@Query('orderReference') orderRef: string, @Res() res: Response) {
    res.set('Content-Type', 'text/html').send(page(orderRef));
  }
}

function page(orderRef?: string): string {
  const ref = orderRef ? `<p class="ref">Order: ${escapeHtml(orderRef)}</p>` : '';
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>ZanSeaFood — Payment</title>
  <style>
    body{margin:0;font-family:-apple-system,Segoe UI,Roboto,sans-serif;background:#0f2540;
         color:#fff;display:flex;min-height:100vh;align-items:center;justify-content:center;text-align:center}
    .card{max-width:420px;padding:32px 24px}
    .tick{width:88px;height:88px;border-radius:50%;background:#16a34a;margin:0 auto 20px;
          display:flex;align-items:center;justify-content:center;font-size:48px}
    h1{font-size:22px;margin:0 0 8px} p{opacity:.85;line-height:1.5;margin:6px 0}
    .ref{opacity:.6;font-size:13px;margin-top:16px}
  </style>
</head>
<body>
  <div class="card">
    <div class="tick">✓</div>
    <h1>Payment being processed</h1>
    <p>Asante! Malipo yako yanashughulikiwa.</p>
    <p>You can now close this page and return to the <strong>ZanSeaFood</strong> app — your order status will update automatically.</p>
    ${ref}
  </div>
</body>
</html>`;
}

function escapeHtml(s: string): string {
  return s.replace(/[&<>"']/g, (c) => (
    { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c] as string
  ));
}
