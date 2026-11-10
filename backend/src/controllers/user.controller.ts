import type { RequestHandler } from "express";
import { registerUser } from "../services/user.service";

export const registerUserController: RequestHandler = async (
  req,
  res
) => {
  const user = await registerUser(req.body);

  res.status(201).json({
    success: true,
    message: "User registered successfully",
    data: user,
  });
};