/**
 * Unit tests for the LevelDB reader.
 *
 * Each test constructs minimal binary fixtures (SSTable .ldb and/or
 * write-ahead log .log files) in a temp directory, then calls
 * findKeysContaining and asserts the results.
 *
 * Run:  node --experimental-transform-types --no-warnings=ExperimentalWarning \
 *         --test src/helpers/leveldb.test.ts
 */

import { describe, it, beforeEach, afterEach } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { findKeysContaining } from "./leveldb.ts";

// ── Helpers: encode primitives ──────────────────────────────────────

const enc = new TextEncoder();

function encodeVarint(n: number): Uint8Array {
  const bytes: number[] = [];
  while (n > 0x7f) {
    bytes.push((n & 0x7f) | 0x80);
    n >>>= 7;
  }
  bytes.push(n & 0x7f);
  return Uint8Array.from(bytes);
}

function encodeU32LE(n: number): Uint8Array {
  const buf = new Uint8Array(4);
  buf[0] = n & 0xff;
  buf[1] = (n >>> 8) & 0xff;
  buf[2] = (n >>> 16) & 0xff;
  buf[3] = (n >>> 24) & 0xff;
  return buf;
}

function encodeU64LE(n: bigint): Uint8Array {
  const buf = new Uint8Array(8);
  const view = new DataView(buf.buffer);
  view.setBigUint64(0, n, true);
  return buf;
}

function cat(...parts: Uint8Array[]): Uint8Array {
  let total = 0;
  for (const p of parts) total += p.length;
  const out = new Uint8Array(total);
  let off = 0;
  for (const p of parts) { out.set(p, off); off += p.length; }
  return out;
}

// ── Helpers: LevelDB internal key ───────────────────────────────────

/** Pack sequence number and value type into 8-byte trailer.
 *  Layout: (sequence << 8) | type, stored little-endian. */
function packSeqType(seq: bigint, kind: number): Uint8Array {
  return encodeU64LE((seq << 8n) | BigInt(kind));
}

function internalKey(userKey: Uint8Array, seq: bigint, kind: number = 1): Uint8Array {
  return cat(userKey, packSeqType(seq, kind));
}

// ── Helpers: build a data block ─────────────────────────────────────
//
// Entries are written with no prefix compression (shared=0 for every
// entry) and a single restart point at offset 0. This is the simplest
// valid block structure.

function buildDataBlock(entries: Array<{ key: Uint8Array; value: Uint8Array }>): Uint8Array {
  const parts: Uint8Array[] = [];
  for (const { key, value } of entries) {
    parts.push(
      encodeVarint(0),          // shared bytes = 0 (no prefix compression)
      encodeVarint(key.length), // unshared bytes
      encodeVarint(value.length),
      key,
      value,
    );
  }
  // Restart array: one restart point at offset 0
  parts.push(encodeU32LE(0)); // restart[0] = 0
  parts.push(encodeU32LE(1)); // num_restarts = 1
  return cat(...parts);
}

/** Wrap a raw block with compression-type byte (0=none) and 4-byte fake CRC. */
function wrapBlock(block: Uint8Array): Uint8Array {
  return cat(block, Uint8Array.from([0x00]), new Uint8Array(4)); // type=none, crc=0000
}

// ── Helpers: build a minimal SSTable ────────────────────────────────

const SSTABLE_MAGIC = Uint8Array.from([0x57, 0xfb, 0x80, 0x8b, 0x24, 0x75, 0x47, 0xdb]);

