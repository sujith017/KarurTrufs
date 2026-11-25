// import { findUserByIdentifier } from "../repositories/user.repository";
import {
  createSession,
  rotateSession,
  revokeSession,
  revokeAllUserSessions
} from "../repositories/session.repository";
import { comparePassword } from "../utils/password";
import {
  generateRefreshToken,
  hashRefreshToken,
  signAccessToken,
} from "../utils/token";
import { AppError } from "../utils/AppError";
import { env } from "../config/env";
import { issueOtp, verifyOtp } from "./otp.service";

import {
  findUserByIdentifier,
  findUserById,
  markPhoneVerified,
} from "../repositories/user.repository";
export const loginUser = async (
  data: { identifier: string; password: string },
  context: { deviceInfo: string | null; ipAddress: string | null },
) => {
  // 1. Find user by email or phone
  const user = await findUserByIdentifier(data.identifier);

  // 2. Unknown user, or account with no password (e.g. Google-only)
  if (!user || !user.password_hash) {
    throw new AppError("Invalid email/phone or password", 401);
  }

  // 3. Verify password BEFORE revealing anything about account status
  const isPasswordValid = await comparePassword(
    data.password,
    user.password_hash,
  );

  if (!isPasswordValid) {
    throw new AppError("Invalid email/phone or password", 401);
  }

  // 4. Only now, with proof of ownership, report an inactive account
  if (!user.is_active) {
    throw new AppError("Your account is inactive", 403);
  }

  // 5. Create a session: store only the HASH of the refresh token
  const refreshToken = generateRefreshToken();
  const expiresAt = new Date(
    Date.now() + env.REFRESH_TOKEN_TTL_DAYS * 24 * 60 * 60 * 1000,
  );

  const session = await createSession({
    userId: user.id,
    refreshTokenHash: hashRefreshToken(refreshToken),
    deviceInfo: context.deviceInfo,
    ipAddress: context.ipAddress,
    expiresAt,
  });

  // 6. Sign a short-lived access token tied to this session
  const accessToken = signAccessToken({
    userId: user.id,
    sessionId: session.id,
  });

  // 7. Return safe user info plus both tokens
  return {
    user: {
      id: user.id,
      full_name: user.full_name,
      email: user.email,
      phone: user.phone,
    },
    accessToken,
    refreshToken,
  };
};

export const refreshSession = async (
  refreshToken: string,
  context: { deviceInfo: string | null; ipAddress: string | null },
) => {
  const newRefreshToken = generateRefreshToken();
  const expiresAt = new Date(
    Date.now() + env.REFRESH_TOKEN_TTL_DAYS * 24 * 60 * 60 * 1000,
  );

  const result = await rotateSession({
    oldTokenHash: hashRefreshToken(refreshToken),
    newTokenHash: hashRefreshToken(newRefreshToken),
    expiresAt,
    deviceInfo: context.deviceInfo,
    ipAddress: context.ipAddress,
  });

  // Same message for unknown, expired and reused tokens
  if (result.status !== "rotated") {
    throw new AppError("Invalid or expired refresh token", 401);
  }

  const accessToken = signAccessToken({
    userId: result.userId,
    sessionId: result.sessionId,
  });

  return { accessToken, refreshToken: newRefreshToken };
};

export const logoutCurrentSession = async (auth: {
  userId: string;
  sessionId: string;
}) => {
  await revokeSession(auth.sessionId, auth.userId);
};

export const logoutAllSessions = async (auth: { userId: string }) => {
  const count = await revokeAllUserSessions(auth.userId);
  return { revokedSessions: count };
};

export const sendPhoneVerificationOtp = async (auth: { userId: string }) => {
  const user = await findUserById(auth.userId);

  if (!user || !user.is_active) {
    throw new AppError("Account unavailable", 403);
  }

  if (!user.phone) {
    throw new AppError("No phone number on this account", 400);
  }

  // Don't send (and pay for) a code the user doesn't need
  if (user.phone_verified_at) {
    throw new AppError("Phone number is already verified", 409);
  }

  // The phone comes from OUR database, never from the request
  return issueOtp({ phone: user.phone, purpose: "PHONE_VERIFICATION" });
};

export const verifyPhoneOtp = async (
  auth: { userId: string },
  code: string
) => {
  const user = await findUserById(auth.userId);

  if (!user || !user.is_active) {
    throw new AppError("Account unavailable", 403);
  }

  if (!user.phone) {
    throw new AppError("No phone number on this account", 400);
  }

  if (user.phone_verified_at) {
    throw new AppError("Phone number is already verified", 409);
  }

  // Throws "Invalid or expired code" unless the code is right
  await verifyOtp({
    phone: user.phone,
    purpose: "PHONE_VERIFICATION",
    code,
  });

  const updated = await markPhoneVerified(user.id, user.phone);

  if (!updated) {
    throw new AppError(
      "Phone number changed. Please request a new code.",
      409
    );
  }

  return { phoneVerified: true };
};