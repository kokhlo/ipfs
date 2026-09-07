--  DAG-PB decoder tests against real fixtures.

with Ada.Streams;

package DagPB_Tests is

   --  Run all dag-pb tests.
   --  Prints: "DagPB tests: N run, M passed"
   procedure Run;

private

   --  Test dir_block.bin: 1 link, name 'inner.txt', hash starts 0x01 0x55 0x12 0x20.
   procedure Test_Dir_Block;

   --  Test big_root_block.bin: 1 link, UnixFS type=File or Directory.
   procedure Test_Big_Root_Block;

   --  Load fixture bytes from test/fixtures/<name>.
   function Load_Fixture
     (Name : String)
      return Ada.Streams.Stream_Element_Array;

end DagPB_Tests;
