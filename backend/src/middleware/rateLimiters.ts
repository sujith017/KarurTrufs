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