/**
 * Read-only LevelDB parser for extracting Chromium Local Storage data.
 *
 * Implements just enough of the LevelDB on-disk format to scan key-value
 * entries from SSTable (.ldb/.sst) and write-ahead log (.log) files.
 * Includes an inline Snappy decompressor so no native modules are needed.
 *
 * Design: generator-based scanning avoids building large intermediate
 * arrays — only entries that match the caller's filter are retained.
 * Internal keys (user key + 8-byte sequence/type trailer) are parsed so
 * that duplicate keys resolve to the newest version and tombstones
 * (deletion markers) are honoured.
 *
 * Format references:
 *   SSTable layout  — https://github.com/google/leveldb/blob/main/doc/table_format.md
 *   Write-ahead log — https://github.com/google/leveldb/blob/main/doc/log_format.md
 *   Snappy raw format — https://github.com/google/snappy/blob/main/format_description.txt
 *   Chromium Local Storage — https://source.chromium.org/chromium/chromium/src/+/main:components/services/storage/dom_storage/local_storage_impl.cc
 */

import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";

// ── Public API ──────────────────────────────────────────────────────

export interface LevelDBEntry {
  key: Uint8Array;
  value: Uint8Array;
}

/**
 * Scan a Chromium LevelDB directory and return every live entry whose
 * key contains `needle` as a contiguous subsequence.
 *
 * When multiple versions of the same user key exist (across SSTables and
 * log files), only the version with the highest sequence number is kept.
 * Keys whose newest record is a deletion are excluded.
 */
export function findKeysContaining(
  dir: string,
  needle: Uint8Array,
): LevelDBEntry[] {
  // Track the newest version of each matching user key.
  // Key string is hex-encoded for use as Map key (user keys are short).
  const best = new Map<string, { userKey: Uint8Array; value: Uint8Array; seq: bigint; deleted: boolean }>();

  for (const rec of scanRecords(dir)) {
    if (!subsequenceMatch(rec.userKey, needle)) continue;

    const hex = hexKey(rec.userKey);
    const prev = best.get(hex);
    if (!prev || rec.seq > prev.seq) {
      best.set(hex, {
        userKey: rec.userKey.slice(),
        value: rec.value.slice(),
        seq: rec.seq,
        deleted: rec.kind === KIND_DELETION,
      });
    }
  }

  const result: LevelDBEntry[] = [];
  for (const entry of best.values()) {
    if (!entry.deleted) {
      result.push({ key: entry.userKey, value: entry.value });
    }
  }
  return result;
}

// ── Internal record representation ──────────────────────────────────
//
// LevelDB stores each key with a 56-bit sequence number and an 8-bit
// value type packed into the last 8 bytes of the on-disk key.
// See: https://github.com/google/leveldb/blob/main/db/dbformat.h

const KIND_DELETION = 0;
const KIND_VALUE = 1;

interface InternalRecord {
  userKey: Uint8Array;
  value: Uint8Array;
  seq: bigint;
  kind: number; // KIND_DELETION | KIND_VALUE
}

/** Extract user key and sequence/type from an SSTable internal key. */
function splitInternalKey(raw: Uint8Array): { userKey: Uint8Array; seq: bigint; kind: number } | null {
  // Internal keys are at least 8 bytes (the trailer alone); empty user
  // keys are valid per the LevelDB spec, though unusual in practice.
  if (raw.length < 8) return null;
  const trailer = raw.subarray(raw.length - 8);
  const view = new DataView(trailer.buffer, trailer.byteOffset, 8);
  const packed = view.getBigUint64(0, true);
  // Lower 8 bits = value type, upper 56 bits = sequence number.
  const kind = Number(packed & 0xffn);
  const seq = packed >> 8n;
  if (kind !== KIND_DELETION && kind !== KIND_VALUE) return null;
  return { userKey: raw.subarray(0, raw.length - 8), seq, kind };
}

// ── Directory scanner ───────────────────────────────────────────────

/**
 * Yield every record from all SSTable and log files in `dir`.
 *
 * Files are sorted by numeric name so that records from newer files
 * (higher file numbers) are yielded later. This is not strictly needed
 * because sequence numbers determine freshness, but it keeps iteration
 * order predictable.
 *
 * Note: we scan every file in the directory without consulting the
 * MANIFEST. This means obsolete SSTables (not yet garbage-collected)
 * may contribute stale records. For Chromium Local Storage extraction
 * this is acceptable — the sequence-based dedup in findKeysContaining
 * still picks the newest version, and false resurrections from
 * compacted-away tombstones are extremely unlikely in practice.
 */
