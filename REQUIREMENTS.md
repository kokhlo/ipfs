# REQUIREMENTS

## 1. Overview

**ada-ipfs** is an Ada library for accessing and verifying content-addressed data from the InterPlanetary File System (IPFS) ecosystem. It provides a trustless HTTP gateway client, local CAR archive verification, and core IPFS primitives (CID, multihash, multibase, UnixFS).

### Goals

- **Verifiable gateway access**: Fetch IPFS content via HTTP gateways with cryptographic verification of every block.
- **Offline verification**: Read and validate CAR archives without network access.
- **Ada-native implementation**: Zero C/FFI dependencies for core codecs; pure Ada parsing and hashing.
- **Embedded-friendly**: Support for zero runtime heap allocation in verification paths (configurable).
- **SPARK-ready subset**: Core codecs annotated for SPARK formal verification.
- **Developer ergonomics**: CLI tool (`ipfs-get`), clear error types, examples for every feature.

### Non-Goals (v0.1)

- Full libp2p stack (bitswap, DHT, pubsub, QUIC transport)
- Private IPFS swarms (no libp2p peer identity, swarm keys)
- Content creation/publishing (CID generation from files, CAR authoring)
- IPLD advanced traversals (selectors, graphsync)
- WebSocket-only gateways
- Pinning services API

## 2. Users & Use Cases

### UC-1: Media Player Developer (NebulaPlayer-style p2p media app)

**Actor**: Application developer building a decentralized media player.

**Scenario**: Embed IPFS content retrieval into an Ada GUI application. Fetch audio/video files by CID from public HTTP gateways, verify integrity locally, pass file path to media decoder.

**Requirements**: Gateway client with block-by-block verification, UnixFS file reconstruction, clear error reporting (network vs verification failure).

### UC-2: CLI Power User

**Actor**: DevOps engineer, researcher, or Ada enthusiast.

**Scenario**: Fetch a dataset/document published on IPFS using a one-liner: `ipfs-get <cid> -o data.tar.gz`. Must work on macOS, Linux (x86_64/aarch64).

**Requirements**: Standalone CLI binary, follows Unix conventions (exit codes, stdout/stderr), supports `--gateway`, `--timeout`, `--verify` flags.

### UC-3: Offline CAR Archive Auditor

**Actor**: Security researcher, compliance officer.

**Scenario**: Verify integrity of a CAR archive received via non-IPFS channel (email, USB stick). Check that every block's hash matches its CID without network access.

**Requirements**: CAR v1 parser, multihash verification, typed errors for corrupted blocks, no network I/O.

### UC-4: Ada Application Integrator

**Actor**: Developer embedding IPFS-addressed content into another Ada system (e.g., firmware updater, document management).

**Scenario**: Add `with Ada_IPFS;` to project, parse CID strings from user input or config files, fetch content via gateway, handle errors gracefully.

**Requirements**: Clean API (`Parse_CID`, `Gateway.Fetch`, `UnixFS.Read_File`), Alire crate, comprehensive README with `alr with ada_ipfs` snippet.

## 3. Functional Requirements

### FR-1: Multihash Encode/Decode (P0)

**Description**: Encode raw digest bytes into multihash format; decode multihash bytes into (hash_function_code, digest_length, digest).

**MoTDD Acceptance Criteria**:
- `Multihash.Encode(SHA2_256, Digest_Bytes) → Multihash_Bytes`: Prepends `0x12` (SHA2-256 code), length byte, digest.
- `Multihash.Decode(Multihash_Bytes) → (Hash_Function, Length, Digest)`: Parses header, returns fields.
- Supports SHA2-256 (code `0x12`) as minimum; extensible for SHA2-512, SHA3, BLAKE3.
- Rejects unknown hash codes with `Unsupported_Hash_Function` exception.
- Rejects malformed input (length mismatch) with `Invalid_Multihash` exception.
- **Observable**: Test suite covers 20+ cases (valid SHA2-256, unknown code, truncated bytes, length overflow).

**Priority**: P0

### FR-2: Multibase Encode/Decode (P0)

**Description**: Encode/decode byte arrays using multibase prefixes (`f` = base16, `b` = base32, `z` = base58btc).

