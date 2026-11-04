import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import { pool } from "./config/db";

dotenv.config();

const app = express();

app.use(cors());
app.use(express.json());

// Basic server health check
app.get("/api/v1/health", (req, res) => {
  res.json({
    success: true,
    message: "KarurTrufs API is running",
  });
});

// Database connection test
app.get("/api/v1/health/db", async (req, res) => {
  try {
    const result = await pool.query(
      "SELECT current_database(), current_user, NOW()"
    );

    res.json({
      success: true,
      message: "Database connected successfully",
      database: result.rows[0],
    });
  } catch (error) {
    console.error("Database connection failed:", error);

    res.status(500).json({
      success: false,
      message: "Database connection failed",
    });
  }
});

const PORT = process.env.PORT || 5000;

app.listen(PORT, () => {
  console.log(`KarurTrufs API running on port ${PORT}`);
});