function* scanRecords(dir: string): Generator<InternalRecord> {
  let names: string[];
  try {
    names = readdirSync(dir);
  } catch {
    return;
  }

  // LevelDB names files as <6-digit number>.<ext>. Sort numerically
  // so we process older files first.
  const byNumber = (a: string, b: string) => {
    const na = parseInt(a, 10);
    const nb = parseInt(b, 10);
    if (!Number.isNaN(na) && !Number.isNaN(nb)) return na - nb;
    return a.localeCompare(b);
  };

  // SSTables first (compacted, older data), then logs (recent writes).
  const sstFiles = names.filter(n => n.endsWith(".ldb") || n.endsWith(".sst")).sort(byNumber);
  const logFiles = names.filter(n => n.endsWith(".log")).sort(byNumber);

  for (const name of sstFiles) {
    yield* readSSTableRecords(join(dir, name));
  }
  for (const name of logFiles) {
    yield* readLogRecords(join(dir, name));
  }
}

// ── SSTable reader ──────────────────────────────────────────────────
//
// SSTable layout (from table_format.md):
//
//   [data block 0]
//   [data block 1]
//   ...
//   [meta block 0]  (e.g. filter)
//   ...
//   [metaindex block]
//   [index block]
//   [footer]          (48 bytes, fixed size)
//
// The footer ends with an 8-byte magic number so we can quickly reject
// non-SSTable files. The footer also contains two BlockHandles that
// point to the metaindex and index blocks.

/** 8-byte magic at the end of every SSTable footer.
 *  Value 0xdb4775248b80fb57 — chosen by the LevelDB authors as a
 *  fingerprint; no semantic meaning beyond file identification.
 *  See: https://github.com/google/leveldb/blob/main/table/format.cc */
const SSTABLE_MAGIC = new Uint8Array([0x57, 0xfb, 0x80, 0x8b, 0x24, 0x75, 0x47, 0xdb]);

const FOOTER_SIZE = 48; // Two BlockHandles (max 10 bytes each) + padding + 8 byte magic

function* readSSTableRecords(path: string): Generator<InternalRecord> {
  let data: Uint8Array;
  try {
    data = readFileSync(path);
  } catch {
    return;
  }
  if (data.length < FOOTER_SIZE) return;

  // ── Footer validation ──
  const footer = data.subarray(data.length - FOOTER_SIZE);
  if (!bytesEqual(footer.subarray(40, 48), SSTABLE_MAGIC)) return;

  try {
    // Skip metaindex handle, read index handle.
    const [, metaHandleLen] = decodeBlockHandle(footer, 0);
    const [indexHandle] = decodeBlockHandle(footer, metaHandleLen);

    // ── Read index block (uncompressed list of data-block handles) ──
    const indexBlock = readBlock(data, indexHandle);
    if (!indexBlock) return;

    // Each index entry's value is a BlockHandle pointing to a data block.
    for (const indexEntry of iterBlockEntries(indexBlock)) {
      const [dataHandle] = decodeBlockHandle(indexEntry.value, 0);
      const dataBlock = readBlock(data, dataHandle);
      if (!dataBlock) continue;

      for (const kv of iterBlockEntries(dataBlock)) {
        const parsed = splitInternalKey(kv.key);
        if (parsed) yield { ...parsed, value: kv.value };
      }
    }
  } catch {
    // Corrupt table — skip silently. The caller only needs a best-effort
    // scan, and a single corrupt file should not abort the whole directory.
  }
}

/** A BlockHandle is two varints: offset and size. */
interface BlockHandle { offset: number; size: number }

function decodeBlockHandle(buf: Uint8Array, pos: number): [BlockHandle, number] {
  const [offset, n1] = varint(buf, pos);
  const [size, n2] = varint(buf, pos + n1);
  return [{ offset, size }, n1 + n2];
}

/**
 * Read and decompress one data/index block from an SSTable.
 *
 * Each block is stored as:
 *   [block data ...] [compression type: 1 byte] [crc32: 4 bytes]
 *
 * The 5-byte trailer (type + crc) follows immediately after the block
 * data. We skip CRC verification — this reader prioritises simplicity
 * and the data is from a local filesystem, not a network transfer.
 */
function readBlock(table: Uint8Array, handle: BlockHandle): Uint8Array | null {
  const totalSize = handle.size + 5; // block data + 1 byte type + 4 byte crc
  if (handle.offset + totalSize > table.length) return null;

  const compressionType = table[handle.offset + handle.size]!;
  const raw = table.subarray(handle.offset, handle.offset + handle.size);

  if (compressionType === 0) return raw;                   // no compression
  if (compressionType === 1) return snappyDecompress(raw);  // Snappy
  return null; // unknown compression — skip rather than crash
}

