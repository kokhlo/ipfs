pragma Ada_2022;

with Ada.Text_IO;
with Ada.Exceptions;
with Ada.Streams;
with IPFS.Multibase;

package body Multibase_Tests is

   use Ada.Text_IO;
   use IPFS.Multibase;

   Total_Tests  : Natural := 0;
   Passed_Tests : Natural := 0;

   procedure Test
     (Name    : String;
      Passed  : Boolean;
      Message : String := "");

   function Hex_To_Bytes (Hex : String) return Ada.Streams.Stream_Element_Array;
   function Bytes_To_Hex (Bytes : Ada.Streams.Stream_Element_Array) return String;

   ----------
   -- Test --
   ----------

   procedure Test
     (Name    : String;
      Passed  : Boolean;
      Message : String := "")
   is
   begin
      Total_Tests := Total_Tests + 1;
      if Passed then
         Passed_Tests := Passed_Tests + 1;
         Put_Line ("  [PASS] " & Name);
      else
         Put_Line ("  [FAIL] " & Name);
         if Message /= "" then
            Put_Line ("         " & Message);
         end if;
      end if;
   end Test;

   ------------------
   -- Hex_To_Bytes --
   ------------------

   function Hex_To_Bytes (Hex : String) return Ada.Streams.Stream_Element_Array is
      use Ada.Streams;
      Result : Stream_Element_Array (1 .. Hex'Length / 2);
      Idx    : Stream_Element_Offset := Result'First;
      Value  : Natural;
   begin
      if Hex'Length = 0 then
         return [1 .. 0 => 0];
      end if;

      for I in 0 .. (Hex'Length / 2) - 1 loop
         Value := 0;
         for J in 0 .. 1 loop
            declare
               C   : constant Character := Hex (Hex'First + I * 2 + J);
               Val : Natural;
            begin
               if C in '0' .. '9' then
                  Val := Character'Pos (C) - Character'Pos ('0');
               elsif C in 'a' .. 'f' then
                  Val := Character'Pos (C) - Character'Pos ('a') + 10;
               elsif C in 'A' .. 'F' then
                  Val := Character'Pos (C) - Character'Pos ('A') + 10;
               else
                  raise Constraint_Error with "Invalid hex character";
               end if;
               Value := Value * 16 + Val;
            end;
         end loop;
         Result (Idx) := Stream_Element (Value);
         Idx := Idx + 1;
      end loop;

      return Result;
   end Hex_To_Bytes;

   ------------------
   -- Bytes_To_Hex --
   ------------------

   function Bytes_To_Hex (Bytes : Ada.Streams.Stream_Element_Array) return String is
      Hex_Chars : constant String := "0123456789abcdef";
      Result    : String (1 .. Bytes'Length * 2);
      Idx       : Positive := 1;
   begin
      for Byte of Bytes loop
         Result (Idx) := Hex_Chars (Natural (Byte) / 16 + 1);
         Result (Idx + 1) := Hex_Chars (Natural (Byte) mod 16 + 1);
         Idx := Idx + 2;
      end loop;
      return Result;
   end Bytes_To_Hex;

   ---------
   -- Run --
   ---------

   procedure Run is
   begin
      Put_Line ("Running Multibase tests...");
      New_Line;

      --  Test all vectors: encode/decode round-trip
      Put_Line ("Encode/Decode round-trip tests:");
      for Vector of Test_Vectors loop
         declare
            use Ada.Streams;
            Bytes      : constant Stream_Element_Array :=
              Hex_To_Bytes (Vector.Hex.all);
            Encoded32  : constant String := Encode (Base_32_Lower, Bytes);
            Encoded58  : constant String := Encode (Base_58_BTC, Bytes);
            Decoded32  : constant Stream_Element_Array := Decode (Encoded32);
            Decoded58  : constant Stream_Element_Array := Decode (Encoded58);
         begin
            Test
              (Vector.Name.all & " base32 encode",
               Encoded32 = Vector.B32.all,
               "Expected: " & Vector.B32.all & ", Got: " & Encoded32);

            Test
              (Vector.Name.all & " base32 decode",
               Bytes = Decoded32,
               "Round-trip failed");

            Test
              (Vector.Name.all & " base58 encode",
               Encoded58 = Vector.B58.all,
               "Expected: " & Vector.B58.all & ", Got: " & Encoded58);

            Test
              (Vector.Name.all & " base58 decode",
               Bytes = Decoded58,
               "Round-trip failed");
         end;
      end loop;

      New_Line;
      Put_Line ("Case-insensitive base32 decode test:");
      declare
         use Ada.Streams;
         Upper_B32 : constant String := "BPFSXGIDNMFXGSIBB";
         Mixed_B32 : constant String := "BpFsXgIdNmFxGsIbB";
         Expected  : constant String := "796573206d616e692021";
         Result1   : constant Stream_Element_Array := Decode (Upper_B32);
         Result2   : constant Stream_Element_Array := Decode (Mixed_B32);
      begin
         Test
           ("uppercase base32",
            Bytes_To_Hex (Result1) = Expected,
            "Expected: " & Expected & ", Got: " & Bytes_To_Hex (Result1));
         Test
           ("mixed-case base32",
            Bytes_To_Hex (Result2) = Expected,
            "Expected: " & Expected & ", Got: " & Bytes_To_Hex (Result2));
      end;

      New_Line;
      Put_Line ("Detect_Base tests:");
      Test ("detect base32 lowercase", Detect_Base ("btest") = Base_32_Lower);
      Test ("detect base32 uppercase", Detect_Base ("BTEST") = Base_32_Lower);
      Test ("detect base58btc", Detect_Base ("ztest") = Base_58_BTC);

      New_Line;
      Put_Line ("Rejection tests:");

      --  Empty string
      declare
         use Ada.Streams;
      begin
         declare
            Dummy : constant Stream_Element_Array := Decode ("");
         begin
            Test ("reject empty string", False, "Should raise Malformed_Encoding");
         end;
      exception
         when Malformed_Encoding =>
            Test ("reject empty string", True);
         when E : others =>
            Test
              ("reject empty string",
               False,
               "Wrong exception: " & Ada.Exceptions.Exception_Name (E));
      end;

      --  Unknown prefix
      declare
         use Ada.Streams;
      begin
         declare
            Dummy : constant Stream_Element_Array := Decode ("xabc");
         begin
            Test ("reject unknown prefix", False, "Should raise Malformed_Encoding");
         end;
      exception
         when Malformed_Encoding =>
            Test ("reject unknown prefix", True);
         when E : others =>
            Test
              ("reject unknown prefix",
               False,
               "Wrong exception: " & Ada.Exceptions.Exception_Name (E));
      end;

      --  Base32 with padding
      declare
         use Ada.Streams;
      begin
         declare
            Dummy : constant Stream_Element_Array := Decode ("btest====");
         begin
            Test ("reject base32 with padding", False, "Should raise Malformed_Encoding");
         end;
      exception
         when Malformed_Encoding =>
            Test ("reject base32 with padding", True);
         when E : others =>
            Test
              ("reject base32 with padding",
               False,
               "Wrong exception: " & Ada.Exceptions.Exception_Name (E));
      end;

      --  Base58 with '0' character
      declare
         use Ada.Streams;
      begin
         declare
            Dummy : constant Stream_Element_Array := Decode ("z10test");
         begin
            Test ("reject base58 with '0'", False, "Should raise Malformed_Encoding");
         end;
      exception
         when Malformed_Encoding =>
            Test ("reject base58 with '0'", True);
         when E : others =>
            Test
              ("reject base58 with '0'",
               False,
               "Wrong exception: " & Ada.Exceptions.Exception_Name (E));
      end;

      New_Line;
      Put_Line ("========================================");
      Put_Line
        ("Multibase tests: " & Total_Tests'Image & " run," &
         Passed_Tests'Image & " passed");
      if Passed_Tests = Total_Tests then
         Put_Line ("All tests passed!");
      else
         Put_Line
           ("FAILED: " & Natural'Image (Total_Tests - Passed_Tests) & " tests");
      end if;
   end Run;

end Multibase_Tests;
