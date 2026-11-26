import net from "node:net";
import {readFile} from "node:fs/promises";
import {createRequire} from "node:module";
import {join} from "node:path";
import {spawn} from "node:child_process";

const packageDirectory = process.env.HANYU_PG_TEST_DIR;
const python = process.env.HANYU_TEST_PY || "python";
if (!packageDirectory) {
  throw new Error("Set HANYU_PG_TEST_DIR to the temporary npm package directory.");
}
const require = createRequire(join(packageDirectory, "fixture.cjs"));
const {PGlite} = require("@electric-sql/pglite");
const {PGLiteSocketServer} = require("@electric-sql/pglite-socket");
const probe = net.createServer();
await new Promise((resolve, reject) => {
  probe.once("error", reject);
  probe.listen(0, "127.0.0.1", resolve);
});
const {port} = probe.address();
await new Promise((resolve) => probe.close(resolve));

const db = await PGlite.create();
let server;
try {
  await db.exec(`
    CREATE ROLE anon NOLOGIN;
    CREATE ROLE authenticated NOLOGIN;
    CREATE SCHEMA auth;
    CREATE SCHEMA storage;
    CREATE TABLE auth.users (id uuid PRIMARY KEY);
    CREATE TABLE auth.sessions (id uuid PRIMARY KEY, user_id uuid NOT NULL REFERENCES auth.users);
    CREATE TABLE storage.buckets (
      id text PRIMARY KEY, name text NOT NULL, public boolean NOT NULL,
      file_size_limit bigint, allowed_mime_types text[]
    );
    CREATE TABLE storage.objects (id uuid PRIMARY KEY, bucket_id text NOT NULL);
    ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
  `);
  const migration = new URL("../../../supabase/migrations/202611240001_ocr_queue.sql", import.meta.url);
  await db.exec(await readFile(migration, "utf8"));
  const workerMigration = new URL("../../../supabase/migrations/202611240002_ocr_worker.sql", import.meta.url);
  await db.exec(await readFile(workerMigration, "utf8"));
  const accountMigration = new URL("../../../supabase/migrations/202611240003_learner_account_bootstrap.sql", import.meta.url);
  await db.exec(await readFile(accountMigration, "utf8"));
  const vocabularyMigration = new URL("../../../supabase/migrations/202611250001_learner_vocabulary.sql", import.meta.url);
  await db.exec(await readFile(vocabularyMigration, "utf8"));
  const reviewMigration = new URL("../../../supabase/migrations/202611250002_review_sessions.sql", import.meta.url);
  await db.exec(await readFile(reviewMigration, "utf8"));
  const examMigration = new URL("../../../supabase/migrations/202611250003_exams.sql", import.meta.url);
  await db.exec(await readFile(examMigration, "utf8"));
  const learnerManagement = new URL("../../../supabase/migrations/202611250004_learner_management.sql", import.meta.url);
  await db.exec(await readFile(learnerManagement, "utf8"));
  const adminContent = new URL("../../../supabase/migrations/202611250005_admin_content.sql", import.meta.url);
  await db.exec(await readFile(adminContent, "utf8"));
  const scenarioWriting = new URL("../../../supabase/migrations/202611250006_scenarios_writing.sql", import.meta.url);
  await db.exec(await readFile(scenarioWriting, "utf8"));
  const roleplay = new URL("../../../supabase/migrations/202611250007_roleplay_sessions.sql", import.meta.url);
  await db.exec(await readFile(roleplay, "utf8"));
  const avatars = new URL("../../../supabase/migrations/202611250008_avatars.sql", import.meta.url);
  await db.exec(await readFile(avatars, "utf8"));
  const adminImport = new URL("../../../supabase/migrations/202611250009_admin_import.sql", import.meta.url);
  await db.exec(await readFile(adminImport, "utf8"));
  const cnn = new URL("../../../supabase/migrations/202611250010_cnn_prediction.sql", import.meta.url);
  await db.exec(await readFile(cnn, "utf8"));
  const tts = new URL("../../../supabase/migrations/202611250011_tts.sql", import.meta.url);
  await db.exec(await readFile(tts, "utf8"));
  const deletion = new URL("../../../supabase/migrations/202611250012_account_deletion.sql", import.meta.url);
  await db.exec(await readFile(deletion, "utf8"));
  const conversation = new URL("../../../supabase/migrations/202611250013_conversation_jobs.sql", import.meta.url);
  await db.exec(await readFile(conversation, "utf8"));
  const ocrDictionary = new URL("../../../supabase/migrations/202611260001_ocr_dictionary.sql", import.meta.url);
  await db.exec(await readFile(ocrDictionary, "utf8"));
  const ttsStaging = new URL("../../../supabase/migrations/202611260002_tts_staging.sql", import.meta.url);
  await db.exec(await readFile(ttsStaging, "utf8"));
  console.log("Backend migrations applied to local PGlite fixture");

  server = new PGLiteSocketServer({db, port, host:"127.0.0.1", maxConnections:16});
  await server.start();
  process.exitCode = await new Promise((resolve, reject) => {
    const child = spawn(python, ["-m", "unittest", "discover", "-s", "tests", "-v"], {
      cwd: new URL("../", import.meta.url),
      stdio: "inherit",
      env: {
        ...process.env,
        HANYU_TEST_DATABASE_URL: `postgresql://postgres@127.0.0.1:${port}/postgres?sslmode=disable`,
      },
      windowsHide: true,
    });
    child.once("error", reject);
    child.once("close", (code) => resolve(code ?? 1));
  });
} finally {
  if (server) await server.stop();
  await db.close();
}
