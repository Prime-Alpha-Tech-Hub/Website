#!/usr/bin/env node
// ═══════════════════════════════════════════════════════════════════════════
//  Prime Alpha Securities — Backend Server
//
//  Architecture:
//    Port 80  (HTTP)  ─┐
//    Port 443 (HTTPS) ─┴─→ This server
//                           ├── /api/*  → DynamoDB (IAM role, server-side)
//                           └── /*      → Vite dist/ (React SPA)
//
//  AWS credentials: EC2 IAM role via IMDS — no hardcoded keys
// ═══════════════════════════════════════════════════════════════════════════
'use strict';

const http  = require('http');
const https = require('https');
const fs    = require('fs');
const path  = require('path');

const {
  DynamoDBClient,
  ScanCommand,
  GetItemCommand,
  PutItemCommand,
  UpdateItemCommand,
  DeleteItemCommand,
} = require('@aws-sdk/client-dynamodb');
const { marshall, unmarshall } = require('@aws-sdk/util-dynamodb');

// ── Config ────────────────────────────────────────────────────────────────────
const PORT_HTTP  = Number(process.env.PORT_HTTP)  || 80;
const PORT_HTTPS = Number(process.env.PORT_HTTPS) || 443;
const REGION     = process.env.AWS_REGION || 'eu-west-2';
const DIST       = path.join(__dirname, 'dist');
const CERTS      = path.join(__dirname, 'certs');

// ── DynamoDB client — uses EC2 IAM role automatically ────────────────────────
const ddb = new DynamoDBClient({ region: REGION });

// ── Primary key map ───────────────────────────────────────────────────────────
const PK = {
  investor:           'investorId',
  portfolios:         'portfolioId',
  documents:          'docId',
  workers:            'workerId',
  calendar:           'eventId',
  pe_companies:       'dealId',
  credit_application: 'appId',
  real_estate:        'assetId',
  articles:           'articleId',
  enquiries:          'enquiryId',
};
const TABLES = new Set(Object.keys(PK));

// ── MIME types ────────────────────────────────────────────────────────────────
const MIME = {
  '.html':'text/html; charset=utf-8',
  '.js':  'application/javascript; charset=utf-8',
  '.mjs': 'application/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json':'application/json',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.ico': 'image/x-icon',
  '.woff2':'font/woff2',
  '.woff':'font/woff',
  '.ttf': 'font/ttf',
  '.map': 'application/json',
};

// ── Helpers ───────────────────────────────────────────────────────────────────
function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', c => chunks.push(c));
    req.on('end', () => {
      try { resolve(JSON.parse(Buffer.concat(chunks).toString() || '{}')); }
      catch { resolve({}); }
    });
    req.on('error', reject);
  });
}

function jsonRes(res, status, data) {
  const body = JSON.stringify(data);
  res.writeHead(status, {
    'Content-Type':                  'application/json',
    'Content-Length':                Buffer.byteLength(body),
    'Access-Control-Allow-Origin':   '*',
    'Access-Control-Allow-Headers':  'Content-Type',
    'Access-Control-Allow-Methods':  'GET,POST,PUT,PATCH,DELETE,OPTIONS',
  });
  res.end(body);
}

