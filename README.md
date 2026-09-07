# ada-ipfs

**Native IPFS client library for Ada.** Parse CIDs, read CAR archives, and fetch content
from IPFS HTTP gateways with cryptographic verification — no daemon, no libp2p, no trust
in the gateway.

## Why

The Alire index (800+ crates) had zero IPFS libraries. ada-ipfs fills that gap: an
Ada-native, verifiable, dependency-free client for reading IPFS content.

**Trustless by design:** every block fetched through a gateway is hashed (SHA2-256) and
checked against the CID before your code ever sees it. A malicious or broken gateway
cannot make you accept wrong bytes.

## Features (v0.1)

- ✅ **CID** v0 (`Qm…`) and v1 (`bafy…`): parse, encode, base conversion (base32, base58btc)
- ✅ **Multihash**: sha2-256 + identity, encode/decode/verify
- ✅ **Multibase**: base32 (RFC 4648, no padding) + base58btc
- ✅ **SHA2-256** (FIPS 180-4), pure Ada, zero dependencies
- ✅ **CAR v1** reader with per-block hash verification
- ✅ **dag-pb** reader (protobuf subset for IPFS nodes)
- ✅ **UnixFS** file extraction: single-block and chunked files; directories
- ✅ **Gateway client**: HTTP fetch (`format=raw`, `format=car`), timeouts, redirects
- ✅ CLI example: `fetch_cid <cid>` — fetch, verify, write file

## Install

Requires GNAT 2021+ (Ada 2022) and gprbuild. With [Alire](https://alire.ada.dev):

```bash
alr with ipfs
```

Or build directly:

```bash
gprbuild -p -P ipfs.gpr
```

## Usage

Parse a CID and check it:

```ada
with IPFS.CID;

declare
   C : constant IPFS.CID.CID_Type :=
     IPFS.CID.Parse ("bafkreiexwmlay7yehnir7u554rrpgtxtc4lnlxxggwhpvdemykfsmw2xqi");
begin
   --  C is verified structurally (version, codec, multihash shape)
   Ada.Text_IO.Put_Line (IPFS.CID.To_String (C));  --  round-trips exactly
end;
```

Fetch from a local kubo gateway and verify:

```ada
with IPFS.Gateway;
with IPFS.Multihash;

declare
   Config : constant IPFS.Gateway.Gateway_Config :=
     IPFS.Gateway.Local_Kubo;  --  http://127.0.0.1:8080
   Data : constant Ada.Streams.Stream_Element_Array :=
     IPFS.Gateway.Fetch_Raw_Block (Config, "bafkrei…");
begin
   if IPFS.Multihash.Verify (Data, Expected_Multihash) then
      --  bytes are provably the content the CID addresses
      null;
   end if;
end;
```

CLI:

```bash
./bin/fetch_cid bafkreiexwmlay7yehnir7u554rrpgtxtc4lnlxxggwhpvdemykfsmw2xqi
./bin/fetch_cid QmarWQsVmm85BgiJxB3GkgegSzJuqyEXAhAWPxQUmWvEGQ
```

## Architecture

```
IPFS.CID ── IPFS.Multihash ── IPFS.SHA256
    │
IPFS.Multibase (base32 / base58btc)
    │
IPFS.DagPB ── IPFS.UnixFS      (readers)
    │
IPFS.CAR (v1 reader + verify) ── test/fixtures/*.car (kubo 0.43)
    │
IPFS.Gateway (HTTP client) ── GNAT.Sockets
```

All codecs are pure Ada with `pragma SPARK_Mode`, fixed-size buffers (no heap in the
verification path), and typed exceptions per layer (`Malformed_CID`,
`Malformed_CAR`, `Gateway_Error`, …).

## Testing

125+ assertions across the codec suites, driven by real kubo-generated fixtures
(see `test/fixtures/MANIFEST.txt`). Run:

```bash
gprbuild -p -P ipfs_tests.gpr
./bin/ipfs_tests_runner
```

End-to-end (requires `ipfs daemon` on 127.0.0.1:8080): `examples/fetch_cid`.

## Status

v0.1 — see [REQUIREMENTS.md](REQUIREMENTS.md) for scope, [docs/research/SOTA_REPORT.md](docs/research/SOTA_REPORT.md)
for the ecosystem survey. Non-goals for v0.1: bitswap, DHT, pubsub, TLS gateways,
content creation (add/pin).

## License

MIT © 2026 Konstantin Khlopkov
