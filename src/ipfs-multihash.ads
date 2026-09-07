--  Multihash (multiformats) codec and verification.
--  Encodes hash function output as varint(code) + varint(length) + digest.
pragma SPARK_Mode;

with Ada.Streams;
with Interfaces;

package IPFS.Multihash is

   use type Ada.Streams.Stream_Element_Offset;

   --  Multihash codes from the multicodec table.
   Sha2_256_Code : constant Interfaces.Unsigned_64 := 16#12#;
   Identity_Code : constant Interfaces.Unsigned_64 := 16#00#;

   --  Maximum digest length supported.
   Max_Digest_Length : constant := 128;

   --  Opaque multihash container.
   type Hash_Type is private;

   Malformed_Multihash : exception;

   --  Encode a digest with the given hash function code.
   --  Returns varint(code) + varint(length) + digest bytes.
   --  Raises Constraint_Error if code or length exceed encoding limits.
   function Encode
     (Code   : Interfaces.Unsigned_64;
      Digest : Ada.Streams.Stream_Element_Array)
      return Ada.Streams.Stream_Element_Array
     with Pre => Digest'Length <= Max_Digest_Length;

   --  Decode multihash bytes into a Hash_Type.
   --  Raises Malformed_Multihash on invalid structure.
   function Decode
     (Bytes : Ada.Streams.Stream_Element_Array)
      return Hash_Type;

   --  Extract hash function code from a decoded multihash.
   function Code (H : Hash_Type) return Interfaces.Unsigned_64;

   --  Extract digest bytes from a decoded multihash.
   function Digest_Of (H : Hash_Type) return Ada.Streams.Stream_Element_Array;

   --  Compute SHA2-256 multihash of data.
   --  Returns complete multihash: 0x12 0x20 <32 digest bytes>.
   function Sha2_256
     (Data : Ada.Streams.Stream_Element_Array)
      return Ada.Streams.Stream_Element_Array;

   --  Verify data against a multihash.
   --  Returns True if:
   --    - code = sha2-256: recomputes sha256(data) and compares digest
   --    - code = identity: data equals hash bytes
   --  Returns False for unsupported codes.
   function Verify
     (Data       : Ada.Streams.Stream_Element_Array;
      Hash_Bytes : Ada.Streams.Stream_Element_Array)
      return Boolean;

private

   type Digest_Array is array (1 .. Max_Digest_Length) of Ada.Streams.Stream_Element;

   type Hash_Type is record
      Hash_Code     : Interfaces.Unsigned_64;
      Digest_Length : Natural range 0 .. Max_Digest_Length;
      Digest_Data   : Digest_Array;
   end record;

end IPFS.Multihash;
