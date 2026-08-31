import * as SQLite from "expo-sqlite";

const DATABASE_NAME = "versegarden.db";
const SCHEMA_VERSION = 1;
let databasePromise: Promise<SQLite.SQLiteDatabase> | null = null;

export async function initializeDatabase(): Promise<SQLite.SQLiteDatabase> {
  if (!databasePromise) databasePromise = openAndMigrateDatabase();
  return databasePromise;
}

async function openAndMigrateDatabase(): Promise<SQLite.SQLiteDatabase> {
  const database = await SQLite.openDatabaseAsync(DATABASE_NAME);
  await database.execAsync(`
    PRAGMA journal_mode = WAL;
    CREATE TABLE IF NOT EXISTS app_metadata (
      key TEXT PRIMARY KEY NOT NULL,
      value TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  `);

  const schemaVersion = await database.getFirstAsync<{ value: string }>(
    "SELECT value FROM app_metadata WHERE key = ?",
    ["schema_version"],
  );
  if (schemaVersion && Number(schemaVersion.value) > SCHEMA_VERSION) {
    throw new Error("The local database was created by a newer app version.");
  }
  if (!schemaVersion || Number(schemaVersion.value) < SCHEMA_VERSION) {
    await database.runAsync(
      "INSERT OR REPLACE INTO app_metadata (key, value, updated_at) VALUES (?, ?, ?)",
      ["schema_version", String(SCHEMA_VERSION), new Date().toISOString()],
    );
  }
  return database;
}
