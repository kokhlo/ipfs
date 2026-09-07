pragma SPARK_Mode;

with Ada.Text_IO;
with Ada.Streams;
with IPFS.SHA256;

package body SHA256_Tests is

   use Ada.Text_IO;
   use Ada.Streams;

   Tests_Run : Natural := 0;
   Tests_Passed : Natural := 0;
   Has_Failure : Boolean := False;

   procedure Check_Hash
     (Name     : String;
      Input    : Stream_Element_Array;
      Expected : String)
   is
      Result : constant Stream_Element_Array := IPFS.SHA256.Digest (Input);
      Hex : String (1 .. 64);
      Hex_Digits : constant String := "0123456789abcdef";
   begin
      Tests_Run := Tests_Run + 1;

      for I in Result'Range loop
         declare
            Byte : constant Stream_Element := Result (I);
            High : constant Natural := Natural (Byte / 16);
            Low  : constant Natural := Natural (Byte mod 16);
            Pos  : constant Natural := Natural (I - Result'First) * 2 + 1;
         begin
            Hex (Pos) := Hex_Digits (High + 1);
            Hex (Pos + 1) := Hex_Digits (Low + 1);
         end;
      end loop;

      if Hex = Expected then
         Tests_Passed := Tests_Passed + 1;
      else
         Put_Line ("FAIL: " & Name);
         Put_Line ("  Expected: " & Expected);
         Put_Line ("  Got:      " & Hex);
         Has_Failure := True;
      end if;
   end Check_Hash;

   type Offset_Array is array (Natural range <>) of Natural;

   procedure Check_Incremental
     (Name      : String;
      Data      : Stream_Element_Array;
      Chunk_Sizes : Offset_Array;
      Expected  : String)
   is
      Ctx : IPFS.SHA256.Context := IPFS.SHA256.Initial;
      Result : Stream_Element_Array (1 .. 32);
      Hex : String (1 .. 64);
      Hex_Digits : constant String := "0123456789abcdef";
      Offset : Stream_Element_Offset := Data'First;
   begin
      Tests_Run := Tests_Run + 1;

      for Size of Chunk_Sizes loop
         declare
            Chunk_End : constant Stream_Element_Offset :=
              Stream_Element_Offset (Integer (Offset) + Size - 1);
         begin
            if Size > 0 and then Chunk_End <= Data'Last then
               IPFS.SHA256.Update (Ctx, Data (Offset .. Chunk_End));
               Offset := Stream_Element_Offset (Integer (Chunk_End) + 1);
            end if;
         end;
      end loop;

      --  Process any remaining data
      if Offset <= Data'Last then
         IPFS.SHA256.Update (Ctx, Data (Offset .. Data'Last));
      end if;

      Result := IPFS.SHA256.Finish (Ctx);

      for I in Result'Range loop
         declare
            Byte : constant Stream_Element := Result (I);
            High : constant Natural := Natural (Byte / 16);
            Low  : constant Natural := Natural (Byte mod 16);
            Pos  : constant Natural := Natural (I - Result'First) * 2 + 1;
         begin
            Hex (Pos) := Hex_Digits (High + 1);
            Hex (Pos + 1) := Hex_Digits (Low + 1);
         end;
      end loop;

      if Hex = Expected then
         Tests_Passed := Tests_Passed + 1;
      else
         Put_Line ("FAIL: " & Name);
         Put_Line ("  Expected: " & Expected);
         Put_Line ("  Got:      " & Hex);
         Has_Failure := True;
      end if;
   end Check_Incremental;

   procedure Run is
      Empty : constant Stream_Element_Array (1 .. 0) := [];
      ABC : constant Stream_Element_Array := [Character'Pos ('a'), Character'Pos ('b'), Character'Pos ('c')];

      --  FIPS 180-4 Appendix B.1: "abc"
      ABC_Hash : constant String := "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";

      --  Empty string
      Empty_Hash : constant String := "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855";

      --  FIPS 180-4 two-block message: "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq" (56 bytes)
      Two_Block : constant Stream_Element_Array :=
        [Character'Pos ('a'), Character'Pos ('b'), Character'Pos ('c'), Character'Pos ('d'),
         Character'Pos ('b'), Character'Pos ('c'), Character'Pos ('d'), Character'Pos ('e'),
         Character'Pos ('c'), Character'Pos ('d'), Character'Pos ('e'), Character'Pos ('f'),
         Character'Pos ('d'), Character'Pos ('e'), Character'Pos ('f'), Character'Pos ('g'),
         Character'Pos ('e'), Character'Pos ('f'), Character'Pos ('g'), Character'Pos ('h'),
         Character'Pos ('f'), Character'Pos ('g'), Character'Pos ('h'), Character'Pos ('i'),
         Character'Pos ('g'), Character'Pos ('h'), Character'Pos ('i'), Character'Pos ('j'),
         Character'Pos ('h'), Character'Pos ('i'), Character'Pos ('j'), Character'Pos ('k'),
         Character'Pos ('i'), Character'Pos ('j'), Character'Pos ('k'), Character'Pos ('l'),
         Character'Pos ('j'), Character'Pos ('k'), Character'Pos ('l'), Character'Pos ('m'),
         Character'Pos ('k'), Character'Pos ('l'), Character'Pos ('m'), Character'Pos ('n'),
         Character'Pos ('l'), Character'Pos ('m'), Character'Pos ('n'), Character'Pos ('o'),
         Character'Pos ('m'), Character'Pos ('n'), Character'Pos ('o'), Character'Pos ('p'),
         Character'Pos ('n'), Character'Pos ('o'), Character'Pos ('p'), Character'Pos ('q')];

      Two_Block_Hash : constant String := "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1";

      --  One million 'a'
      Million_A_Hash : constant String := "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0";

   begin
      Tests_Run := 0;
      Tests_Passed := 0;
      Has_Failure := False;

      Check_Hash ("Empty string", Empty, Empty_Hash);
      Check_Hash ("abc", ABC, ABC_Hash);
      Check_Hash ("Two-block FIPS vector", Two_Block, Two_Block_Hash);

      --  One million 'a' test
      declare
         Million : Stream_Element_Array (1 .. 1_000_000);
      begin
         for I in Million'Range loop
            Million (I) := Character'Pos ('a');
         end loop;
         Check_Hash ("One million 'a'", Million, Million_A_Hash);

         --  Incremental test: chunks of 1, 7, 63, 64, 1000 bytes, then remainder
         declare
            Chunk_Sizes : constant Offset_Array := [1, 7, 63, 64, 1000];
         begin
            Check_Incremental
              ("Incremental vs one-shot",
               Million,
               Chunk_Sizes,
               Million_A_Hash);
         end;
      end;

      Put_Line ("SHA256 tests: " & Natural'Image (Tests_Run) & " run," &
                Natural'Image (Tests_Passed) & " passed");

      if Has_Failure then
         raise Program_Error with "SHA256 tests failed";
      end if;
   end Run;

end SHA256_Tests;
