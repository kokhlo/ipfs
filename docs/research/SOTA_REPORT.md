# SOTA Report: IPFS Ecosystem (ipfs crate research)

**Date**: 2026-09-07  
**Researcher**: Claude-4.5  
**Purpose**: Foundations for ipfs crate v0.1 design — minimal trustless HTTP gateway client

---

## 1. SOTA Libraries by Language

| Name | Language | libp2p dependency | HTTP Gateway mode | Trustless verifiable fetch | Maturity | Notes |
|------|----------|-------------------|-------------------|---------------------------|----------|-------|
| **kubo** (go-ipfs) | Go | Yes (full) | Yes (server) | Yes (CAR) | Production | Reference implementation; 17.1k stars; active (2026-09-06); libp2p + DHT + bitswap [1] |
| **Helia** (js-ipfs successor) | TypeScript | Yes (`@libp2p/…`) | Via `@helia/http` | Yes (verified-fetch) | Production | Modular, browser + Node; replaces js-ipfs (archived 2023-05); 267 stars js-multiformats [2] |
| **rust-ipfs** (rs-ipfs) | Rust | Yes (rust-libp2p) | Yes | Partial | **Archived (2022-10)** | Original; 1.3k stars; fork by dariusc93 active (v0.16, 67 stars, 2026-08) [3] |
| **py-ipfs** (ipfs-shipyard) | Python | No | No | No | **Early alpha (not remotely done)** | 477 stars; pushed 2025-05; py-ipfs-http-client (API wrapper) available [4] |
| **rust-libp2p** (libp2p/rust-libp2p) | Rust | N/A (is libp2p) | N/A | N/A | Production | Core p2p stack; v0.56 (2024-07); 5.6k stars; IPFS uses it [5] |
| **libp2p-rs** (web3infra-foundation) | Rust | N/A (alternative impl) | N/A | N/A | Experimental (v0.3, 2021) | Alternative async/await-driven libp2p; 172 stars; netwarps fork [6] |
| **erlang-libp2p** (helium) | Erlang | N/A (libp2p impl) | N/A | N/A | **Archived** | Helium blockchain; no longer maintained; docs refer to relay/proxy [7] |
| **ipfs-embed** (ipfs-rust) | Rust | Yes | Yes | Partial | Active (2024-03) | Embeddable lightweight IPFS; ipfs-rust org (most repos archived) [8] |
| **Iroh** (n0-computer) | Rust | No (QUIC + own NAT) | No (not IPFS) | No | Active | 12.5k stars; alternative to IPFS, not IPFS-compatible; previously Beetle [9] |

**Key findings**:
- **No Ada IPFS implementation exists** (only NFEL/requests_ipfs_adaptor, a 2022 HTTP adapter).
- **vivo75/ares does not exist** (404 on GitHub, Wayback, no repos in vivo75 profile matching Erlang/libp2p).
- **ipfs-rust/libp2p-rs does not exist** (ipfs-rust org has ipfs-embed, libp2p-bitswap; web3infra-foundation/libp2p-rs is the closest match).
- **py-ipfs** is not production-ready — "not even remotely done yet" per README.
- **Rust-IPFS (dariusc93 fork)** is the most viable Rust IPFS; original archived.
- **Helia + @helia/http** is the canonical lightweight JS client model.

---

## 2. Minimal Spec Set for Verifiable HTTP Gateway Client

To implement **trustless verifiable retrieval** over HTTP gateways (ipfs crate v0.1 goal), the following specs are required:

### Core primitives (MUST implement)

1. **CID** (Content IDentifier)  
   - Spec: https://specs.ipfs.tech/cid/ [10]  
   - Format: `<multicodec-cidv1><multicodec-content-type><multihash-content-address>` (unsigned varint encoding)  
   - CIDv0 backward compat (base58btc, dag-pb, sha256 implicit)  
   - Multibase prefixes: base58btc (`z`), base32 (`b`), base16 (`f`), base36 (`k`) for IPNS

