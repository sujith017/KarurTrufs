import type { RequestHandler } from "express";
import { AppError } from "../utils/AppError";
import { verifyAccessToken } from "../utils/token";
import { findActiveSession } from "../repositories/session.repository";

declare global {
  namespace Express {
    interface Request {
      auth?: { userId: string; sessionId: string };
    }
  }
}

export const authenticate: RequestHandler = async (req, res, next) => {
  const header = req.get("authorization");

  if (!header || !header.startsWith("Bearer ")) {
    return next(new AppError("Authentication required", 401));
  }

  const token = header.slice("Bearer ".length).trim();
  const { userId, sessionId } = verifyAccessToken(token);

  const session = await findActiveSession(sessionId, userId);

  if (!session) {
    return next(new AppError("Invalid or expired token", 401));
  }

  req.auth = { userId, sessionId };
  next();
};