import type { ErrorRequestHandler } from "express";
import { AppError } from "../utils/AppError";
import { env } from "../config/env";

export const errorHandler: ErrorRequestHandler = (
  err,
  req,
  res,
  next
) => {
  if (res.headersSent) {
    return next(err);
  }

  // Handle expected application errors
  if (err instanceof AppError) {
    return res.status(err.statusCode).json({
      success: false,
      message: err.message,
    });
  }

  // Log unexpected errors for debugging
  console.error("Unexpected error:", err);

  // Handle unexpected errors
  return res.status(500).json({
    success: false,
    message:
      env.NODE_ENV === "production"
        ? "Internal server error"
        : err instanceof Error
          ? err.message
          : "Unknown error",
  });
};