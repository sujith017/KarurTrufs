
import dotenv from "dotenv";

dotenv.config();
const requiredEnv = ["DATABASE_URL", "JWT_ACCESS_SECRET", "OTP_HMAC_SECRET"] as const;



for (const key of requiredEnv) {
  if (!process.env[key]) {
    throw new Error(`Missing required environment variable: ${key}`);
  }
}

export const env = {
  PORT: Number(process.env.PORT) || 5000,
  DATABASE_URL: process.env.DATABASE_URL!,
  NODE_ENV: process.env.NODE_ENV || "development",
  FRONTEND_URL: process.env.FRONTEND_URL || "http://localhost:5173",
  JWT_ACCESS_SECRET: process.env.JWT_ACCESS_SECRET!,
  JWT_ACCESS_TTL_SECONDS: Number(process.env.JWT_ACCESS_TTL_SECONDS) || 900,
  REFRESH_TOKEN_TTL_DAYS: Number(process.env.REFRESH_TOKEN_TTL_DAYS) || 30,
  OTP_HMAC_SECRET: process.env.OTP_HMAC_SECRET!,
  OTP_TTL_MINUTES: Number(process.env.OTP_TTL_MINUTES) || 10,
  OTP_MAX_ATTEMPTS: Number(process.env.OTP_MAX_ATTEMPTS) || 5,
  OTP_RESEND_COOLDOWN_SECONDS: Number(process.env.OTP_RESEND_COOLDOWN_SECONDS) || 60,
  OTP_HOURLY_LIMIT: Number(process.env.OTP_HOURLY_LIMIT) || 5,
};