// ── Data block entry iterator ───────────────────────────────────────
//
// Data blocks use prefix compression to save space on sorted keys.
// Each entry stores:
//   [shared key bytes: varint]  — bytes shared with the previous key
//   [unshared key bytes: varint]
//   [value length: varint]
//   [unshared key data ...]
//   [value data ...]
//
// At fixed intervals (the "restart interval", typically every 16 keys),
// a full key is written (shared = 0) and its offset recorded in a
// restart-point array at the end of the block. This enables binary
// search within the block — we don't need that for a sequential scan,
// but we do need the restart count to know where entries end.

function* iterBlockEntries(block: Uint8Array): Generator<{ key: Uint8Array; value: Uint8Array }> {
  if (block.length < 4) return;

  // Last 4 bytes: uint32le count of restart points.
  const restartCount = u32le(block, block.length - 4);
  // Entries live before the restart array. Each restart is a 4-byte offset.
  const entriesEnd = block.length - 4 - restartCount * 4;
  if (entriesEnd < 0) return;

  let pos = 0;
  let prevKey = new Uint8Array(0);

  while (pos < entriesEnd) {
    const [shared, n1] = varint(block, pos);     pos += n1;
    const [unshared, n2] = varint(block, pos);   pos += n2;
    const [valueLen, n3] = varint(block, pos);    pos += n3;

    if (pos + unshared + valueLen > entriesEnd) break;

    // Reconstruct key: reuse `shared` bytes from previous key, then
    // append `unshared` new bytes.
    const delta = block.subarray(pos, pos + unshared);
    pos += unshared;
    const key = concat(prevKey.subarray(0, shared), delta);

    const value = block.subarray(pos, pos + valueLen);
    pos += valueLen;

    prevKey = key;
    yield { key: key.slice(), value: value.slice() };
  }
}

// ── Log file reader ─────────────────────────────────────────────────
//
// The write-ahead log is a sequence of 32 KiB physical blocks, each
// containing one or more records. A record that doesn't fit in the
// remaining space of a block is split across blocks using fragment types:
//
//   FULL   (1) — complete record in one fragment
//   FIRST  (2) — first fragment of a multi-block record
//   MIDDLE (3) — continuation fragment
//   LAST   (4) — final fragment
//
// Record header: [crc32: 4 bytes] [length: uint16le] [type: uint8]
//
// Inside each complete record is a WriteBatch:
//   [sequence: uint64le] [count: uint32le] [records ...]
// where each record is:
//   type=1 (put): [key_len: varint] [key] [value_len: varint] [value]
//   type=0 (delete): [key_len: varint] [key]

const LOG_BLOCK_SIZE = 32768; // 32 KiB — from the spec
const LOG_HEADER_SIZE = 7;    // 4 (crc) + 2 (length) + 1 (type)

const FRAG_FULL = 1;
const FRAG_FIRST = 2;
const FRAG_MIDDLE = 3;
const FRAG_LAST = 4;

function* readLogRecords(path: string): Generator<InternalRecord> {
  let data: Uint8Array;
  try {
    data = readFileSync(path);
  } catch {
    return;
  }

  let pos = 0;
  let fragments: Uint8Array[] = [];

  while (pos < data.length) {
    const blockOffset = pos % LOG_BLOCK_SIZE;
    const remaining = LOG_BLOCK_SIZE - blockOffset;

    // If fewer than LOG_HEADER_SIZE bytes remain in this physical block,
    // the spec says they are zero-padded filler — skip to next block.
    if (remaining < LOG_HEADER_SIZE) {
      pos += remaining;
      continue;
    }
    if (pos + LOG_HEADER_SIZE > data.length) break;

    const length = data[pos + 4]! | (data[pos + 5]! << 8);
    const type = data[pos + 6]!;

    if (pos + LOG_HEADER_SIZE + length > data.length) {
      // Truncated record at end of file — nothing more to read.
      break;
    }

    // A zero-length record in FIRST position is legal per the spec
    // (the payload is split entirely into MIDDLE/LAST fragments).
    // Only skip zero-length + invalid type as true corruption.
    if (length === 0 && type === 0) {
      pos += remaining;
      fragments = [];
      continue;
    }

    const payload = data.subarray(pos + LOG_HEADER_SIZE, pos + LOG_HEADER_SIZE + length);
    pos += LOG_HEADER_SIZE + length;

    switch (type) {
      case FRAG_FULL:
        fragments = [];
        yield* parseWriteBatch(payload);
        break;
      case FRAG_FIRST:
        fragments = [payload.slice()];
        break;
      case FRAG_MIDDLE:
        if (fragments.length > 0) fragments.push(payload.slice());
        break;
      case FRAG_LAST:
        if (fragments.length > 0) {
          fragments.push(payload.slice());
          yield* parseWriteBatch(concat(...fragments));
        }
        fragments = [];
        break;
      default:
        // Unknown fragment type — discard accumulated state and continue.
        fragments = [];
    }
  }
}

