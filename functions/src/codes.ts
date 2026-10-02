import { createHmac } from "node:crypto";

/**
 * Rotating redeem code — must match lib/core/utils/redeem_code.dart exactly.
 * code = base32(HMAC-SHA256(secret, `${promoId}:${window}`)[0..30 bits])
 */
export const PERIOD_SECONDS = 30;
export const CODE_LENGTH = 6;
export const ALPHABET = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";

export function windowFor(ms: number): number {
  return Math.floor(Math.floor(ms / 1000) / PERIOD_SECONDS);
}

export function codeForWindow(secret: string, promoId: string, window: number): string {
  const mac = createHmac("sha256", secret).update(`${promoId}:${window}`).digest();
  const bits = (mac[0] << 22) | (mac[1] << 14) | (mac[2] << 6) | (mac[3] >> 2);
  let out = "";
  for (let i = 0; i < CODE_LENGTH; i++) {
    out += ALPHABET[(bits >> (5 * (CODE_LENGTH - 1 - i))) & 31];
  }
  return out;
}

export function normalize(input: string): string {
  return input.toUpperCase().replace(/[^0-9A-Z]/g, "");
}

/** Business days follow Jakarta time (UTC+7), not the server's UTC clock. */
export function jakartaDayKey(ms: number): string {
  const d = new Date(ms + 7 * 3600 * 1000);
  const mm = String(d.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(d.getUTCDate()).padStart(2, "0");
  return `${d.getUTCFullYear()}${mm}${dd}`;
}

/** "h00".."h23" — hour-of-day bucket in WIB for the busy-hours chart. */
export function jakartaHourField(ms: number): string {
  return `h${String(new Date(ms + 7 * 3600 * 1000).getUTCHours()).padStart(2, "0")}`;
}

export function jakartaMonthKey(ms: number): string {
  return jakartaDayKey(ms).slice(0, 6);
}

/** Haversine distance in metres. */
export function distanceMeters(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371000;
  const toRad = (x: number) => (x * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}