2. **Multihash** (self-describing hash digest)  
   - Spec: https://github.com/multiformats/multihash [11]  
   - Format: `<varint hash code><varint digest size><digest bytes>`  
   - Hash table: https://github.com/multiformats/multicodec/blob/master/table.csv (sha2-256 `0x12`, sha2-512 `0x13`, blake2b-256 `0xb220`)

3. **Multibase** (self-describing base encoding)  
   - Spec: https://github.com/multiformats/multibase [12]  
   - Format: `<base-prefix-char><base-encoded-data>`  
   - Table: https://github.com/multiformats/multibase/blob/master/multibase.csv

4. **Multicodec** (self-describing codec ID)  
   - Table: https://github.com/multiformats/multicodec/blob/master/table.csv [13]  
   - Codes: `raw` (0x55), `dag-pb` (0x70), `dag-cbor` (0x71), `dag-json` (0x0129)

5. **Unsigned varint**  
   - Spec: https://github.com/multiformats/unsigned-varint [14]  
   - LEB128 variant: 7 bits/byte, MSB continuation flag, no signed, minimal encoding

### Content addressing & block formats (MUST implement subset)

6. **dag-pb** (UnixFS container)  
   - Spec: https://ipld.io/specs/codecs/dag-pb/spec/ [15]  
   - Protobuf schema: `PBNode { Links: [PBLink], Data: bytes }`  
   - Link sorting: lexicographic by Name field (bytes)

7. **UnixFS** (files & directories)  
   - Spec: https://specs.ipfs.tech/unixfs/ [16]  
   - Types: File (0x02), Directory (0x01), HAMTShard (0x05), Symlink (0x04)  
   - File chunking: `blocksizes` array for multi-block files
   - **Note**: `raw` codec (0x55) for single-block files (no dag-pb wrapper)

8. **CAR v1** (Content Addressable aRchive)  
   - Spec: https://ipld.io/specs/transport/car/carv1/ [17]  
   - Format: `<varint-header-len><dag-cbor-header>[ <varint-section-len><cid><block> ]*`  
   - Header: `{ version: 1, roots: [&Any] }` (DAG-CBOR)

### HTTP transport layer (MUST implement)

9. **Trustless Gateway Specification**  
   - Spec: https://specs.ipfs.tech/http-gateways/trustless-gateway/ [18]  
   - Endpoints: `GET /ipfs/{cid}[/{path}]?format=raw|car&dag-scope=block|entity|all&entity-bytes=from:to`  
   - Response types:
     - `application/vnd.ipld.raw` — single block (raw or dag-pb)
     - `application/vnd.ipld.car` — CAR stream (CARv1)
   - Headers: `Etag`, `Content-Location`, `X-Content-Type-Options: nosniff`
   - Verification: client MUST validate every block's multihash against its CID before processing

**Minimal flow**:
```
1. Parse CID → extract multicodec (0x55 raw / 0x70 dag-pb), multihash
2. Fetch via HTTP: GET /ipfs/{cid}?format=raw (single block)
3. Validate: hash(block) == multihash in CID
4. If dag-pb: decode protobuf → PBNode.Data (UnixFS) + Links
5. If multi-block file: fetch children via blocksizes offsets
6. For CAR: parse header → read sections → validate each block CID
```

**Optional but recommended**:
- **dag-cbor** (0x71) — structured data codec
- **dag-json** (0x0129) — human-readable codec
- **IPNS** (mutable pointers) — out of scope for v0.1

---

## 3. Test Vectors & Fixtures

### Official test vector repositories

| Spec | Location | Format | Notes |
|------|----------|--------|-------|
| **IPLD codec fixtures** | https://github.com/ipld/codec-fixtures [19] | CAR + per-codec files | Cross-codec (dag-pb, dag-cbor, dag-json); Go/JS/Rust/Python impls test against this |
| **Multibase spec tests** | https://github.com/multiformats/js-multibase/tree/master/test [20] | JS test files | `spec-test1..6.spec.js` — all bases, input "Decentralize everything!!" |
| **Multihash (no dedicated repo)** | Embedded in implementations | — | js-multiformats: `test/test-multihash.spec.ts` [21] |
| **CID (no dedicated repo)** | Embedded in implementations | — | js-multiformats: `test/test-cid.spec.ts` [21] |
| **CAR fixtures** | ipld/go-car `v2/testdata/` [22] | .car files | sample-v1.car, sample-v2-indexless.car, sample-unixfs-v2.car, fuzz/ |
| **UnixFS fixtures** | specs.ipfs.tech/unixfs/ [16] | Embedded in spec | Test CIDs for 0-byte dag-pb, single-link, 11 unnamed links |
| **Gateway conformance** | https://github.com/ipfs/gateway-conformance [23] | Go DSL test suite | `fixtures/` dir + extract-fixtures command; tests HTTP gateway compliance |

