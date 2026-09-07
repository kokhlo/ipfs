# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2026-09-07

### Added

- `IPFS.Varint`: unsigned varint codec (multiformats spec)
- `IPFS.SHA256`: FIPS 180-4 SHA2-256, pure Ada (incremental + one-shot)
- `IPFS.Multibase`: base32 (RFC 4648, unpadded) + base58btc encodings
- `IPFS.Multihash`: sha2-256/identity codes, encode/decode/verify
- `IPFS.CID`: CIDv0/CIDv1 parse, encode, v0↔v1 conversion, equality
- `IPFS.DagPB`: dag-pb node reader (protobuf subset)
- `IPFS.UnixFS`: UnixFS data reader, file extraction (single-block + chunked), directory links
- `IPFS.CAR`: CARv1 reader with per-block hash verification
- `IPFS.Gateway`: HTTP gateway client (raw-block + CAR fetch, timeouts, redirects)
- `fetch_cid` CLI example
- Test suite: 125+ assertions against kubo-0.43-generated fixtures
- CI: GitHub Actions matrix (ubuntu-22.04/24.04, macos-14/15)

[0.1.0]: https://github.com/kokhlo/ipfs/releases/tag/v0.1.0
