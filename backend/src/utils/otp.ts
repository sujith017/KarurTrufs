import crypto from "node:crypto";
import { env } from "../config/env";
import type { OtpPurpose } from "../providers/otp.provider";

// 6-digit code from a cryptographically secure source, zero-padded ("004217")
export const generateOtpCode = (): string =>
  crypto.randomInt(0, 1_000_000).toString().padStart(6, "0");

// The hash is bound to the phone and purpose, and keyed with a server secret
export const hashOtp = (data: {
  phone: string;
  purpose: OtpPurpose;
  code: string;
}): string =>
  crypto
    .createHmac("sha256", env.OTP_HMAC_SECRET)
    .update(`${data.phone}:${data.purpose}:${data.code}`)
    .digest("hex");

// Constant-time comparison of two hex hashes
export const otpHashesMatch = (a: string, b: string): boolean => {
  const bufferA = Buffer.from(a, "hex");
  const bufferB = Buffer.from(b, "hex");

  if (bufferA.length !== bufferB.length) return false;

  return crypto.timingSafeEqual(bufferA, bufferB);
};