**MoTDD Acceptance Criteria**:
- `Multibase.Encode(Base32_Lower, Bytes) → "b<encoded>"`: Prepends `b`, encodes with RFC 4648 base32 lowercase, no padding.
- `Multibase.Decode("z<encoded>") → (Base58_BTC, Bytes)`: Strips prefix, decodes base58-btc alphabet.
- Supports base32-lower (`b`), base58-btc (`z`) as minimum; extensible for base16 (`f`), base64 (`m`).
- Rejects unknown prefix with `Unsupported_Base` exception.
- Rejects invalid alphabet characters with `Invalid_Encoding` exception.
- **Observable**: Round-trip property test (encode → decode = identity) for 100 random byte sequences per base.

**Priority**: P0

### FR-3: CID Parse/Encode/Convert (P0)

**Description**: Parse CID strings into structured CID type; encode CID to string; convert CIDv0 ↔ CIDv1.

**MoTDD Acceptance Criteria**:
- `CID.Parse("Qm...") → CID_V0(Multihash)`: Parses base58-btc CIDv0 (implicit dag-pb, sha2-256).
- `CID.Parse("bafybei...") → CID_V1(Base32_Lower, Multicodec, Multihash)`: Parses multibase CIDv1.
- `CID.To_String(CID_V1) → "bafybei..."`: Encodes CID with configured base.
- `CID.To_V1(CID_V0) → CID_V1`: Upgrades CIDv0 to CIDv1 (multicodec=0x70 dag-pb, base=base32).
- `CID.Parse(String)` completes in **O(len)** time (single-pass, no backtracking).
- Rejects strings with invalid multibase prefix, unknown multicodec, or malformed multihash.
- **Observable**: 30+ test vectors from IPFS spec examples; 10k CID parsing benchmark < 50ms on M1.

**Priority**: P0

### FR-4: CAR v1 Read (P0)

**Description**: Read CAR (Content Addressable aRchive) v1 files: parse header, iterate sections (CID + block data), verify block hashes.

**MoTDD Acceptance Criteria**:
- `CAR.Open(File_Path) → CAR_Reader`: Opens file, parses header (version=1, root CIDs).
- `CAR_Reader.Next_Block → (CID, Bytes)`: Reads next section (varint CID length, CID bytes, varint block length, block bytes).
- `CAR_Reader.Verify_Block(CID, Bytes) → Boolean`: Computes multihash of block, compares to CID's hash; returns True if match.
- Rejects CAR v2 or unknown versions with `Unsupported_CAR_Version` exception.
- Rejects truncated sections with `Malformed_CAR_Section` exception.
- Rejects hash mismatches with `Block_Verification_Failed` exception (includes expected vs actual hash).
- **Observable**: Verify a 1 MB CAR file (10 blocks, SHA2-256) in **< 1 second** on M1 Mac.

**Priority**: P0

### FR-5: dag-pb Decode (P1)

**Description**: Decode dag-pb (Protocol Buffers encoded DAG nodes) into structured Link and Data fields. Minimal implementation sufficient for UnixFS.

**MoTDD Acceptance Criteria**:
- `DAG_PB.Decode(Bytes) → (Links, Data)`: Parses protobuf fields 2 (Links) and 1 (Data).
- `Link` type contains: `Hash` (bytes), `Name` (optional string), `Tsize` (optional uint64).
- Rejects unknown required fields with `Unsupported_DAG_PB_Field` exception.
- Tolerates unknown optional fields (forward compatibility).
- **Observable**: Decodes IPFS kubo-generated dag-pb blocks (verified against go-ipfs output).

**Priority**: P1 (required for FR-6)

### FR-6: UnixFS Read (P0 files, P1 directories)

**Description**: Read UnixFS data structures: single-block files, chunked files (with indirect links), directories (HAMT in P2).

**MoTDD Acceptance Criteria** (Files, P0):
- `UnixFS.Read_File(CAR_Reader, Root_CID) → Bytes`: Reconstructs file from single block or follows dag-pb links to concatenate chunks.
- Supports UnixFS Data types: `File` (0x2), `Raw` (0x5).
- Rejects non-file types (directory, symlink, metadata) with `Not_A_File` exception.
- **Observable**: Read a 5 MB chunked file (256KB chunks) from CAR in < 2 seconds.

**MoTDD Acceptance Criteria** (Directories, P1):
- `UnixFS.List_Directory(CAR_Reader, Root_CID) → Array_Of_Entry`: Returns name + CID for each child.
- Supports UnixFS `Directory` type (0x1).
- HAMT-sharded directories deferred to P2.
- **Observable**: List a flat directory with 100 entries in < 100ms.

**Priority**: P0 (files), P1 (directories)

