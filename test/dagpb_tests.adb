--  DAG-PB tests implementation.

with Ada.Text_IO;
with Ada.Streams.Stream_IO;
with IPFS.DagPB;

package body DagPB_Tests is

   use Ada.Text_IO;
   use type Ada.Streams.Stream_Element;

   Tests_Run    : Natural := 0;
   Tests_Passed : Natural := 0;

   ------------------
   --  Load_Fixture --
   ------------------

   function Load_Fixture
     (Name : String)
      return Ada.Streams.Stream_Element_Array
   is
      F       : Ada.Streams.Stream_IO.File_Type;
      Path    : constant String := "test/fixtures/" & Name;
      Size    : Ada.Streams.Stream_Element_Offset;
      Last    : Ada.Streams.Stream_Element_Offset;
   begin
      Ada.Streams.Stream_IO.Open (F, Ada.Streams.Stream_IO.In_File, Path);
      Size := Ada.Streams.Stream_Element_Offset (Ada.Streams.Stream_IO.Size (F));
      declare
         Buf : Ada.Streams.Stream_Element_Array (1 .. Size);
      begin
         Ada.Streams.Stream_IO.Read (F, Buf, Last);
         Ada.Streams.Stream_IO.Close (F);
         return Buf;
      end;
   end Load_Fixture;

   ---------------------
   --  Test_Dir_Block --
   ---------------------

   procedure Test_Dir_Block is
      Bytes : constant Ada.Streams.Stream_Element_Array := Load_Fixture ("dir_block.bin");
      Node  : IPFS.DagPB.Node_Type;
   begin
      Tests_Run := Tests_Run + 1;
      Node := IPFS.DagPB.Decode (Bytes);

      if Node.Links_Count /= 1 then
         Put_Line ("FAIL: dir_block.bin: expected 1 link, got " & Node.Links_Count'Image);
         return;
      end if;

      if Node.Links (1).Name_Len /= 9 then
         Put_Line ("FAIL: dir_block.bin: link name length mismatch");
         return;
      end if;

      if Node.Links (1).Name (1 .. 9) /= "inner.txt" then
         Put_Line ("FAIL: dir_block.bin: link name is '" &
                   Node.Links (1).Name (1 .. Node.Links (1).Name_Len) & "', expected 'inner.txt'");
         return;
      end if;

      if Node.Links (1).Hash_Len < 4 then
         Put_Line ("FAIL: dir_block.bin: hash too short");
         return;
      end if;

      if Node.Links (1).Hash (1) /= Ada.Streams.Stream_Element (16#01#) or else
         Node.Links (1).Hash (2) /= Ada.Streams.Stream_Element (16#55#) or else
         Node.Links (1).Hash (3) /= Ada.Streams.Stream_Element (16#12#) or else
         Node.Links (1).Hash (4) /= Ada.Streams.Stream_Element (16#20#)
      then
         Put_Line ("FAIL: dir_block.bin: hash prefix mismatch (expected 01 55 12 20)");
         return;
      end if;

      Put_Line ("PASS: dir_block.bin");
      Tests_Passed := Tests_Passed + 1;
   end Test_Dir_Block;

   --------------------------
   --  Test_Big_Root_Block --
   --------------------------

   procedure Test_Big_Root_Block is
      Bytes : constant Ada.Streams.Stream_Element_Array := Load_Fixture ("big_root_block.bin");
      Node  : IPFS.DagPB.Node_Type;
   begin
      Tests_Run := Tests_Run + 1;
      Node := IPFS.DagPB.Decode (Bytes);

      if Node.Links_Count /= 1 then
         Put_Line ("FAIL: big_root_block.bin: expected 1 link, got " & Node.Links_Count'Image);
         return;
      end if;

      if Node.Data_Len = 0 then
         Put_Line ("FAIL: big_root_block.bin: empty Data field");
         return;
      end if;

      --  UnixFS Data field should decode (tested in UnixFS_Tests)
      Put_Line ("PASS: big_root_block.bin");
      Tests_Passed := Tests_Passed + 1;
   end Test_Big_Root_Block;

   ---------
   --  Run --
   ---------

   procedure Run is
   begin
      Tests_Run    := 0;
      Tests_Passed := 0;

      Test_Dir_Block;
      Test_Big_Root_Block;

      Put_Line ("DagPB tests: " & Tests_Run'Image & " run," & Tests_Passed'Image & " passed");
   end Run;

end DagPB_Tests;
