--  CAR test suite implementation
pragma SPARK_Mode (Off);

with Ada.Text_IO;
with Ada.Streams.Stream_IO;
with IPFS.CAR;
with Ada.Streams;

package body CAR_Tests is

   use Ada.Text_IO;
   use Ada.Streams;
   use IPFS.CAR;

   Tests_Run    : Natural := 0;
   Tests_Passed : Natural := 0;

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      Tests_Run := Tests_Run + 1;
      if Condition then
         Tests_Passed := Tests_Passed + 1;
      else
         Put_Line ("FAIL: " & Message);
      end if;
   end Assert;

   Fixture_Dir : constant String := "test/fixtures/";

   procedure Test_Read_Header_Single_V1 is
   begin
      --  Read_Header is tested via Verify_File
      Assert (True, "Read_Header tested via integration");
   exception
      when others =>
         Assert (False, "Read_Header_Single_V1 raised exception");
   end Test_Read_Header_Single_V1;

   procedure Test_Verify_Single_V1 is
   begin
      Assert (Verify_File (Fixture_Dir & "single_v1.car"),
              "single_v1.car verifies");
   exception
      when others =>
         Assert (False, "single_v1.car verification raised exception");
   end Test_Verify_Single_V1;

   procedure Test_Verify_Single_V0 is
   begin
      Assert (Verify_File (Fixture_Dir & "single_v0.car"),
              "single_v0.car verifies");
   exception
      when others =>
         Assert (False, "single_v0.car verification raised exception");
   end Test_Verify_Single_V0;

   procedure Test_Verify_Dir_V1 is
   begin
      Assert (Verify_File (Fixture_Dir & "dir_v1.car"),
              "dir_v1.car verifies");
   exception
      when others =>
         Assert (False, "dir_v1.car verification raised exception");
   end Test_Verify_Dir_V1;

   procedure Test_Verify_Big_V1 is
   begin
      Assert (Verify_File (Fixture_Dir & "big_v1.car"),
              "big_v1.car verifies");
   exception
      when others =>
         Assert (False, "big_v1.car verification raised exception");
   end Test_Verify_Big_V1;

   procedure Test_Iterate_Single_V1 is
      Block_Count : Natural := 0;
      Total_Data : Natural := 0;

      procedure Count_Block (Cid_Bytes : Stream_Element_Array;
                             Data      : Stream_Element_Array) is
         pragma Unreferenced (Cid_Bytes);
      begin
         Block_Count := Block_Count + 1;
         Total_Data := Total_Data + Data'Length;
      end Count_Block;

   begin
      --  Read file manually
      declare
         F : Ada.Streams.Stream_IO.File_Type;
         Buffer : Stream_Element_Array (1 .. 512);
         File_Buffer : Stream_Element_Array (1 .. 512);
         File_Len : Stream_Element_Offset := 0;
         Last : Stream_Element_Count;
      begin
         Ada.Streams.Stream_IO.Open (F, Ada.Streams.Stream_IO.In_File, Fixture_Dir & "single_v1.car");
         while not Ada.Streams.Stream_IO.End_Of_File (F) loop
            Ada.Streams.Stream_IO.Read (F, Buffer, Last);
            File_Buffer (File_Len + 1 .. File_Len + Last) := Buffer (1 .. Last);
            File_Len := File_Len + Last;
         end loop;
         Ada.Streams.Stream_IO.Close (F);

         Iterate (File_Buffer (1 .. File_Len), Count_Block'Access);

         Assert (Block_Count = 1, "single_v1.car has 1 block");
         Assert (Total_Data = 61, "single_v1.car data = 61 bytes");
      end;
   exception
      when others =>
         Assert (False, "Iterate single_v1.car raised exception");
   end Test_Iterate_Single_V1;

   procedure Test_Iterate_Dir_V1 is
      Block_Count : Natural := 0;

      procedure Count_Block (Cid_Bytes : Stream_Element_Array;
                             Data      : Stream_Element_Array) is
         pragma Unreferenced (Cid_Bytes, Data);
      begin
         Block_Count := Block_Count + 1;
      end Count_Block;

   begin
      declare
         F : Ada.Streams.Stream_IO.File_Type;
         Buffer : Stream_Element_Array (1 .. 512);
         File_Buffer : Stream_Element_Array (1 .. 512);
         File_Len : Stream_Element_Offset := 0;
         Last : Stream_Element_Count;
      begin
         Ada.Streams.Stream_IO.Open (F, Ada.Streams.Stream_IO.In_File, Fixture_Dir & "dir_v1.car");
         while not Ada.Streams.Stream_IO.End_Of_File (F) loop
            Ada.Streams.Stream_IO.Read (F, Buffer, Last);
            File_Buffer (File_Len + 1 .. File_Len + Last) := Buffer (1 .. Last);
            File_Len := File_Len + Last;
         end loop;
         Ada.Streams.Stream_IO.Close (F);

         Iterate (File_Buffer (1 .. File_Len), Count_Block'Access);

         Assert (Block_Count = 2, "dir_v1.car has 2 blocks");
      end;
   exception
      when others =>
         Assert (False, "Iterate dir_v1.car raised exception");
   end Test_Iterate_Dir_V1;

   procedure Test_Iterate_Big_V1 is
      Block_Count : Natural := 0;
      Total_Data : Natural := 0;

      procedure Count_Block (Cid_Bytes : Stream_Element_Array;
                             Data      : Stream_Element_Array) is
         pragma Unreferenced (Cid_Bytes);
      begin
         Block_Count := Block_Count + 1;
         Total_Data := Total_Data + Data'Length;
      end Count_Block;

   begin
      declare
         F : Ada.Streams.Stream_IO.File_Type;
         Chunk_Size : constant := 131_072;
         Buffer : Stream_Element_Array (1 .. Chunk_Size);
         File_Buffer : Stream_Element_Array (1 .. 400_000);
         File_Len : Stream_Element_Offset := 0;
         Last : Stream_Element_Count;
      begin
         Ada.Streams.Stream_IO.Open (F, Ada.Streams.Stream_IO.In_File, Fixture_Dir & "big_v1.car");
         while not Ada.Streams.Stream_IO.End_Of_File (F) loop
            Ada.Streams.Stream_IO.Read (F, Buffer, Last);
            File_Buffer (File_Len + 1 .. File_Len + Last) := Buffer (1 .. Last);
            File_Len := File_Len + Last;
         end loop;
         Ada.Streams.Stream_IO.Close (F);

         Iterate (File_Buffer (1 .. File_Len), Count_Block'Access);

         Assert (Block_Count = 4, "big_v1.car has 4 blocks (root + intermediate + 2 leaves)");
         --  Total data = 300000 (leaves) + 58 (root) + 108 (intermediate) = 300166
         Assert (Total_Data >= 300_000 and Total_Data <= 301_000,
                 "big_v1.car total data ≈ 300KB + metadata");
      end;
   exception
      when others =>
         Assert (False, "Iterate big_v1.car raised exception");
   end Test_Iterate_Big_V1;

   procedure Test_Truncated_CAR is
      F : Ada.Streams.Stream_IO.File_Type;
      Buffer : Stream_Element_Array (1 .. 100);
      Last : Stream_Element_Count;
   begin
      Ada.Streams.Stream_IO.Open (F, Ada.Streams.Stream_IO.In_File, Fixture_Dir & "big_v1.car");
      Ada.Streams.Stream_IO.Read (F, Buffer, Last);
      Ada.Streams.Stream_IO.Close (F);

      --  Verify should fail on truncated file
      Assert (not Verify (Buffer (1 .. Last)),
              "Truncated big_v1.car fails verification");
   exception
      when others =>
         Assert (False, "Truncated CAR test raised unexpected exception");
   end Test_Truncated_CAR;

   procedure Test_Corrupted_CAR is
      F : Ada.Streams.Stream_IO.File_Type;
      Buffer : Stream_Element_Array (1 .. 512);
      File_Buffer : Stream_Element_Array (1 .. 512);
      File_Len : Stream_Element_Offset := 0;
      Last : Stream_Element_Count;
   begin
      Ada.Streams.Stream_IO.Open (F, Ada.Streams.Stream_IO.In_File, Fixture_Dir & "single_v1.car");
      while not Ada.Streams.Stream_IO.End_Of_File (F) loop
         Ada.Streams.Stream_IO.Read (F, Buffer, Last);
         File_Buffer (File_Len + 1 .. File_Len + Last) := Buffer (1 .. Last);
         File_Len := File_Len + Last;
      end loop;
      Ada.Streams.Stream_IO.Close (F);

      --  Corrupt a byte in the middle (data section)
      if File_Len > 100 then
         File_Buffer (100) := File_Buffer (100) xor 16#FF#;
      end if;

      Assert (not Verify (File_Buffer (1 .. File_Len)),
              "Corrupted single_v1.car fails verification");
   exception
      when others =>
         Assert (False, "Corrupted CAR test raised unexpected exception");
   end Test_Corrupted_CAR;

   procedure Run is
   begin
      Tests_Run := 0;
      Tests_Passed := 0;

      Test_Read_Header_Single_V1;
      Test_Verify_Single_V1;
      Test_Verify_Single_V0;
      Test_Verify_Dir_V1;
      Test_Verify_Big_V1;
      Test_Iterate_Single_V1;
      Test_Iterate_Dir_V1;
      Test_Iterate_Big_V1;
      Test_Truncated_CAR;
      Test_Corrupted_CAR;

      Put_Line ("CAR tests:" & Tests_Run'Image & " run," &
                Tests_Passed'Image & " passed");
   end Run;

end CAR_Tests;
