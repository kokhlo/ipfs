--  Test runner for the ipfs crate: calls every module suite in turn.

with SHA256_Tests;
with Multibase_Tests;
with Multihash_Tests;
with CID_Tests;
with DagPB_Tests;
with UnixFS_Tests;
with CAR_Tests;

with Ada.Text_IO;
with Ada.Exceptions;

procedure IPFS_Tests_Runner is
begin
   SHA256_Tests.Run;
   Multibase_Tests.Run;
   Multihash_Tests.Run;
   CID_Tests.Run;
   DagPB_Tests.Run;
   UnixFS_Tests.Run;
   CAR_Tests.Run;
   Ada.Text_IO.New_Line;
   Ada.Text_IO.Put_Line ("ada-ipfs: all suites completed");
exception
   when E : others =>
      Ada.Text_IO.Put_Line
        ("UNEXPECTED EXCEPTION: " & Ada.Exceptions.Exception_Message (E));
      Ada.Text_IO.Put_Line ("ada-ipfs: FAILED");
end IPFS_Tests_Runner;