/**
 * Parse a WriteBatch payload into internal records.
 *
 * Batch header: 8-byte LE sequence number + 4-byte LE record count.
 * Each record in the batch gets an incrementing sequence starting from
 * the batch's base sequence. This mirrors the real LevelDB behaviour
 * and lets us correctly resolve multi-key batches.
 */
function* parseWriteBatch(batch: Uint8Array): Generator<InternalRecord> {
  if (batch.length < 12) return;

  // Sequence number occupies bytes 0..7.  We only need the lower 53 bits
  // for JS numeric safety, but use BigInt to match SSTable sequences.
  const seqView = new DataView(batch.buffer, batch.byteOffset, 8);
  let seq = seqView.getBigUint64(0, true);

  // bytes 8..11 = count (we don't enforce it — just parse until end)
  let pos = 12;

  while (pos < batch.length) {
    const recordType = batch[pos++]!;

    if (recordType === KIND_VALUE) {
      const [keyLen, n1] = varint(batch, pos);  pos += n1;
      if (pos + keyLen > batch.length) break;
      const userKey = batch.subarray(pos, pos + keyLen);
      pos += keyLen;

      const [valLen, n2] = varint(batch, pos);  pos += n2;
      if (pos + valLen > batch.length) break;
      const value = batch.subarray(pos, pos + valLen);
      pos += valLen;

      yield { userKey, value, seq, kind: KIND_VALUE };
      seq++;
    } else if (recordType === KIND_DELETION) {
      const [keyLen, n1] = varint(batch, pos);  pos += n1;
      if (pos + keyLen > batch.length) break;
      const userKey = batch.subarray(pos, pos + keyLen);
      pos += keyLen;

      yield { userKey, value: new Uint8Array(0), seq, kind: KIND_DELETION };
      seq++;
    } else {
      break; // unknown record type — stop parsing this batch
    }
  }
}

// ── Snappy raw decompressor ─────────────────────────────────────────
//
// LevelDB blocks use raw (unframed) Snappy compression. The format is:
//   [uncompressed length: varint] [tagged elements ...]
//
// Each element starts with a tag byte whose lower 2 bits identify the type:
//   00 = literal  — copy `len` bytes verbatim from the compressed stream
//   01 = copy-1   — back-reference with 1-byte offset extension (short copies)
//   10 = copy-2   — back-reference with 2-byte little-endian offset
//   11 = copy-4   — back-reference with 4-byte little-endian offset
//
// Back-references copy `len` bytes from a position `offset` bytes behind
// the current output pointer. Overlapping copies (offset < len) are valid
// and must be handled byte-at-a-time because later bytes depend on earlier
// ones within the same copy operation.
//
// Reference: https://github.com/google/snappy/blob/main/format_description.txt

const SNAPPY_MAX_UNCOMPRESSED = 1 << 27; // 128 MiB safety cap

