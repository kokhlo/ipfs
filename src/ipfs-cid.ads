--  Content Identifier (CID) implementation.
--  Supports CIDv0 (base58btc, dag-pb codec) and CIDv1 (multibase-prefixed).
pragma SPARK_Mode;

with Ada.Streams;
with Interfaces;
with IPFS.Multibase;
with IPFS.Multihash;

package IPFS.CID is

   use type Interfaces.Unsigned_64;

   Raw_Code    : constant Interfaces.Unsigned_64 := 16#55#;
   Dag_Pb_Code : constant Interfaces.Unsigned_64 := 16#70#;

   type CID_Type is private;

   Malformed_CID : exception;

   --  Parse CID from text representation.
   --  Supports CIDv0 (46-char base58btc starting with 'Qm') and CIDv1 (multibase-prefixed).
   function Parse (Text : String) return CID_Type;

   --  Convert CID to string representation with specified base.
   function To_String
     (C    : CID_Type;
      Base : IPFS.Multibase.Base_Type := IPFS.Multibase.Base_32_Lower)
      return String;

   --  Convert to CIDv1. CIDv0 becomes CIDv1 with dag-pb codec.
   function To_V1 (C : CID_Type) return CID_Type;

   --  Convert to CIDv0. Only valid if codec is dag-pb and hash is sha2-256.
   function To_V0 (C : CID_Type) return CID_Type;

   --  Return CID version (0 or 1).
   function Version (C : CID_Type) return Natural;

   --  Return codec code.
   function Codec (C : CID_Type) return Interfaces.Unsigned_64;

   --  Extract multihash from CID.
   function Multihash_Of (C : CID_Type) return IPFS.Multihash.Hash_Type;

   --  Construct CID from components.
   function From_Multihash
     (V     : Natural;
      Codec : Interfaces.Unsigned_64;
      H     : IPFS.Multihash.Hash_Type)
      return CID_Type;

   --  Serialize CID to binary bytes.
   function To_Bytes (C : CID_Type) return Ada.Streams.Stream_Element_Array;

   --  Deserialize CID from binary bytes.
   function From_Bytes
     (Bytes : Ada.Streams.Stream_Element_Array)
      return CID_Type;

   --  Test CID equality.
   function Equals (L, R : CID_Type) return Boolean;

   function "=" (L, R : CID_Type) return Boolean renames Equals;

private

   type CID_Type is record
      CID_Version    : Natural range 0 .. 1;
      CID_Codec      : Interfaces.Unsigned_64;
      Binary_Data    : Ada.Streams.Stream_Element_Array (1 .. 128);
      Binary_Length  : Ada.Streams.Stream_Element_Offset range 0 .. 128;
   end record;

end IPFS.CID;
