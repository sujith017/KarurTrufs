import type { RequestHandler } from "express";
import type { ZodType } from "zod";
import { AppError } from "../utils/AppError";

export const validate = (schema: ZodType): RequestHandler => {
  return (req, res, next) => {
    const result = schema.safeParse(req.body);

    if (!result.success) {
      const messages = result.error.issues.map(
        (issue) => issue.message
      );

      return next(
        new AppError(messages.join(", "), 400)
      );
    }

    req.body = result.data;
    next();
  };
};