--  NebulaPlayer scenario: fetch a verified audio file from IPFS
--  (raw block, single-block UnixFS) through the gateway client.

with Ada.Streams;
with Ada.Text_IO;
with Ada.Exceptions;
with IPFS.Gateway;

procedure Nebula_Demo is
   use type Ada.Streams.Stream_Element_Offset;

   Host : constant String := "127.0.0.1";
   Config : IPFS.Gateway.Gateway_Config := (others => <>);
   Audio_Cid : constant String :=
     "bafkreifgpexvgq7y4zmo4x2bbvpdj57jchmurdkzuvhorqyho2cvjishqu";
begin
   Config.Host (1 .. Host'Length) := Host;
   Config.Host_Len := Host'Length;
   Ada.Text_IO.Put_Line ("NebulaPlayer: fetching audio from IPFS...");
   declare
      Block : constant Ada.Streams.Stream_Element_Array :=
        IPFS.Gateway.Fetch_Raw_Block (Config, Audio_Cid);
   begin
      Ada.Text_IO.Put_Line ("fetched" & Block'Length'Img &
        " bytes, multihash verified");
   end;
exception
   when E : others =>
      Ada.Text_IO.Put_Line ("error: " & Ada.Exceptions.Exception_Message (E));
end Nebula_Demo;