### FR-7: HTTP Gateway Client (P0)

**Description**: Fetch IPFS content from HTTP gateways. Supports path-style (`/ipfs/<cid>`) and subdomain-style (`<cid>.ipfs.<gateway>`). Trustless mode via `application/vnd.ipld.car` endpoint.

**MoTDD Acceptance Criteria**:
- `Gateway.Fetch(CID, Gateway_URL) → Bytes`: HTTP GET to `https://<gateway>/ipfs/<cid>`, returns body.
- `Gateway.Fetch_CAR(CID, Gateway_URL) → CAR_Bytes`: Requests `Accept: application/vnd.ipld.car`, returns CAR archive.
- Verifies CAR blocks: computes multihash for each block, rejects mismatches with `Block_Verification_Failed`.
- Follows HTTP redirects (3xx) up to 5 hops; rejects beyond with `Too_Many_Redirects`.
- Configurable timeout (default 30s); raises `Gateway_Timeout` on exceeded.
- Subdomain mode: constructs `https://<base32_cid>.ipfs.dweb.link/`.
- **Observable**: Fetch a verified 1 MB file via `dweb.link` in < 5 seconds on 10 Mbps connection.

**Priority**: P0

### FR-8: CLI Tool `ipfs-get` (P0)

**Description**: Command-line utility to fetch CID to file.

**MoTDD Acceptance Criteria**:
- `ipfs-get <cid>` → writes to `<cid>` in current directory.
- `ipfs-get <cid> -o <path>` → writes to specified path.
- `ipfs-get <cid> --gateway <url>` → uses custom gateway (default: `https://dweb.link`).
- `ipfs-get <cid> --timeout <seconds>` → sets HTTP timeout.
- Exit codes: `0` success, `1` network error, `2` verification failed, `3` invalid CID.
- Prints progress to stderr: `Fetching <cid>... <bytes> received... Verifying... Done.`
- **Observable**: `ipfs-get bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi` completes on fresh install (no config).

**Priority**: P0

### FR-9: Typed Error Handling (P0)

**Description**: Layered exceptions for precise error diagnosis.

**MoTDD Acceptance Criteria**:
- Codec layer: `Invalid_Multihash`, `Unsupported_Hash_Function`, `Invalid_Encoding`, `Unsupported_Base`, `Invalid_CID`.
- CAR layer: `Unsupported_CAR_Version`, `Malformed_CAR_Section`, `Block_Verification_Failed` (includes CID + expected/actual hash).
- Gateway layer: `Gateway_Timeout`, `Gateway_Error` (includes HTTP status), `Too_Many_Redirects`.
- UnixFS layer: `Not_A_File`, `Unsupported_UnixFS_Type`, `Incomplete_DAG` (missing linked block).
- Each exception includes human-readable message + structured fields for programmatic handling.
- **Observable**: Test suite verifies exception types for 40+ error scenarios.

**Priority**: P0

## 4. Non-Functional Requirements

### NFR-1: Portability (P0)

**Description**: Build and run on GNAT FSF ≥ 14.0 across macOS arm64, Linux x86_64, Linux aarch64.

**MoTDD Acceptance Criteria**:
- CI matrix: `macos-14` (arm64), `ubuntu-22.04` (x86_64), `ubuntu-24.04` (x86_64, aarch64 via QEMU).
- Uses only Ada 2012 features (no GNAT-specific extensions in public API).
- Dependencies: Alire crates only (no system libs via `-largs`).
- **Observable**: All CI jobs green on every commit to `main`.

**Priority**: P0

### NFR-2: Zero Runtime Allocation (Configurable) (P1)

**Description**: Core verification paths (multihash, CID parsing, block hashing) support stack-only execution with pre-allocated buffers. No implicit heap allocation (`pragma Restrictions(No_Implicit_Heap_Allocations)` compliant).

**MoTDD Acceptance Criteria**:
- Package `Ada_IPFS.Zero_Alloc` provides stack-only API variants: `Parse_CID_Stack`, `Verify_Block_Stack`.
- Caller provides `Storage : in out Byte_Array` buffer; functions raise `Buffer_Too_Small` if insufficient.
- Tested under `pragma Restrictions(No_Implicit_Heap_Allocations)` in separate test executable.
- **Observable**: Example program `examples/verify_car_stack_only.adb` compiles and runs without heap.

**Priority**: P1

### NFR-3: SPARK Annotations (P1)

