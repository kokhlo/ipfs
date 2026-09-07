--  CAR (Content Addressable aRchive) v1 reader with integrity verification.
--  Reads CARv1 files (header + blocks), verifies block hashes against CIDs.
pragma SPARK_Mode;

with Ada.Streams;

package IPFS.CAR is

   use type Ada.Streams.Stream_Element_Offset;

   Malformed_CAR : exception;

   --  Read and parse CAR header, returning the root CID bytes.
   --  Decodes: varint(header_len) + CBOR header {version:1, roots:[cid]}.
   function Read_Header
     (Bytes : Ada.Streams.Stream_Element_Array)
      return Ada.Streams.Stream_Element_Array;

   --  Iterate over all blocks in the CAR archive.
   --  For each block (varint section_len + CID bytes + data), calls Process(cid, data).
   procedure Iterate
     (Bytes   : Ada.Streams.Stream_Element_Array;
      Process : access procedure
        (Cid_Bytes : Ada.Streams.Stream_Element_Array;
         Data      : Ada.Streams.Stream_Element_Array));

   --  Verify the integrity of a CAR archive in memory.
   --  Checks: (1) first block CID matches header root, (2) every block's data hashes to its CID.
   function Verify
     (Bytes : Ada.Streams.Stream_Element_Array)
      return Boolean;

   --  Verify the integrity of a CAR file on disk.
   --  Reads the file incrementally (chunks up to 262144 bytes) to support large archives.
   function Verify_File (Path : String) return Boolean;

end IPFS.CAR;
