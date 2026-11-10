import { z } from "zod";

export const registerUserSchema = z.object({
  fullName: z
    .string()
    .trim()
    .min(3, "Name must contain at least 3 characters")
    .max(100, "Name cannot exceed 100 characters"),

  email: z
    .string()
    .trim()
    .email("Please provide a valid email address")
    .toLowerCase(),

  phone: z
    .string()
    .regex(/^[6-9]\d{9}$/, "Please provide a valid Indian phone number"),

  password: z
    .string()
    .min(8, "Password must contain at least 8 characters")
    .max(72, "Password cannot exceed 72 characters"),
});

export const loginUserSchema = z.object({
  identifier: z
    .string()
    .trim()
    .min(1, "Email or phone number is required"),

  password: z
    .string()
    .min(1, "Password is required"),
});