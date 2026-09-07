--  DAG-PB (Data-Aware Generalized Merkle DAG) codec for IPFS.
--  Protobuf-based format: field 1 = Data (bytes), field 2 = Links (repeated).
--  Link message: field 1 = Hash (bytes), field 2 = Name (bytes), field 3 = Tsize (varint).

pragma SPARK_Mode;

with Ada.Streams;
with Interfaces;

package IPFS.DagPB is

   use type Ada.Streams.Stream_Element_Offset;

   Max_Links       : constant := 256;
   Max_Name_Length : constant := 255;
   Max_Data_Length : constant := 1024;

   Malformed_DagPB : exception;

   type Link_Type is record
      Name      : String (1 .. Max_Name_Length);
      Name_Len  : Natural;
      Hash      : Ada.Streams.Stream_Element_Array (1 .. 128);
      Hash_Len  : Natural;
      Tsize     : Interfaces.Unsigned_64;
   end record;

   type Link_Array is array (1 .. Max_Links) of Link_Type;

   type Node_Type is record
      Links       : Link_Array;
      Links_Count : Natural;
      Data        : Ada.Streams.Stream_Element_Array (1 .. Max_Data_Length);
      Data_Len    : Natural;
   end record;

   --  Decode dag-pb protobuf bytes into Node_Type.
   --  Protobuf wire format: field tag (varint) + value.
   --  Field 1 = Data (wire type 2, length-delimited bytes).
   --  Field 2 = Links (wire type 2, repeated messages).
   --  Unknown fields with wire types 0/1/2/5 are skipped.
   function Decode
     (Bytes : Ada.Streams.Stream_Element_Array)
      return Node_Type;

end IPFS.DagPB;