**Description**: Core codec packages (Multihash, Multibase, CID) annotated with SPARK contracts (preconditions, postconditions, `Global`, `Depends`).

**MoTDD Acceptance Criteria**:
- `spark/` directory contains `.ads` stubs for SPARK-compatible subset.
- Contracts specify: buffer bounds, absence of aliasing, exception conditions.
- SPARK GPL 2024+ analysis completes with no warnings on annotated units.
- **Observable**: `gnatprove -P ada_ipfs_spark.gpr --level=1` exits 0.

**Priority**: P1

### NFR-4: Code Style & Warnings (P0)

**Description**: Clean compilation under strict warnings; consistent Ada 2012 style.

**MoTDD Acceptance Criteria**:
- Compiler flags: `-gnatwa` (all warnings), `-gnatwe` (warnings as errors), `-gnatyabcdefhiklmnoprstux` (style checks).
- Zero warnings on `gprbuild -P ada_ipfs.gpr`.
- Identifiers: `Mixed_Case` for types/procedures, `ALL_CAPS` for constants, `Lower_Case` for packages.
- **Observable**: CI build job fails on first warning.

**Priority**: P0

### NFR-5: Test Coverage (P0)

**Description**: Statement coverage ≥ 80% for P0 modules (Multihash, Multibase, CID, CAR, Gateway).

**MoTDD Acceptance Criteria**:
- Coverage measured via `gnatcov` (GNAT Coverage).
- P0 packages: each ≥ 80% statement coverage.
- P1/P2 packages: ≥ 60% coverage.
- **Observable**: `gnatcov coverage --level=stmt+decision --annotate=html` generates report; CI checks thresholds.

**Priority**: P0

### NFR-6: Documentation (P0)

**Description**: Complete user documentation and architectural overview.

**MoTDD Acceptance Criteria**:
- `README.md`: Quickstart (`alr with ada_ipfs`), 5-line code example, link to full docs.
- `docs/architecture.md`: Package structure, layer responsibilities, data flow diagram.
- `examples/`: One example per feature (`parse_cid.adb`, `fetch_gateway.adb`, `verify_car.adb`, `read_unixfs_file.adb`).
- Each example: < 50 lines, runs standalone (`alr run <example>`), prints result to stdout.
- API docs: Every public subprogram has GNAT-style comment with `@param`, `@return`, `@raises`.
- **Observable**: Fresh user clones repo, runs `alr build`, `alr run fetch_gateway`, sees output in < 5 minutes.

**Priority**: P0

### NFR-7: Continuous Integration (P0)

**Description**: Automated build, test, coverage on every push.

**MoTDD Acceptance Criteria**:
- GitHub Actions workflow: `.github/workflows/ci.yml`.
- Jobs: `build` (matrix: 3 platforms), `test` (runs test suite, uploads coverage), `lint` (checks warnings).
- Runs on: push to `main`, pull requests.
- Status badge in `README.md`.
- **Observable**: Badge shows "passing" on `main`; PRs blocked if red.

**Priority**: P0

### NFR-8: Reproducible Builds (P1)

**Description**: Identical binaries from identical source on same platform.

**MoTDD Acceptance Criteria**:
- No timestamps in output (use `SOURCE_DATE_EPOCH`).
- Fixed compiler flags in `.gpr` (no `$ADAFLAGS` from environment).
- **Observable**: `sha256sum bin/ipfs-get` matches between two fresh clones on same commit + platform.

**Priority**: P1

### NFR-9: Security Hardening (P0)

**Description**: Robust against malformed/malicious input; no unsafe operations.

**MoTDD Acceptance Criteria**:
- No `Unchecked_Conversion` without safety comment.
- No `System.Address` arithmetic.
- Bounded parsing: All varint/length decoders reject > 10 bytes, > 2^31-1 values.
- Fuzz-ready: All `Parse_*`/`Decode_*` functions tested with 1000+ random inputs (property-based testing via `AUnit` or external fuzzer).
- No external command execution (`Ada.Directories` only for file I/O, no `Process.Run`).
- **Observable**: 6-hour fuzzing run (`cargo fuzz` via Ada FFI or `examples/fuzz_cid.adb` + random data) finds zero crashes/exceptions.

**Priority**: P0

### NFR-10: License & Versioning (P0)

**Description**: MIT license, semantic versioning, CHANGELOG.