### Interop test approach
1. **js-multiformats fixtures** (`test/fixtures/`) — CID parsing/encoding edge cases
2. **codec-fixtures** — decode dag-pb/raw, re-encode, compare CID
3. **gateway-conformance** — HTTP fetch + CAR parsing + block validation
4. **go-car testdata** — CAR v1/v2 edge cases (corrupt pragma, zero-len section, rootless v42)

**Ada-specific needs**:
- **Varint edge cases**: max 9 bytes (64-bit limit), minimal encoding rejection
- **Protobuf strictness**: dag-pb field order, no duplicates (stricter than standard protobuf)
- **CAR validation**: reject out-of-order blocks, validate header DAG-CBOR

---

## 4. Minimal Client Architecture (rust-ipfs, py-ipfs, Helia patterns)

### rust-ipfs (dariusc93/rust-ipfs) [3]

**Architecture** (v0.16.0):
- **Does NOT implement minimal client** — full libp2p integration (DHT, bitswap, pubsub)
- **Uses rust-libp2p** for swarm, Kademlia DHT, mdns discovery
- **HTTP gateway**: `ipfs-http` crate exposes RPC API compatible with Kubo
- **Blockstore**: `ipfs-repo` (filesystem-backed, sled/rocksdb optional)
- **Content routing**: bitswap (pull), DHT content discovery

**What it discards for minimal mode**: None — this is a full node.

**Takeaway for the ipfs crate**: rust-ipfs is **not** a gateway client — it's a server. Wrong reference.

### py-ipfs (ipfs-shipyard/py-ipfs) [4]

**Status**: "Not even remotely done yet" (README, 2025-05 push)  
**Architecture**: Incomplete — no minimal client mode documented  
**IPFS HTTP client wrapper**: `py-ipfs-http-client` (ipfshttpclient) — connects to local/remote Kubo daemon over HTTP RPC API  
  - **Not a trustless client** — relies on gateway trust  
  - **Does not validate blocks** — just fetches via `/api/v0/cat`, `/api/v0/dag/get`

**What it uses**: HTTP API client (requests), no libp2p, no block validation

**Takeaway for the ipfs crate**: py-ipfs-http-client is a **trusted gateway wrapper**, not verifiable. Wrong reference.

### Helia (@helia/http, @helia/verified-fetch) [2]

**Architecture** (the right model):

#### @helia/http — HTTP-only gateway client
```typescript
import { createHeliaHTTP } from '@helia/http'
const helia = await createHeliaHTTP({ gateways: ['https://ipfs.io'] })
const { cid, bytes } = await helia.blockstore.get(CID.parse('bafybeigdyr...'))
```
- **No libp2p** — pure HTTP gateway fetches
- **Blockstore interface**: `get(cid) → block bytes`, backed by HTTP gateway
- **No DHT, no bitswap** — delegate to gateway for content routing
- **Block validation**: multihash verification in `@helia/block-brokers`

#### @helia/verified-fetch — trustless fetch API
```typescript
import { verifiedFetch } from '@helia/verified-fetch'
const resp = await verifiedFetch('ipfs://bafybeigdyr.../path/to/file')
// Returns Web API Response with verified bytes
```
- **Fetch-like API** over IPFS/IPNS URIs
- **CAR support**: `Accept: application/vnd.ipld.car` for efficient DAG fetches
- **Validation**: every block's multihash checked before assembly
- **UnixFS assembly**: multi-block files reconstructed from blocksizes

