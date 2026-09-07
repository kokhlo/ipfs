pragma SPARK_Mode;

with Ada.Streams;

package IPFS.SHA256 is

   --  SHA-256 hash length in bytes
   Digest_Length : constant := 32;

   --  Hashing context for incremental updates
   type Context is private;

   --  Initialize a new hashing context
   function Initial return Context;

   --  Update context with additional data
   procedure Update
     (Ctx  : in out Context;
      Data : Ada.Streams.Stream_Element_Array);

   --  Finalize and return digest
   function Finish (Ctx : Context) return Ada.Streams.Stream_Element_Array
     with Post => Finish'Result'Length = Digest_Length;

   --  One-shot hash computation
   function Digest (Data : Ada.Streams.Stream_Element_Array)
     return Ada.Streams.Stream_Element_Array
     with Post => Digest'Result'Length = Digest_Length;

private

   type Word is mod 2**32;
   type State_Array is array (0 .. 7) of Word;
   type Block_Array is array (0 .. 63) of Ada.Streams.Stream_Element;

   type Context is record
      State       : State_Array;
      Buffer      : Block_Array;
      Buffer_Len  : Natural;
      Total_Bytes : Long_Long_Integer;
   end record;

end IPFS.SHA256;
