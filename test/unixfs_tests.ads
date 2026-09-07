--  UnixFS decoder tests against real fixtures.

with Ada.Streams;

package UnixFS_Tests is

   --  Run all UnixFS tests.
   --  Prints: "UnixFS tests: N run, M passed"
   procedure Run;

private

   --  Test big_root_block.bin UnixFS Data: Format=File, FileSize=300000, blocksizes=[...].
   procedure Test_Big_UnixFS;

   --  Test dir_block.bin UnixFS Data: Format=Directory.
   procedure Test_Dir_UnixFS;

   --  Load fixture bytes from test/fixtures/<name>.
   function Load_Fixture
     (Name : String)
      return Ada.Streams.Stream_Element_Array;

end UnixFS_Tests;
