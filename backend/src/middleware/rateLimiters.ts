import rateLimit from "express-rate-limit";

const tooManyRequests = (message: string) => ({
  success: false,
  message,
});

// Login: strict, because this is where password guessing happens
export const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  limit: 10,
  standardHeaders: "draft-7",
  legacyHeaders: false,
  message: tooManyRequests("Too many login attempts. Please try again later."),
});

// Refresh: more generous, since legitimate apps call it regularly
export const refreshLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 60,
  standardHeaders: "draft-7",
  legacyHeaders: false,
  message: tooManyRequests("Too many requests. Please try again later."),
});
// OTP sending: each send costs money and can annoy a real person
export const otpSendLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 5,
  standardHeaders: "draft-7",
  legacyHeaders: false,
  message: tooManyRequests("Too many code requests. Please try again later."),
});
// OTP verification: guessing happens here
export const otpVerifyLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 10,
  standardHeaders: "draft-7",
  legacyHeaders: false,
  message: tooManyRequests("Too many verification attempts. Please try again later."),
});