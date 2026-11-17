import type { RequestHandler } from "express";
import { loginUser,refreshSession , logoutCurrentSession , logoutAllSessions} from "../services/auth.service";

export const loginController: RequestHandler = async (req, res) => {
  const result = await loginUser(req.body, {
    deviceInfo: req.get("user-agent") ?? null,
    ipAddress: req.ip ?? null,
  });

  res.status(200).json({
    success: true,
    message: "Login successful",
    data: result,
  });
};

export const refreshController: RequestHandler = async (req, res) => {
  const result = await refreshSession(req.body.refreshToken, {
    deviceInfo: req.get("user-agent") ?? null,
    ipAddress: req.ip ?? null,
  });

  res.status(200).json({
    success: true,
    message: "Token refreshed",
    data: result,
  });
};

export const logoutController: RequestHandler = async (req, res) => {
  await logoutCurrentSession(req.auth!);

  res.status(200).json({
    success: true,
    message: "Logged out successfully",
  });
};

export const logoutAllController: RequestHandler = async (req, res) => {
  const result = await logoutAllSessions(req.auth!);

  res.status(200).json({
    success: true,
    message: "Logged out from all devices",
    data: result,
  });
};