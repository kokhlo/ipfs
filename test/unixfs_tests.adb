--  UnixFS tests implementation.

with Ada.Text_IO;
with Ada.Streams.Stream_IO;
with Interfaces;
with IPFS.DagPB;
with IPFS.UnixFS;

package body UnixFS_Tests is

   use Ada.Text_IO;
   use type IPFS.UnixFS.Data_Format_Type;
   use type Interfaces.Unsigned_64;

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
   --  Test_Big_UnixFS --
   ---------------------

   procedure Test_Big_UnixFS is
      Bytes : constant Ada.Streams.Stream_Element_Array := Load_Fixture ("big_intermediate_block.bin");
      Node  : IPFS.DagPB.Node_Type;
      UFS   : IPFS.UnixFS.Data_Type;
   begin
      Tests_Run := Tests_Run + 1;
      Node := IPFS.DagPB.Decode (Bytes);

      if Node.Links_Count /= 2 then
         Put_Line ("FAIL: big_intermediate_block.bin: expected 2 links, got " & Node.Links_Count'Image);
         return;
      end if;

      if Node.Data_Len = 0 then
         Put_Line ("FAIL: big_intermediate_block.bin: empty Data field");
         return;
      end if;

      UFS := IPFS.UnixFS.Decode_Data (Node.Data (1 .. Ada.Streams.Stream_Element_Offset (Node.Data_Len)));

      if UFS.Format /= IPFS.UnixFS.File then
         Put_Line ("FAIL: big_intermediate_block.bin: expected Format=File, got " & UFS.Format'Image);
         return;
      end if;

      if UFS.FileSize /= 300000 then
         Put_Line ("FAIL: big_intermediate_block.bin: expected FileSize=300000, got " & UFS.FileSize'Image);
         return;
      end if;

      if UFS.Blocksizes_Count /= 2 then
         Put_Line ("FAIL: big_intermediate_block.bin: expected 2 blocksizes, got " & UFS.Blocksizes_Count'Image);
         return;
      end if;

      if UFS.Blocksizes (1) /= 262144 or else UFS.Blocksizes (2) /= 37856 then
         Put_Line ("FAIL: big_intermediate_block.bin: blocksize mismatch (expected [262144, 37856])");
         return;
      end if;

      Put_Line ("PASS: big_intermediate_block.bin UnixFS (File, size=300000, blocksizes=[262144,37856])");
      Tests_Passed := Tests_Passed + 1;
   end Test_Big_UnixFS;

   ---------------------
   --  Test_Dir_UnixFS --
   ---------------------

   procedure Test_Dir_UnixFS is
      Bytes : constant Ada.Streams.Stream_Element_Array := Load_Fixture ("dir_block.bin");
      Node  : IPFS.DagPB.Node_Type;
      UFS   : IPFS.UnixFS.Data_Type;
   begin
      Tests_Run := Tests_Run + 1;
      Node := IPFS.DagPB.Decode (Bytes);

      if Node.Data_Len = 0 then
         Put_Line ("FAIL: dir_block.bin: empty Data field");
         return;
      end if;

      UFS := IPFS.UnixFS.Decode_Data (Node.Data (1 .. Ada.Streams.Stream_Element_Offset (Node.Data_Len)));

      if UFS.Format /= IPFS.UnixFS.Directory then
         Put_Line ("FAIL: dir_block.bin: expected Format=Directory, got " & UFS.Format'Image);
         return;
      end if;

      Put_Line ("PASS: dir_block.bin UnixFS (Directory)");
      Tests_Passed := Tests_Passed + 1;
   end Test_Dir_UnixFS;

   ---------
   --  Run --
   ---------

   procedure Run is
   begin
      Tests_Run    := 0;
      Tests_Passed := 0;

      Test_Dir_UnixFS;
      Test_Big_UnixFS;

      Put_Line ("UnixFS tests: " & Tests_Run'Image & " run," & Tests_Passed'Image & " passed");
   end Run;

end UnixFS_Tests;