function snappyDecompress(compressed: Uint8Array): Uint8Array {
  let pos = 0;

  const [declaredLen, hdrSize] = varint(compressed, 0);
  pos += hdrSize;

  if (declaredLen > SNAPPY_MAX_UNCOMPRESSED) {
    throw new Error(`Snappy: declared length ${declaredLen} exceeds safety limit`);
  }
  if (declaredLen === 0) return new Uint8Array(0);

  const out = new Uint8Array(declaredLen);
  let op = 0; // output position

  while (pos < compressed.length && op < declaredLen) {
    const tag = compressed[pos++]!;
    const tagType = tag & 0x03;

    if (tagType === 0) {
      // ── Literal ──
      // Upper 6 bits encode length-1 for short literals (0..59).
      // Values 60..63 mean the length-1 is in the next 1..4 bytes.
      const lenCode = (tag >> 2) & 0x3f;
      let len: number;
      if (lenCode < 60) {
        len = lenCode + 1;
      } else {
        const extra = lenCode - 59; // 1..4 bytes of length follow
        if (pos + extra > compressed.length) throw new Error("Snappy: truncated literal length");
        len = 0;
        for (let i = 0; i < extra; i++) {
          len |= compressed[pos++]! << (i * 8);
        }
        len += 1;
      }
      if (pos + len > compressed.length) throw new Error("Snappy: literal exceeds input");
      if (op + len > declaredLen) throw new Error("Snappy: literal exceeds declared length");
      out.set(compressed.subarray(pos, pos + len), op);
      pos += len;
      op += len;
    } else if (tagType === 1) {
      // ── Copy with 1-byte offset ──
      // Length: 3 bits from tag (bits 4..2) plus 4  →  range 4..11
      // Offset: 3 bits from tag (bits 7..5) as high bits, next byte as low bits
      if (pos >= compressed.length) throw new Error("Snappy: truncated copy-1");
      const len = ((tag >> 2) & 0x07) + 4;
      const offset = ((tag >> 5) << 8) | compressed[pos++]!;
      if (offset === 0 || offset > op) throw new Error("Snappy: invalid copy-1 offset");
      if (op + len > declaredLen) throw new Error("Snappy: copy-1 exceeds declared length");
      for (let i = 0; i < len; i++) out[op] = out[op++ - offset]!;
    } else if (tagType === 2) {
      // ── Copy with 2-byte little-endian offset ──
      if (pos + 2 > compressed.length) throw new Error("Snappy: truncated copy-2");
      const len = ((tag >> 2) & 0x3f) + 1;
      const offset = compressed[pos]! | (compressed[pos + 1]! << 8);
      pos += 2;
      if (offset === 0 || offset > op) throw new Error("Snappy: invalid copy-2 offset");
      if (op + len > declaredLen) throw new Error("Snappy: copy-2 exceeds declared length");
      for (let i = 0; i < len; i++) out[op] = out[op++ - offset]!;
    } else {
      // ── Copy with 4-byte little-endian offset ──
      if (pos + 4 > compressed.length) throw new Error("Snappy: truncated copy-4");
      const len = ((tag >> 2) & 0x3f) + 1;
      // Read as unsigned: JS bitwise OR produces a signed int32,
      // so we use `>>> 0` to convert back to unsigned.
      const offset = (
        compressed[pos]! |
        (compressed[pos + 1]! << 8) |
        (compressed[pos + 2]! << 16) |
        (compressed[pos + 3]! << 24)
      ) >>> 0;
      pos += 4;
      if (offset === 0 || offset > op) throw new Error("Snappy: invalid copy-4 offset");
      if (op + len > declaredLen) throw new Error("Snappy: copy-4 exceeds declared length");
      for (let i = 0; i < len; i++) out[op] = out[op++ - offset]!;
    }
  }

  if (op !== declaredLen) {
    throw new Error(`Snappy: output ${op} bytes but declared ${declaredLen}`);
  }
  return out;
}

// ── Byte-level helpers ──────────────────────────────────────────────

/** Decode a protobuf-style varint (LEB128, up to 32-bit value). */
function varint(buf: Uint8Array, offset: number): [value: number, bytesRead: number] {
  let result = 0;
  let shift = 0;
  let i = 0;
  while (offset + i < buf.length) {
    const byte = buf[offset + i]!;
    i++;
    result |= (byte & 0x7f) << shift;
    if ((byte & 0x80) === 0) return [result >>> 0, i];
    shift += 7;
    if (shift >= 35) throw new Error("varint overflow");
  }
  throw new Error("varint: unexpected end of data");
}

/** Read a little-endian uint32 from `buf` at `offset`. */
function u32le(buf: Uint8Array, offset: number): number {
  return (
    buf[offset]! |
    (buf[offset + 1]! << 8) |
    (buf[offset + 2]! << 16) |
    (buf[offset + 3]! << 24)
  ) >>> 0;
}

function concat(...arrays: Uint8Array[]): Uint8Array {
  let total = 0;
  for (const a of arrays) total += a.length;
  const out = new Uint8Array(total);
  let off = 0;
  for (const a of arrays) { out.set(a, off); off += a.length; }
  return out;
}

function bytesEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false;
  for (let i = 0; i < a.length; i++) {
    if (a[i] !== b[i]) return false;
  }
  return true;
}

/** True if `haystack` contains `needle` as a contiguous subsequence. */
function subsequenceMatch(haystack: Uint8Array, needle: Uint8Array): boolean {
  if (needle.length === 0) return true;
  const end = haystack.length - needle.length;
  outer: for (let i = 0; i <= end; i++) {
    for (let j = 0; j < needle.length; j++) {
      if (haystack[i + j] !== needle[j]) continue outer;
    }
    return true;
  }
  return false;
}

function hexKey(buf: Uint8Array): string {
  let s = "";
  for (let i = 0; i < buf.length; i++) s += buf[i]!.toString(16).padStart(2, "0");
  return s;
}
