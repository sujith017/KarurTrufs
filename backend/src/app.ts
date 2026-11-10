
import express from "express";
import cors from "cors";
import { pool } from "./config/db";
import { env } from "./config/env";
import { notFound } from "./middleware/notFound";
import { errorHandler } from "./middleware/errorHandler";
import userRoutes from "./routes/user.routes";


const app = express();

// Middleware
app.use(
  cors({
    origin: env.FRONTEND_URL,
  })
);


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

app.use("/api/v1/users", userRoutes);




// Handle unknown routes
app.use(notFound);

// Centralized error handler (must be last)
app.use(errorHandler);
export default app;