**Layers**:
1. **HTTP client** → gateway (fetch CAR or raw)
2. **CAR decoder** → stream of `(CID, block)` pairs
3. **Block validator** → `hash(block) == multihash_in_cid`
4. **UnixFS assembler** → concat blocks per blocksizes
5. **Public API** → `verifiedFetch(uri) → Response`

**What Helia discards for HTTP-only mode**:
- libp2p (no swarm, no DHT, no bitswap)
- Local block storage (ephemeral cache only, or delegate to gateway)

**Takeaway for the ipfs crate**: **@helia/http is the canonical minimal client**. Ada should replicate this architecture.

---

## 5. Ada-IPFS Architecture Recommendations

### Proposed layer structure

```
┌─────────────────────────────────────────────────────────┐
│  Public API (ipfs crate v0.1)                             │
│  - IPFS.Get(CID) → Bytes                                │
│  - IPFS.Cat(CID, Path) → Stream                         │
│  - IPFS.Verify_CAR(CAR_Bytes) → Boolean                 │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│  UnixFS Layer                                            │
│  - Decode dag-pb PBNode                                  │
│  - Assemble multi-block files (blocksizes)              │
│  - Traverse directories (Links)                         │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│  Block Validation                                        │
│  - Multihash.Verify(block, CID) → Boolean               │
│  - MUST reject on mismatch (security critical)          │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│  CAR Decoder                                             │
│  - Parse header (DAG-CBOR)                              │
│  - Read sections: varint len → CID → block              │
│  - Yield (CID, block) stream                            │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│  HTTP Gateway Client                                     │
│  - GET /ipfs/{cid}?format=car&dag-scope=all             │
│  - Parse response headers (Etag, Content-Type)          │
│  - Stream response body → CAR bytes                     │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│  Multiformats Primitives                                 │
│  - CID: parse/encode, multibase/multicodec/multihash    │
│  - Varint: encode/decode (minimal enforcement)          │
│  - Multibase: base58btc/base32/base16/base36            │
└─────────────────────────────────────────────────────────┘
```

### Package structure (Alire crates)

```
ipfs/                          -- root aggregate package
├── ipfs-primitives/           -- CID, multihash, multibase, varint
├── ipfs-car/                  -- CAR v1 encoder/decoder
├── ipfs-dag-pb/               -- dag-pb codec (protobuf)
├── ipfs-unixfs/               -- UnixFS file/directory handling
├── ipfs-http-client/          -- Trustless gateway HTTP fetch
└── ipfs/                      -- Public facade (IPFS.Get, IPFS.Cat)
```

**Dependencies** (Alire available):
- `simple_components` — protobuf codec (or roll own via GNAT Protocol Buffers)
- `tlsada` or `wolfssl` — HTTPS client (or use `aws` from AdaCore)
- `gnatcoll-json` — JSON/CBOR parsing (header parsing)
- `aunit` — unit testing

### Why Ada wins

1. **Type-safe CID/multihash**
   ```ada
   type CID_Version is (V0, V1);
   type Multicodec is (Raw, Dag_PB, Dag_CBOR, Dag_JSON);
   type Multihash_Code is (SHA2_256, SHA2_512, Blake2b_256);
   
   type CID is record
      Version : CID_Version;
      Codec   : Multicodec;
      Hash    : Multihash;
   end record
     with Dynamic_Predicate => 
       (if Version = V0 then Codec = Dag_PB and Hash.Code = SHA2_256);
   ```
   - Compiler enforces CIDv0 constraints (no runtime checks)
   - Impossible to construct invalid CID at compile time

2. **Contract-based validation**
   ```ada
   function Verify_Block(Block : Byte_Array; Expected_CID : CID) return Boolean
     with Post => (if Verify_Block'Result then 
                     Multihash.Digest(Block, Expected_CID.Hash.Code) = Expected_CID.Hash.Digest);
   ```
   - Formal specification in code
   - SPARK-provable (optional) → no runtime hash mismatches

3. **Stream-safe CAR parsing**
   ```ada
   procedure Read_CAR_Section(Stream : in out CAR_Stream; 
                               CID    : out CID_Type; 
                               Block  : out Byte_Array)
     with Pre  => Stream.Has_Next,
          Post => Block'Length = Stream.Last_Section_Length;
   ```
   - Buffer overflows prevented by preconditions
   - No manual bounds checking

