--  IPFS HTTP Gateway client (GNAT.Sockets, HTTP/1.1 only).
--  Fetches raw blocks and CAR archives from localhost kubo or HTTP-only public gateways.
pragma SPARK_Mode (Off);

with Ada.Streams;
with Interfaces;

package IPFS.Gateway is

   use type Ada.Streams.Stream_Element_Offset;

   type Gateway_Config is record
      Host     : String (1 .. 128) := [others => ' '];
      Host_Len : Natural := 0;
      Port     : Interfaces.Unsigned_16 := 8080;
      Use_TLS  : Boolean := False;
   end record;

   Connection_Error : exception;
   Gateway_Error    : exception;

   --  Fetch raw block via GET /ipfs/<cid>?format=raw (Accept: application/vnd.ipld.raw).
   --  Returns block bytes on HTTP 200, raises Gateway_Error on 404/5xx, Connection_Error on network failure.
   function Fetch_Raw_Block
     (Config   : Gateway_Config;
      Cid_Text : String)
      return Ada.Streams.Stream_Element_Array;

   --  Fetch CAR archive via GET /ipfs/<cid>?format=car (Accept: application/vnd.ipld.car).
   --  Returns CAR bytes on HTTP 200, raises Gateway_Error on 404/5xx, Connection_Error on network failure.
   function Fetch_CAR
     (Config   : Gateway_Config;
      Cid_Text : String)
      return Ada.Streams.Stream_Element_Array;

end IPFS.Gateway;
