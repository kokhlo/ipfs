--  CLI tool: fetch CID content from IPFS gateway and verify.
--  Usage: fetch_cid <cid> [gateway_host:port]
--  Default gateway: 127.0.0.1:8080 (local kubo daemon).

with Ada.Command_Line;
with Ada.Text_IO;
with Ada.Streams.Stream_IO;
with Ada.Exceptions;
with Interfaces;
with IPFS.CID;
with IPFS.Multihash;
with IPFS.Gateway;
with IPFS.DagPB;
with IPFS.UnixFS;

procedure Fetch_CID is

   use Ada.Text_IO;
   use Ada.Streams;
   use Interfaces;

   Gateway : IPFS.Gateway.Gateway_Config;
   CID_Text : String (1 .. 256);
   CID_Len  : Natural := 0;
   Parsed_CID : IPFS.CID.CID_Type;
   Output_File : Stream_IO.File_Type;

begin
   if Ada.Command_Line.Argument_Count < 1 then
      Put_Line ("Usage: fetch_cid <cid> [gateway_host:port]");
      Put_Line ("Default gateway: 127.0.0.1:8080");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   --  Parse CID.
   declare
      Arg : constant String := Ada.Command_Line.Argument (1);
   begin
      CID_Len := Arg'Length;
      CID_Text (1 .. CID_Len) := Arg;
      Parsed_CID := IPFS.CID.Parse (Arg);
      Put_Line ("Parsed CID: " & IPFS.CID.To_String (Parsed_CID));
   exception
      when IPFS.CID.Malformed_CID =>
         Put_Line ("Error: Malformed CID");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
   end;

   --  Configure gateway.
   Gateway.Host (1 .. 9) := "127.0.0.1";
   Gateway.Host_Len := 9;
   Gateway.Port := 8080;
   Gateway.Use_TLS := False;

   if Ada.Command_Line.Argument_Count >= 2 then
      declare
         Gateway_Arg : constant String := Ada.Command_Line.Argument (2);
         Colon_Pos   : Natural := 0;
      begin
         for I in Gateway_Arg'Range loop
            if Gateway_Arg (I) = ':' then
               Colon_Pos := I;
               exit;
            end if;
         end loop;

         if Colon_Pos > 0 then
            Gateway.Host_Len := Colon_Pos - 1;
            Gateway.Host (1 .. Gateway.Host_Len) := Gateway_Arg (Gateway_Arg'First .. Colon_Pos - 1);
            Gateway.Port := Unsigned_16 (Natural'Value (Gateway_Arg (Colon_Pos + 1 .. Gateway_Arg'Last)));
         else
            Gateway.Host_Len := Gateway_Arg'Length;
            Gateway.Host (1 .. Gateway.Host_Len) := Gateway_Arg;
         end if;
      end;
   end if;

   Put_Line ("Gateway: " & Gateway.Host (1 .. Gateway.Host_Len) &
             ":" & Gateway.Port'Image);

   --  Fetch raw block.
   Put_Line ("Fetching raw block...");
   declare
      Raw_Block : constant Stream_Element_Array :=
        IPFS.Gateway.Fetch_Raw_Block (Gateway, CID_Text (1 .. CID_Len));
      MH : constant IPFS.Multihash.Hash_Type := IPFS.CID.Multihash_Of (Parsed_CID);
      MH_Bytes : constant Stream_Element_Array :=
        IPFS.Multihash.Encode (IPFS.Multihash.Code (MH), IPFS.Multihash.Digest_Of (MH));
   begin
      Put_Line ("Received" & Raw_Block'Length'Image & " bytes");

      --  Verify multihash.
      if IPFS.Multihash.Verify (Raw_Block, MH_Bytes) then
         Put_Line ("✓ Multihash verified");
      else
         Put_Line ("✗ Multihash verification FAILED");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      end if;

      --  Attempt UnixFS extraction if codec is dag-pb.
      if IPFS.CID.Codec (Parsed_CID) = IPFS.CID.Dag_Pb_Code then
         declare
            Node : constant IPFS.DagPB.Node_Type := IPFS.DagPB.Decode (Raw_Block);
         begin
            if IPFS.UnixFS.Is_File (Node) and then IPFS.UnixFS.Link_Count (Node) = 0 then
               declare
                  File_Bytes : constant Stream_Element_Array := IPFS.UnixFS.File_Data (Node);
                  Output_Name : constant String := "fetched_" & CID_Text (1 .. CID_Len) & ".bin";
               begin
                  Put_Line ("Extracting UnixFS single-block file (" & File_Bytes'Length'Image & " bytes)");

                  Stream_IO.Create (Output_File, Stream_IO.Out_File, Output_Name);
                  Stream_IO.Write (Output_File, File_Bytes);
                  Stream_IO.Close (Output_File);

                  Put_Line ("✓ Wrote " & Output_Name);
               end;
            else
               Put_Line ("Note: dag-pb node is not a single-block file (multi-block or directory)");
            end if;
         exception
            when IPFS.DagPB.Malformed_DagPB | IPFS.UnixFS.Malformed_UnixFS =>
               Put_Line ("Note: dag-pb decode failed, not a valid UnixFS structure");
         end;
      elsif IPFS.CID.Codec (Parsed_CID) = IPFS.CID.Raw_Code then
         --  Raw codec: write directly.
         declare
            Output_Name : constant String := "fetched_" & CID_Text (1 .. CID_Len) & ".bin";
         begin
            Stream_IO.Create (Output_File, Stream_IO.Out_File, Output_Name);
            Stream_IO.Write (Output_File, Raw_Block);
            Stream_IO.Close (Output_File);

            Put_Line ("✓ Wrote raw block to " & Output_Name);
         end;
      else
         Put_Line ("Note: Codec not supported for file extraction (codec code:" &
                   IPFS.CID.Codec (Parsed_CID)'Image & ")");
      end if;
   end;

exception
   when IPFS.Gateway.Connection_Error =>
      Put_Line ("Error: Connection failed (is kubo daemon running?)");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   when IPFS.Gateway.Gateway_Error =>
      Put_Line ("Error: Gateway returned error (404 or 5xx)");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   when E : others =>
      Put_Line ("Error: " & Ada.Exceptions.Exception_Information (E));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end Fetch_CID;