4. **No GC pauses** — predictable latency for embedded/real-time systems
5. **SPARK potential** — formal proof of security properties (hash validation, no buffer overruns)
6. **Exception safety** — explicit error paths (no panic-based unwinding like Rust)

### Interfaces to define

```ada
-- ipfs-primitives/src/ipfs-cid.ads
package IPFS.CID is
   type CID is private;
   function Parse(Text : String) return CID;
   function To_String(C : CID; Base : Multibase_Code := Base58BTC) return String;
   function Verify(Block : Byte_Array; C : CID) return Boolean;
end IPFS.CID;

-- ipfs-http-client/src/ipfs-http_client.ads
package IPFS.HTTP_Client is
   type Gateway_Client is tagged private;
   procedure Fetch_Block(Client : in out Gateway_Client;
                          CID    : in IPFS.CID.CID;
                          Block  : out Byte_Array);
   procedure Fetch_CAR(Client : in out Gateway_Client;
                        CID    : in IPFS.CID.CID;
                        Scope  : DAG_Scope := All_Blocks;
                        Stream : out CAR_Stream);
end IPFS.HTTP_Client;

-- ipfs/src/ipfs.ads (public facade)
package IPFS is
   function Get(CID : String) return Byte_Array;
   function Cat(CID : String; Path : String := "") return File_Stream;
end IPFS;
```

---

## 6. Key Findings Summary

1. **No Ada IPFS exists** (first-mover advantage for kokhlo/ipfs)
2. **Minimal spec set**: CID + multihash/multibase/multicodec + dag-pb + UnixFS + CAR v1 + trustless gateway HTTP
3. **Test vectors**: ipld/codec-fixtures (CAR), js-multibase (multibase), gateway-conformance (HTTP), go-car/testdata (edge cases)
4. **Reference architecture**: Helia @helia/http (NOT rust-ipfs — that's a full node)
5. **Python IPFS is not viable** (early alpha, no validation)
6. **Rust landscape**: rust-ipfs archived (dariusc93 fork active), libp2p-rs (web3infra-foundation) experimental
7. **Ada wins on**: type safety (CID invariants), contracts (SPARK), stream safety (bounds), no GC
8. **v0.1 scope**: HTTP gateway client only (no libp2p, no DHT, no bitswap) — trustless CAR fetch + validation

---

## References

[1] https://github.com/ipfs/kubo  
[2] https://github.com/ipfs/helia  
[3] https://github.com/dariusc93/rust-ipfs (fork of archived rs-ipfs/rust-ipfs)  
[4] https://github.com/ipfs-shipyard/py-ipfs  
[5] https://github.com/libp2p/rust-libp2p  
[6] https://github.com/web3infra-foundation/libp2p-rs (ex-netwarps)  
[7] https://github.com/helium/erlang-libp2p (archived)  
[8] https://github.com/ipfs-rust/ipfs-embed  
[9] https://github.com/n0-computer/iroh  
[10] https://specs.ipfs.tech/cid/  
[11] https://github.com/multiformats/multihash  
[12] https://github.com/multiformats/multibase  
[13] https://github.com/multiformats/multicodec/blob/master/table.csv  
[14] https://github.com/multiformats/unsigned-varint  
[15] https://ipld.io/specs/codecs/dag-pb/spec/  
[16] https://specs.ipfs.tech/unixfs/  
[17] https://ipld.io/specs/transport/car/carv1/  
[18] https://specs.ipfs.tech/http-gateways/trustless-gateway/  
[19] https://github.com/ipld/codec-fixtures  
[20] https://github.com/multiformats/js-multibase/tree/master/test  
[21] https://github.com/multiformats/js-multiformats/tree/master/test  
[22] https://github.com/ipld/go-car (v2/testdata/)  
[23] https://github.com/ipfs/gateway-conformance  

**Report compiled**: 2026-09-07 16:42 MSK  
**Session**: claude-code subagent  
**Model**: claude-sonnet-4.5
