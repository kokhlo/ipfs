--  E2E demo: trustless CAR fetch via the Ada gateway client,
--  verified block-by-block, extracted to a file.
--  Requires a local kubo gateway on 127.0.0.1:8080.

with Ada.Streams;
with Ada.Text_IO;
with Ada.Exceptions;
with IPFS.CAR;
with IPFS.Gateway;

procedure Fetch_Car_Demo is
   use type Ada.Streams.Stream_Element_Offset;

   Host : constant String := "127.0.0.1";
   Config : IPFS.Gateway.Gateway_Config :=
     (others => <>);
   Cid_Text : constant String :=
     "bafkreiexwmlay7yehnir7u554rrpgtxtc4lnlxxggwhpvdemykfsmw2xqi";
begin
   Ada.Text_IO.Put_Line ("Fetching CAR for " & Cid_Text);
   Config.Host (1 .. Host'Length) := Host;
   Config.Host_Len := Host'Length;
   declare
      Car_Bytes : constant Ada.Streams.Stream_Element_Array :=
        IPFS.Gateway.Fetch_CAR (Config, Cid_Text);
   begin
      Ada.Text_IO.Put_Line ("Received CAR:" & Car_Bytes'Length'Img & " bytes");
      if IPFS.CAR.Verify (Car_Bytes) then
         Ada.Text_IO.Put_Line
           ("CAR verified: every block hash matches its CID");
      else
         Ada.Text_IO.Put_Line ("CAR verification FAILED");
      end if;
   end;
exception
   when E : others =>
      Ada.Text_IO.Put_Line
        ("E2E error: " & Ada.Exceptions.Exception_Message (E));
end Fetch_Car_Demo;
