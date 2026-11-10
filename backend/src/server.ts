
import app from "./app";
import { pool } from "./config/db";
import { env } from "./config/env";

const server = app.listen(env.PORT, () => {
  console.log(`KarurTrufs API running on port ${env.PORT}`);
});

// Graceful shutdown
let isShuttingDown = false;

function shutdown(signal: string) {
  if (isShuttingDown) return;

  isShuttingDown = true;

  console.log(`\n${signal} received. Shutting down server...`);

  server.close(async (error) => {
    if (error) {
      console.error("Error closing HTTP server:", error);
      process.exitCode = 1;
    }

    try {
      await pool.end();
      console.log("PostgreSQL connection pool closed.");
    } catch (dbError) {
      console.error("Error closing PostgreSQL pool:", dbError);
      process.exitCode = 1;
    }
  });
}

process.on("SIGINT", () => shutdown("SIGINT"));
process.on("SIGTERM", () => shutdown("SIGTERM"));
