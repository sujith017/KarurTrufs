import type { RequestHandler } from "express";
import { loginUser,refreshSession , logoutCurrentSession , logoutAllSessions,sendPhoneVerificationOtp , verifyPhoneOtp} from "../services/auth.service";

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

export const sendPhoneOtpController: RequestHandler = async (req, res) => {
  const result = await sendPhoneVerificationOtp(req.auth!);

  // Never return the code itself, only when it expires
  res.status(200).json({
    success: true,
    message: "Verification code sent",
    data: { expiresAt: result.expiresAt },
  });
};

export const verifyPhoneOtpController: RequestHandler = async (req, res) => {
  const result = await verifyPhoneOtp(req.auth!, req.body.code);

  res.status(200).json({
    success: true,
    message: "Phone number verified",
    data: result,
  });
};