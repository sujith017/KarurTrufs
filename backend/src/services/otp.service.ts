import { env } from "../config/env";
import {
  createOtp,
  registerOtpAttempt,
  markOtpVerified,
} from "../repositories/otp.repository";
import { otpSender, type OtpPurpose } from "../providers/otp.provider";
import { generateOtpCode, hashOtp, otpHashesMatch } from "../utils/otp";
import { AppError } from "../utils/AppError";
export const issueOtp = async (data: {
  phone: string;
  purpose: OtpPurpose;
}) => {
  const code = generateOtpCode();
  const expiresAt = new Date(Date.now() + env.OTP_TTL_MINUTES * 60 * 1000);

  const result = await createOtp({
    phone: data.phone,
    purpose: data.purpose,
    otpHash: hashOtp({ ...data, code }),
    expiresAt,
    cooldownSeconds: env.OTP_RESEND_COOLDOWN_SECONDS,
    hourlyLimit: env.OTP_HOURLY_LIMIT,
  });

  if (result.status === "cooldown") {
    throw new AppError(
      `Please wait ${result.retryAfterSeconds} seconds before requesting another code`,
      429
    );
  }

  if (result.status === "hourly_limit") {
    throw new AppError("Too many code requests. Please try again later.", 429);
  }

  await otpSender.send({ phone: data.phone, code, purpose: data.purpose });

  return { expiresAt: result.expiresAt };
};

const invalidCodeError = () => new AppError("Invalid or expired code", 400);

// Throws if the code is wrong; returns normally only when the code is valid.
// Callers (phone verification, OTP login, password reset) decide what happens next.
export const verifyOtp = async (data: {
  phone: string;
  purpose: OtpPurpose;
  code: string;
}): Promise<void> => {
  const attempt = await registerOtpAttempt({
    phone: data.phone,
    purpose: data.purpose,
    maxAttempts: env.OTP_MAX_ATTEMPTS,
  });

  if (!attempt) throw invalidCodeError();

  if (!otpHashesMatch(hashOtp(data), attempt.otpHash)) {
    throw invalidCodeError();
  }

  const consumed = await markOtpVerified(attempt.id);
  if (!consumed) throw invalidCodeError();
};