// ── API handler (/api/<table>[/<id>]) ─────────────────────────────────────────
async function handleApi(req, res) {
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin':  '*',
      'Access-Control-Allow-Headers': 'Content-Type',
      'Access-Control-Allow-Methods': 'GET,POST,PUT,PATCH,DELETE,OPTIONS',
    });
    return res.end();
  }

  const parts  = req.url.replace(/^\/api\/?/, '').split('/').filter(Boolean);
  const table  = parts[0];
  const id     = parts[1];
  const method = req.method.toUpperCase();

  if (!table || !TABLES.has(table)) {
    return jsonRes(res, 404, { error: `Unknown table: ${table}. Valid: ${[...TABLES].join(', ')}` });
  }

  const pkAttr = PK[table];

  try {
    // GET /api/<table>           → scan all items
    if (method === 'GET' && !id) {
      const r = await ddb.send(new ScanCommand({ TableName: table }));
      return jsonRes(res, 200, (r.Items || []).map(unmarshall));
    }

    // GET /api/<table>/<id>      → get one item
    if (method === 'GET' && id) {
      const r = await ddb.send(new GetItemCommand({
        TableName: table,
        Key: marshall({ [pkAttr]: id }),
      }));
      return jsonRes(res, 200, r.Item ? unmarshall(r.Item) : null);
    }

    // POST /api/<table>          → upsert (put) item
    if (method === 'POST') {
      const item = await readBody(req);
      await ddb.send(new PutItemCommand({
        TableName: table,
        Item: marshall(item, { removeUndefinedValues: true }),
      }));
      return jsonRes(res, 200, item);
    }

    // PATCH /api/<table>/<id>    → partial update
    if (method === 'PATCH' && id) {
      const fields = await readBody(req);
      const keys   = Object.keys(fields).filter(k => k !== pkAttr);
      if (!keys.length) return jsonRes(res, 200, fields);

      const EAN = {}, EAV = {};
      const setClauses = keys.map((k, i) => {
        EAN[`#f${i}`] = k;
        EAV[`:v${i}`] = fields[k];
        return `#f${i} = :v${i}`;
      });

      await ddb.send(new UpdateItemCommand({
        TableName:                 table,
        Key:                       marshall({ [pkAttr]: id }),
        UpdateExpression:          `SET ${setClauses.join(', ')}`,
        ExpressionAttributeNames:  EAN,
        ExpressionAttributeValues: marshall(EAV, { removeUndefinedValues: true }),
        ReturnValues:              'UPDATED_NEW',
      }));
      return jsonRes(res, 200, fields);
    }

    // DELETE /api/<table>/<id>
    if (method === 'DELETE' && id) {
      await ddb.send(new DeleteItemCommand({
        TableName: table,
        Key: marshall({ [pkAttr]: id }),
      }));
      return jsonRes(res, 200, { deleted: true });
    }

    jsonRes(res, 405, { error: 'Method not allowed' });

  } catch (err) {
    console.error(`[API] ${method} /api/${table}${id ? '/'+id : ''}:`, err.message);
    jsonRes(res, 500, { error: err.message });
  }
}

// ── Static file handler ───────────────────────────────────────────────────────
function handleStatic(req, res) {
  const urlPath  = req.url.split('?')[0];
  const resolved = path.resolve(DIST, '.' + urlPath);
  if (!resolved.startsWith(DIST)) { res.writeHead(403); return res.end('Forbidden'); }

  const serve = (filePath, fallback) => {
    fs.readFile(filePath, (err, data) => {
      if (err) {
        if (fallback) return serve(fallback, null);
        res.writeHead(404); return res.end('Not found');
      }
      const ext = path.extname(filePath).toLowerCase();
      res.writeHead(200, {
        'Content-Type':   MIME[ext] || 'application/octet-stream',
        'Content-Length': data.length,
        'Cache-Control':  urlPath.startsWith('/assets/') ? 'public,max-age=31536000,immutable' : 'no-cache',
      });
      res.end(data);
    });
  };

  if (urlPath === '/' || !path.extname(urlPath)) {
    serve(path.join(DIST, 'index.html'), null);
  } else {
    serve(resolved, path.join(DIST, 'index.html'));
  }
}

// ── Main request handler ──────────────────────────────────────────────────────
function handler(req, res) {
  if (req.url.startsWith('/api/')) return handleApi(req, res);
  handleStatic(req, res);
}

// ── HTTP (port 80) ────────────────────────────────────────────────────────────
http.createServer(handler)
  .listen(PORT_HTTP, '0.0.0.0', () => console.log(`[HTTP]  → http://0.0.0.0:${PORT_HTTP}`))
  .on('error', e => console.error(`[HTTP]  ${e.code==='EACCES' ? 'Need root for port '+PORT_HTTP : e.message}`));

// ── HTTPS (port 443) ──────────────────────────────────────────────────────────
try {
  const tls = {
    key:  fs.readFileSync(path.join(CERTS, 'key.pem')),
    cert: fs.readFileSync(path.join(CERTS, 'cert.pem')),
  };
  https.createServer(tls, handler)
    .listen(PORT_HTTPS, '0.0.0.0', () => console.log(`[HTTPS] → https://0.0.0.0:${PORT_HTTPS}`))
    .on('error', e => console.error(`[HTTPS] ${e.code==='EACCES' ? 'Need root for port '+PORT_HTTPS : e.message}`));
} catch {
  console.warn('[HTTPS] certs/key.pem or certs/cert.pem not found — HTTPS disabled');
}

process.on('SIGTERM', () => process.exit(0));
process.on('SIGINT',  () => process.exit(0));

console.log(`[PAS]   Region: ${REGION} | Credentials: EC2 IAM role (automatic)`);