**MoTDD Acceptance Criteria**:
- `LICENSE` file: MIT with kokhlo copyright.
- `CHANGELOG.md`: Follows [Keep a Changelog](https://keepachangelog.com/) format.
- `alire.toml`: `version` field matches git tag (`v0.1.0`, `v0.2.0`).
- Git tags: Annotated (`git tag -a v0.1.0 -m "Release 0.1.0"`).
- **Observable**: `alr show ada_ipfs` displays version; `git tag --list` shows semantic tags.

**Priority**: P0

## 5. Risks & Mitigations

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| **R-1**: Ada crypto library gaps (no SHA2-256 in Alire index) | High | Medium | Vendor minimal Ada SHA-256 implementation (300 LOC, test against NIST vectors). Upstream to Alire as separate crate (`ada_sha2`) by M2. |
| **R-2**: HTTP client missing in Alire (AWS deprecated, GNAT.Sockets low-level) | High | Medium | Phase 1: Shell out to `curl` (portable, verifiable output). Phase 2: Evaluate `ada_http` crate or vendor minimal HTTP/1.1 GET client (500 LOC). |
| **R-3**: Gateway censorship/rate-limits | Medium | High | Support multiple gateway fallback (`--gateway-list`). Document self-hosted gateway setup. Rate-limit handling (429 → exponential backoff). |
| **R-4**: CAR v2 adoption breaks tooling | Medium | Low | Monitor IPFS specs. CAR v2 is optional index (v1 is mandatory subset). Reject v2 with clear error until implemented. |
| **R-5**: SPARK proof burden slows development | Low | Medium | SPARK annotations are P1 (not release blocker). Start with contracts only (no proof), add proofs incrementally. |
| **R-6**: Adoption blocked by missing Alire index merge | High | Low | Follow alire-project/alire-index PR best practices (mosteo review patterns). Prepare full test matrix, examples, docs before submission. Early draft PR for feedback (week before M4). |
| **R-7**: Rust/Go IPFS clients dominate, no Ada demand | Medium | Medium | Position as embedded/SPARK niche (Rust's unsafe, Go's GC unsuitable for hard-RT). Target Ada community first (Ada Forum, Alire), then cross-post to IPFS forums. |

## 6. Milestones

### M0: Repository Skeleton (Week 1)

**Deliverables**:
- `alire.toml`, `.gpr` files with empty package structure.
- CI workflow stub (builds empty project).
- `README.md`, `CONTRIBUTING.md`, `LICENSE`.
- Example program stubs (compile but print "TODO").

**Success Criteria**: `alr build` succeeds; CI green; `alr show ada_ipfs` displays metadata.

### M1: Core Codecs (Weeks 2-4)

**Deliverables**:
- FR-1 (Multihash), FR-2 (Multibase), FR-3 (CID) fully implemented.
- SHA-256 vendored/wrapped (via `ada_sha2` crate or local implementation).
- 100+ unit tests (AUnit framework).
- `examples/parse_cid.adb` works end-to-end.

**Success Criteria**: Parse 10,000 CIDs in < 50ms; all tests pass on 3 platforms.

### M2: CAR & UnixFS (Weeks 5-7)

**Deliverables**:
- FR-4 (CAR v1 read), FR-5 (dag-pb), FR-6 (UnixFS files) implemented.
- `examples/verify_car.adb`, `examples/read_unixfs_file.adb` working.
- Property-based tests (1000+ random CAR files).

**Success Criteria**: Verify 1 MB CAR file in < 1 second; reconstruct 5 MB chunked file.

### M3: Gateway Client & CLI (Weeks 8-10)

**Deliverables**:
- FR-7 (Gateway client), FR-8 (`ipfs-get` CLI) implemented.
- HTTP client integrated (`curl` shim or native Ada HTTP).
- End-to-end smoke test: `ipfs-get <known_cid>` against live gateway.

**Success Criteria**: Fetch+verify 10 MB file via `dweb.link` in < 30 seconds; CLI help text complete.

### M4: Release & Announce (Weeks 11-12)

**Deliverables**:
- All P0 requirements met; P1 at 80%+ completion.
- Documentation complete (`docs/`, `README.md`, API comments).
- Alire index PR submitted (`alire-project/alire-index`).
- Announcement posts: Ada Forum, IPFS forums, HN Show HN (after index merge).
- `CHANGELOG.md` for v0.1.0.

**Success Criteria**: Alire PR merged; ≥ 3 community upvotes/comments; zero P0 bugs in issue tracker.

---

**Version**: 1.0  
**Last Updated**: 2026-09-07  
**Maintainer**: kokhlo