function buildSSTable(entries: Array<{ key: Uint8Array; value: Uint8Array }>): Uint8Array {
  // 1. Data block
  const dataBlock = buildDataBlock(entries);
  const wrappedData = wrapBlock(dataBlock);
  const dataOffset = 0;
  const dataSize = dataBlock.length;

  // 2. Empty metaindex block (no filter/stats metadata)
  const metaBlock = buildDataBlock([]);
  const wrappedMeta = wrapBlock(metaBlock);
  const metaOffset = wrappedData.length;
  const metaSize = metaBlock.length;

  // 3. Index block — one entry pointing to the data block.
  //    The index key can be anything >= last data key. We use 0xff repeated.
  const indexKey = Uint8Array.from([0xff, 0xff, 0xff, 0xff]);
  const dataHandle = cat(encodeVarint(dataOffset), encodeVarint(dataSize));
  const indexBlock = buildDataBlock([{ key: indexKey, value: dataHandle }]);
  const wrappedIndex = wrapBlock(indexBlock);
  const indexOffset = metaOffset + wrappedMeta.length;
  const indexSize = indexBlock.length;

  // 4. Footer (48 bytes): metaindex handle + index handle + padding + magic
  const metaHandle = cat(encodeVarint(metaOffset), encodeVarint(metaSize));
  const idxHandle = cat(encodeVarint(indexOffset), encodeVarint(indexSize));
  const handlesLen = metaHandle.length + idxHandle.length;
  const padding = new Uint8Array(40 - handlesLen); // pad to 40 bytes before magic
  const footer = cat(metaHandle, idxHandle, padding, SSTABLE_MAGIC);
  assert.equal(footer.length, 48, "footer must be 48 bytes");

  return cat(wrappedData, wrappedMeta, wrappedIndex, footer);
}

// ── Helpers: build a WAL log file ───────────────────────────────────

interface BatchRecord {
  kind: number; // 0=delete, 1=put
  key: Uint8Array;
  value?: Uint8Array;
}

function buildWriteBatch(seq: bigint, records: BatchRecord[]): Uint8Array {
  const parts: Uint8Array[] = [
    encodeU64LE(seq),
    encodeU32LE(records.length),
  ];
  for (const r of records) {
    parts.push(Uint8Array.from([r.kind]));
    parts.push(encodeVarint(r.key.length));
    parts.push(r.key);
    if (r.kind === 1) {
      const val = r.value ?? new Uint8Array(0);
      parts.push(encodeVarint(val.length));
      parts.push(val);
    }
  }
  return cat(...parts);
}

/** Wrap a WriteBatch into a FULL log record (type=1). CRC is zeroed. */
function buildLogRecord(batch: Uint8Array): Uint8Array {
  const len = batch.length;
  const header = new Uint8Array(7);
  // bytes 0..3 = crc (zeroed)
  header[4] = len & 0xff;
  header[5] = (len >> 8) & 0xff;
  header[6] = 1; // FULL
  return cat(header, batch);
}

function buildLogFile(batches: Array<{ seq: bigint; records: BatchRecord[] }>): Uint8Array {
  const parts = batches.map(b => buildLogRecord(buildWriteBatch(b.seq, b.records)));
  return cat(...parts);
}

// ── Test setup ──────────────────────────────────────────────────────

let dir: string;

beforeEach(() => {
  dir = mkdtempSync(join(tmpdir(), "leveldb-test-"));
});

afterEach(() => {
  rmSync(dir, { recursive: true, force: true });
});

// ── Tests ───────────────────────────────────────────────────────────

