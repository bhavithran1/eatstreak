import { QRPayload } from '../types';

export function encodeQR(shopId: string): string {
  return JSON.stringify({ s: shopId, v: 1 });
}

export function decodeQR(data: string): QRPayload | null {
  try {
    const parsed = JSON.parse(data);
    if (parsed.s && parsed.v) {
      return { s: parsed.s, v: parsed.v };
    }
    return null;
  } catch {
    return null;
  }
}
