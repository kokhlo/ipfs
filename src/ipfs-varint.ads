--  Unsigned varint codec (multiformats/unsigned-varint spec).
--  Little-endian base-128 encoding, at most 9 bytes for 64-bit values.
pragma SPARK_Mode;

with Ada.Streams;
with Interfaces;

package IPFS.Varint is

   use type Ada.Streams.Stream_Element_Offset;

   Max_Length : constant := 9;

   Malformed_Varint : exception;

   --  Encode Value as unsigned varint into Buffer starting at Offset.
   --  Last is the index of the final written byte.
   procedure Encode
     (Value  :     Interfaces.Unsigned_64;
      Buffer : in out Ada.Streams.Stream_Element_Array;
      Offset :     Ada.Streams.Stream_Element_Offset := 1;
      Last   :    out Ada.Streams.Stream_Element_Offset)
     with Pre => Offset >= Buffer'First
                and then Offset - 1 + Max_Length <= Buffer'Last,
          Post => Last >= Offset and then Last <= Offset - 1 + Max_Length;

   --  Number of bytes Value occupies when varint-encoded.
   function Encoded_Length (Value : Interfaces.Unsigned_64) return Positive
     with Post => Encoded_Length'Result in 1 .. Max_Length;

   --  Decode a varint from Buffer starting at Offset.
   --  Last is the index of the final byte consumed.
   procedure Decode
     (Buffer :     Ada.Streams.Stream_Element_Array;
      Offset :     Ada.Streams.Stream_Element_Offset;
      Value  :    out Interfaces.Unsigned_64;
      Last   :    out Ada.Streams.Stream_Element_Offset)
     with Pre => Offset >= Buffer'First and then Offset <= Buffer'Last,
          Post => Last >= Offset and then Last <= Buffer'Last;

   --  Convenience: decode a complete buffer holding exactly one varint.
   function Decode_One
     (Buffer : Ada.Streams.Stream_Element_Array)
      return Interfaces.Unsigned_64
     with Pre => Buffer'Length in 1 .. Max_Length;

private

   Continuation_Bit : constant Interfaces.Unsigned_8 := 16#80#;
   Payload_Mask     : constant Interfaces.Unsigned_8 := 16#7F#;
end IPFS.Varint;