describe("findKeysContaining", () => {

  describe("SSTable reading", () => {
    it("finds matching entries from a single .ldb file", () => {
      const sst = buildSSTable([
        { key: internalKey(enc.encode("hello"), 1n), value: enc.encode("world") },
        { key: internalKey(enc.encode("test_key"), 2n), value: enc.encode("test_val") },
      ]);
      writeFileSync(join(dir, "000001.ldb"), sst);

      const results = findKeysContaining(dir, enc.encode("test"));
      assert.equal(results.length, 1);
      assert.deepEqual(new TextDecoder().decode(results[0]!.key), "test_key");
      assert.deepEqual(new TextDecoder().decode(results[0]!.value), "test_val");
    });

    it("returns all matches when multiple keys contain the needle", () => {
      const sst = buildSSTable([
        { key: internalKey(enc.encode("cfg_v1"), 1n), value: enc.encode("a") },
        { key: internalKey(enc.encode("cfg_v2"), 2n), value: enc.encode("b") },
        { key: internalKey(enc.encode("other"), 3n), value: enc.encode("c") },
      ]);
      writeFileSync(join(dir, "000001.ldb"), sst);

      const results = findKeysContaining(dir, enc.encode("cfg_"));
      assert.equal(results.length, 2);
      const keys = results.map(r => new TextDecoder().decode(r.key)).sort();
      assert.deepEqual(keys, ["cfg_v1", "cfg_v2"]);
    });

    it("reads .sst files as well as .ldb", () => {
      const sst = buildSSTable([
        { key: internalKey(enc.encode("foo"), 1n), value: enc.encode("bar") },
      ]);
      writeFileSync(join(dir, "000001.sst"), sst);

      const results = findKeysContaining(dir, enc.encode("foo"));
      assert.equal(results.length, 1);
    });
  });

  describe("log file reading", () => {
    it("finds entries from a .log file", () => {
      const log = buildLogFile([{
        seq: 10n,
        records: [
          { kind: 1, key: enc.encode("log_key"), value: enc.encode("log_val") },
        ],
      }]);
      writeFileSync(join(dir, "000001.log"), log);

      const results = findKeysContaining(dir, enc.encode("log_key"));
      assert.equal(results.length, 1);
      assert.deepEqual(new TextDecoder().decode(results[0]!.value), "log_val");
    });

    it("parses multiple records within one WriteBatch", () => {
      const log = buildLogFile([{
        seq: 1n,
        records: [
          { kind: 1, key: enc.encode("k1"), value: enc.encode("v1") },
          { kind: 1, key: enc.encode("k2"), value: enc.encode("v2") },
          { kind: 1, key: enc.encode("k3"), value: enc.encode("v3") },
        ],
      }]);
      writeFileSync(join(dir, "000001.log"), log);

      const results = findKeysContaining(dir, enc.encode("k"));
      assert.equal(results.length, 3);
    });
  });

  describe("sequence-based deduplication", () => {
    it("keeps the version with the highest sequence number", () => {
      // SSTable has seq=1, log has seq=10 for the same key → log wins.
      const sst = buildSSTable([
        { key: internalKey(enc.encode("mykey"), 1n), value: enc.encode("old") },
      ]);
      const log = buildLogFile([{
        seq: 10n,
        records: [{ kind: 1, key: enc.encode("mykey"), value: enc.encode("new") }],
      }]);
      writeFileSync(join(dir, "000001.ldb"), sst);
      writeFileSync(join(dir, "000002.log"), log);

      const results = findKeysContaining(dir, enc.encode("mykey"));
      assert.equal(results.length, 1);
      assert.deepEqual(new TextDecoder().decode(results[0]!.value), "new");
    });

    it("SSTable with higher sequence wins over log with lower sequence", () => {
      const sst = buildSSTable([
        { key: internalKey(enc.encode("mykey"), 100n), value: enc.encode("sst_val") },
      ]);
      const log = buildLogFile([{
        seq: 5n,
        records: [{ kind: 1, key: enc.encode("mykey"), value: enc.encode("log_val") }],
      }]);
      writeFileSync(join(dir, "000001.ldb"), sst);
      writeFileSync(join(dir, "000002.log"), log);

      const results = findKeysContaining(dir, enc.encode("mykey"));
      assert.equal(results.length, 1);
      assert.deepEqual(new TextDecoder().decode(results[0]!.value), "sst_val");
    });

    it("deduplicates across multiple SSTable files", () => {
      const sst1 = buildSSTable([
        { key: internalKey(enc.encode("k"), 1n), value: enc.encode("first") },
      ]);
      const sst2 = buildSSTable([
        { key: internalKey(enc.encode("k"), 5n), value: enc.encode("second") },
      ]);
      writeFileSync(join(dir, "000001.ldb"), sst1);
      writeFileSync(join(dir, "000002.ldb"), sst2);

      const results = findKeysContaining(dir, enc.encode("k"));
      assert.equal(results.length, 1);
      assert.deepEqual(new TextDecoder().decode(results[0]!.value), "second");
    });
  });

  describe("tombstone handling", () => {
    it("excludes keys whose newest record is a deletion", () => {
      // SSTable puts the key, log deletes it.
      const sst = buildSSTable([
        { key: internalKey(enc.encode("doomed"), 1n), value: enc.encode("alive") },
      ]);
      const log = buildLogFile([{
        seq: 10n,
        records: [{ kind: 0, key: enc.encode("doomed") }], // delete
      }]);
      writeFileSync(join(dir, "000001.ldb"), sst);
      writeFileSync(join(dir, "000002.log"), log);

      const results = findKeysContaining(dir, enc.encode("doomed"));
      assert.equal(results.length, 0);
    });

    it("a put after a delete resurrects the key", () => {
      const log = buildLogFile([
        { seq: 1n, records: [{ kind: 1, key: enc.encode("phoenix"), value: enc.encode("v1") }] },
        { seq: 5n, records: [{ kind: 0, key: enc.encode("phoenix") }] },            // delete
        { seq: 10n, records: [{ kind: 1, key: enc.encode("phoenix"), value: enc.encode("v2") }] }, // re-put
      ]);
      writeFileSync(join(dir, "000001.log"), log);

      const results = findKeysContaining(dir, enc.encode("phoenix"));
      assert.equal(results.length, 1);
      assert.deepEqual(new TextDecoder().decode(results[0]!.value), "v2");
    });

    it("deletion in a batch only affects matching keys", () => {
      const log = buildLogFile([{
        seq: 1n,
        records: [
          { kind: 1, key: enc.encode("keep_me"), value: enc.encode("yes") },
          { kind: 0, key: enc.encode("delete_me") },
        ],
      }]);
      writeFileSync(join(dir, "000001.log"), log);

      assert.equal(findKeysContaining(dir, enc.encode("keep_me")).length, 1);
      assert.equal(findKeysContaining(dir, enc.encode("delete_me")).length, 0);
    });
  });

  describe("empty values", () => {
    it("returns entries with empty values (not confused with deletion)", () => {
      const sst = buildSSTable([
        { key: internalKey(enc.encode("empty_val"), 1n), value: new Uint8Array(0) },
      ]);
      writeFileSync(join(dir, "000001.ldb"), sst);

      const results = findKeysContaining(dir, enc.encode("empty_val"));
      assert.equal(results.length, 1);
      assert.equal(results[0]!.value.length, 0);
    });
  });

  describe("needle matching", () => {
    it("empty needle matches all keys", () => {
      const sst = buildSSTable([
        { key: internalKey(enc.encode("a"), 1n), value: enc.encode("1") },
        { key: internalKey(enc.encode("b"), 2n), value: enc.encode("2") },
      ]);
      writeFileSync(join(dir, "000001.ldb"), sst);

      const results = findKeysContaining(dir, new Uint8Array(0));
      assert.equal(results.length, 2);
    });

    it("no match returns empty array", () => {
      const sst = buildSSTable([
        { key: internalKey(enc.encode("abc"), 1n), value: enc.encode("x") },
      ]);
      writeFileSync(join(dir, "000001.ldb"), sst);

      const results = findKeysContaining(dir, enc.encode("zzz"));
      assert.equal(results.length, 0);
    });

    it("matches needle in the middle of the key", () => {
      const sst = buildSSTable([
        { key: internalKey(enc.encode("prefix_NEEDLE_suffix"), 1n), value: enc.encode("ok") },
      ]);
      writeFileSync(join(dir, "000001.ldb"), sst);

      const results = findKeysContaining(dir, enc.encode("NEEDLE"));
      assert.equal(results.length, 1);
    });
  });

  describe("edge cases", () => {
    it("non-existent directory returns empty array", () => {
      const results = findKeysContaining("/tmp/no-such-dir-ever", enc.encode("x"));
      assert.equal(results.length, 0);
    });

    it("empty directory returns empty array", () => {
      const results = findKeysContaining(dir, enc.encode("x"));
      assert.equal(results.length, 0);
    });

    it("ignores non-LevelDB files in the directory", () => {
      writeFileSync(join(dir, "README.txt"), "not a leveldb file");
      writeFileSync(join(dir, "LOCK"), "");
      writeFileSync(join(dir, "CURRENT"), "MANIFEST-000001\n");

      const results = findKeysContaining(dir, enc.encode("x"));
      assert.equal(results.length, 0);
    });

    it("skips corrupt .ldb files without crashing", () => {
      writeFileSync(join(dir, "000001.ldb"), Uint8Array.from([0xde, 0xad]));
      // Also put a valid file so we verify the good one still works.
      const sst = buildSSTable([
        { key: internalKey(enc.encode("ok"), 1n), value: enc.encode("fine") },
      ]);
      writeFileSync(join(dir, "000002.ldb"), sst);

      const results = findKeysContaining(dir, enc.encode("ok"));
      assert.equal(results.length, 1);
    });

    it("processes files in numeric order", () => {
      // 000002.ldb has seq=1, 000001.ldb has seq=2. Regardless of file
      // order, seq=2 should win because dedup is sequence-based.
      const sst1 = buildSSTable([
        { key: internalKey(enc.encode("k"), 2n), value: enc.encode("from_file1") },
      ]);
      const sst2 = buildSSTable([
        { key: internalKey(enc.encode("k"), 1n), value: enc.encode("from_file2") },
      ]);
      writeFileSync(join(dir, "000001.ldb"), sst1);
      writeFileSync(join(dir, "000002.ldb"), sst2);

      const results = findKeysContaining(dir, enc.encode("k"));
      assert.equal(results.length, 1);
      assert.deepEqual(new TextDecoder().decode(results[0]!.value), "from_file1");
    });

    it("WriteBatch sequence increments per record", () => {
      // One batch at seq=10 with two puts for different keys.
      // The second record should get seq=11.
      const log = buildLogFile([{
        seq: 10n,
        records: [
          { kind: 1, key: enc.encode("first"), value: enc.encode("v1") },
          { kind: 1, key: enc.encode("second"), value: enc.encode("v2") },
        ],
      }]);
      writeFileSync(join(dir, "000001.log"), log);

      // Now add an SSTable with seq=10 for "second" — should lose to
      // the log's seq=11 for "second".
      const sst = buildSSTable([
        { key: internalKey(enc.encode("second"), 10n), value: enc.encode("old") },
      ]);
      writeFileSync(join(dir, "000002.ldb"), sst);

      const results = findKeysContaining(dir, enc.encode("second"));
      assert.equal(results.length, 1);
      assert.deepEqual(new TextDecoder().decode(results[0]!.value), "v2");
    });
  });

  describe("returned entries are independent copies", () => {
    it("mutating returned key/value does not affect future calls", () => {
      const sst = buildSSTable([
        { key: internalKey(enc.encode("immutable"), 1n), value: enc.encode("safe") },
      ]);
      writeFileSync(join(dir, "000001.ldb"), sst);

      const r1 = findKeysContaining(dir, enc.encode("immutable"));
      // Mutate the returned buffers
      r1[0]!.key[0] = 0xff;
      r1[0]!.value[0] = 0xff;

      // A second call should return clean data
      const r2 = findKeysContaining(dir, enc.encode("immutable"));
      assert.deepEqual(new TextDecoder().decode(r2[0]!.key), "immutable");
      assert.deepEqual(new TextDecoder().decode(r2[0]!.value), "safe");
    });
  });
});
