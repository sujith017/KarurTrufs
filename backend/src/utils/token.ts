import crypto from "node:crypto";
import jwt from "jsonwebtoken";
import { env } from "../config/env";
import { AppError } from "./AppError";

// Refresh token: a random string. The client keeps it; we store only its hash.
export const generateRefreshToken = (): string =>
  crypto.randomBytes(48).toString("hex");

export const hashRefreshToken = (token: string): string =>
  crypto.createHash("sha256").update(token).digest("hex");

// Access token: a short-lived signed JWT.
export const signAccessToken = (data: {
  userId: string;
  sessionId: string;
}): string =>
  jwt.sign({ sid: data.sessionId }, env.JWT_ACCESS_SECRET, {
    algorithm: "HS256",
    subject: data.userId,
    expiresIn: env.JWT_ACCESS_TTL_SECONDS,
  });

export const verifyAccessToken = (
  token: string
): { userId: string; sessionId: string } => {
  try {
    const decoded = jwt.verify(token, env.JWT_ACCESS_SECRET, {
      algorithms: ["HS256"],
    });

    if (
      typeof decoded === "string" ||
      !decoded.sub ||
      typeof decoded.sid !== "string"
    ) {
      throw new Error("Malformed token payload");
    }

    return { userId: decoded.sub, sessionId: decoded.sid };
  } catch {
    throw new AppError("Invalid or expired token", 401);
  }
};