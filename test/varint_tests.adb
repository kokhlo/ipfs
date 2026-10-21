--  Varint test suite (multiformats unsigned-varint).
pragma Ada_2022;

with Ada.Text_IO;
with Ada.Streams;
with Interfaces;
with IPFS.Varint;

package body Varint_Tests is

   use Ada.Text_IO;

   use type Ada.Streams.Stream_Element_Offset;
   use type Interfaces.Unsigned_64;

   Tests_Run    : Natural := 0;
   Tests_Passed : Natural := 0;

   procedure Assert (Condition : Boolean; Name : String) is
   begin
      Tests_Run := Tests_Run + 1;
      if Condition then
         Tests_Passed := Tests_Passed + 1;
      else
         Put_Line ("FAIL: " & Name);
      end if;
   end Assert;

   procedure Test_Encode_Decode_Roundtrip is
      Values : constant array (1 .. 6) of Interfaces.Unsigned_64 :=
        [0, 1, 127, 128, 300, 2 ** 63 - 1];
   begin
      for V of Values loop
         declare
            Buf   : Ada.Streams.Stream_Element_Array (1 .. 10) :=
              [others => 0];
            Last  : Ada.Streams.Stream_Element_Offset;
            Dec   : Interfaces.Unsigned_64;
            DLast : Ada.Streams.Stream_Element_Offset;
         begin
            IPFS.Varint.Encode (V, Buf, 1, Last);
            IPFS.Varint.Decode (Buf (1 .. Last), 1, Dec, DLast);
            Assert (Dec = V and then DLast = Last,
                    "roundtrip" & Interfaces.Unsigned_64'Image (V));
         end;
      end loop;
   end Test_Encode_Decode_Roundtrip;

   procedure Test_Encoded_Length is
   begin
      Assert (IPFS.Varint.Encoded_Length (0) = 1, "length of 0 is 1");
      Assert (IPFS.Varint.Encoded_Length (127) = 1, "length of 127 is 1");
      Assert (IPFS.Varint.Encoded_Length (128) = 2, "length of 128 is 2");
      Assert (IPFS.Varint.Encoded_Length (300) = 2, "length of 300 is 2");
      Assert (IPFS.Varint.Encoded_Length (16#3FFF#) = 2,
              "length of 16#3FFF# is 2");
      Assert (IPFS.Varint.Encoded_Length (2 ** 63 - 1) = 9,
              "length of 2**63-1 is 9");
   end Test_Encoded_Length;

   procedure Test_U64_Max_Ten_Byte_Form is
      --  The canonical LEB128 encoding of 2**64-1 is 10 bytes
      --  (FF FF FF FF FF FF FF FF FF 01): bit 63 is the only payload bit
      --  of the final byte, which is legal per multiformats spec.
      Buf : constant Ada.Streams.Stream_Element_Array (1 .. 10) :=
        [16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#,
         16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#01#];
      V    : Interfaces.Unsigned_64;
      Last : Ada.Streams.Stream_Element_Offset;
   begin
      IPFS.Varint.Decode (Buf, 1, V, Last);
      Assert (V = Interfaces.Unsigned_64'Last and then Last = 10,
              "decode 10-byte u64-max form");
   exception
      when IPFS.Varint.Malformed_Varint =>
         Assert (False, "10-byte u64-max form must decode, not raise");
   end Test_U64_Max_Ten_Byte_Form;

   procedure Test_Reject_Overflow_Above_U64 is
      --  10-byte varint whose final byte carries bits above bit 63
      --  (0xFF payload): value exceeds 2**64-1 and must be rejected.
      Buf : constant Ada.Streams.Stream_Element_Array (1 .. 10) :=
        [16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#,
         16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#7F#];
      V    : Interfaces.Unsigned_64;
      Last : Ada.Streams.Stream_Element_Offset;
   begin
      IPFS.Varint.Decode (Buf, 1, V, Last);
      Assert (False, "overflow varint must raise Malformed_Varint");
   exception
      when IPFS.Varint.Malformed_Varint =>
         Assert (True, "rejects varint above 2**64-1");
   end Test_Reject_Overflow_Above_U64;

   procedure Test_Reject_Overlong_Eleven_Bytes is
      --  Even the lowest 11-byte form exceeds u64: continuation forever.
      Buf : constant Ada.Streams.Stream_Element_Array (1 .. 11) :=
        [16#80#, 16#80#, 16#80#, 16#80#, 16#80#, 16#80#,
         16#80#, 16#80#, 16#80#, 16#80#, 16#00#];
      V    : Interfaces.Unsigned_64;
      Last : Ada.Streams.Stream_Element_Offset;
   begin
      IPFS.Varint.Decode (Buf, 1, V, Last);
      Assert (False, "11-byte varint must raise Malformed_Varint");
   exception
      when IPFS.Varint.Malformed_Varint =>
         Assert (True, "rejects overlong 11-byte varint");
   end Test_Reject_Overlong_Eleven_Bytes;

   procedure Test_Reject_Truncated is
      --  Continuation bit set on the final byte: no terminal byte.
      Buf : constant Ada.Streams.Stream_Element_Array (1 .. 2) :=
        [16#80#, 16#80#];
      V    : Interfaces.Unsigned_64;
      Last : Ada.Streams.Stream_Element_Offset;
   begin
      IPFS.Varint.Decode (Buf, 1, V, Last);
      Assert (False, "truncated varint must raise Malformed_Varint");
   exception
      when IPFS.Varint.Malformed_Varint =>
         Assert (True, "rejects truncated varint");
   end Test_Reject_Truncated;

   procedure Run is
   begin
      Tests_Run := 0;
      Tests_Passed := 0;

      Test_Encode_Decode_Roundtrip;
      Test_Encoded_Length;
      Test_U64_Max_Ten_Byte_Form;
      Test_Reject_Overflow_Above_U64;
      Test_Reject_Overlong_Eleven_Bytes;
      Test_Reject_Truncated;

      Put_Line ("Varint tests:" & Tests_Run'Image & " run," &
                Tests_Passed'Image & " passed");
   end Run;

end Varint_Tests;
