#!/usr/bin/env node
/* PNG'yi sol-ust koseden W x H olarak kirpar.  Harici bagimlilik yok (Node zlib).
   Kullanim: node tools/pngcrop.js giris.png cikis.png W H                      */
const fs = require('fs'), zlib = require('zlib');
const [, , inF, outF, wArg, hArg] = process.argv;
const CW = +wArg, CH = +hArg;
const buf = fs.readFileSync(inF);
if (buf.readUInt32BE(0) !== 0x89504e47) throw new Error('PNG degil: ' + inF);

let off = 8, ihdr = null, idat = [];
while (off < buf.length) {
  const len = buf.readUInt32BE(off), type = buf.toString('ascii', off + 4, off + 8);
  const data = buf.slice(off + 8, off + 8 + len);
  if (type === 'IHDR') ihdr = data;
  else if (type === 'IDAT') idat.push(data);
  else if (type === 'IEND') break;
  off += 12 + len;
}
const W = ihdr.readUInt32BE(0), H = ihdr.readUInt32BE(4);
const depth = ihdr[8], ctype = ihdr[9];
if (depth !== 8 || (ctype !== 6 && ctype !== 2)) throw new Error('desteklenmeyen PNG formati');
const BPP = ctype === 6 ? 4 : 3;
if (CW > W || CH > H) throw new Error('kirpma boyutu kaynaktan buyuk: ' + W + 'x' + H);

const raw = zlib.inflateSync(Buffer.concat(idat));
const stride = W * BPP;
const img = Buffer.alloc(H * stride);
let pos = 0;
for (let y = 0; y < H; y++) {
  const f = raw[pos++];
  const line = raw.slice(pos, pos + stride); pos += stride;
  for (let x = 0; x < stride; x++) {
    const a = x >= BPP ? img[y * stride + x - BPP] : 0;
    const b = y > 0 ? img[(y - 1) * stride + x] : 0;
    const c = (x >= BPP && y > 0) ? img[(y - 1) * stride + x - BPP] : 0;
    let v = line[x];
    if (f === 1) v += a;
    else if (f === 2) v += b;
    else if (f === 3) v += (a + b) >> 1;
    else if (f === 4) {
      const p = a + b - c, pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c);
      v += (pa <= pb && pa <= pc) ? a : (pb <= pc ? b : c);
    }
    img[y * stride + x] = v & 255;
  }
}
const cs = CW * BPP;
const out = Buffer.alloc(CH * (cs + 1));
for (let y = 0; y < CH; y++) {
  out[y * (cs + 1)] = 0;
  img.copy(out, y * (cs + 1) + 1, y * stride, y * stride + cs);
}
function chunk(type, data) {
  const b = Buffer.alloc(8 + data.length + 4);
  b.writeUInt32BE(data.length, 0); b.write(type, 4, 'ascii'); data.copy(b, 8);
  b.writeInt32BE(crc(Buffer.concat([Buffer.from(type, 'ascii'), data])) | 0, 8 + data.length);
  return b;
}
let T = null;
function crc(b) {
  if (!T) { T = []; for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; T[n] = c >>> 0; } }
  let c = 0xffffffff;
  for (let i = 0; i < b.length; i++) c = T[(c ^ b[i]) & 255] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}
const nh = Buffer.from(ihdr); nh.writeUInt32BE(CW, 0); nh.writeUInt32BE(CH, 4);
fs.writeFileSync(outF, Buffer.concat([
  buf.slice(0, 8), chunk('IHDR', nh),
  chunk('IDAT', zlib.deflateSync(out, { level: 9 })), chunk('IEND', Buffer.alloc(0))
]));
