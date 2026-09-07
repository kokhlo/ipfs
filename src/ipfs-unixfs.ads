--  UnixFS data structure codec (reads UnixFS Data field from dag-pb).
--  Protobuf encoding: field 1 = Type (varint), field 2 = Data (bytes),
--  field 3 = FileSize (varint), field 4 = BlockSizes (repeated varint).

pragma SPARK_Mode;

with Ada.Streams;
with Interfaces;
with IPFS.DagPB;

package IPFS.UnixFS is

   use type Ada.Streams.Stream_Element_Offset;

   type Data_Format_Type is
     (Raw, Directory, File, Metadata, Symlink, HAMT_Shard);

   Malformed_UnixFS : exception;

   Max_Blocksizes : constant := 8;

   type Blocksize_Array is array (1 .. Max_Blocksizes) of Interfaces.Unsigned_64;

   type Data_Type is record
      Format           : Data_Format_Type;
      FileSize         : Interfaces.Unsigned_64;
      Blocksizes       : Blocksize_Array;
      Blocksizes_Count : Natural;
   end record;

   --  Decode UnixFS Data field (protobuf inside dag-pb Data field).
   function Decode_Data
     (Block_Bytes : Ada.Streams.Stream_Element_Array)
      return Data_Type;

   --  Check if a dag-pb node represents a UnixFS file.
   function Is_File (N : IPFS.DagPB.Node_Type) return Boolean;

   --  Extract raw file data from a single-block UnixFS file.
   --  For Raw/File with no links, returns the embedded Data payload (field 2).
   --  Raises exception if the node is not a single-block file.
   function File_Data
     (N : IPFS.DagPB.Node_Type)
      return Ada.Streams.Stream_Element_Array;

   --  Link accessors (convenience wrappers over DagPB).
   function Link_Count (N : IPFS.DagPB.Node_Type) return Natural;
   function Link_Name
     (N : IPFS.DagPB.Node_Type; Index : Positive)
      return String;
   function Link_Hash
     (N : IPFS.DagPB.Node_Type; Index : Positive)
      return Ada.Streams.Stream_Element_Array;

end IPFS.UnixFS;
