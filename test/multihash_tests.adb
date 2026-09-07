--  Multihash test suite implementation.
with Ada.Text_IO;
with Ada.Streams;
with Interfaces;
with IPFS.Multihash;

package body Multihash_Tests is

   use type Ada.Streams.Stream_Element;
   use type Ada.Streams.Stream_Element_Offset;
   use type Interfaces.Unsigned_64;

   Tests_Run    : Natural := 0;
   Tests_Passed : Natural := 0;

   procedure Assert (Condition : Boolean; Name : String) is
   begin
      Tests_Run := Tests_Run + 1;
      if Condition then
         Tests_Passed := Tests_Passed + 1;
      else
         Ada.Text_IO.Put_Line ("FAIL: " & Name);
      end if;
   end Assert;

   procedure Test_Encode_Decode_Roundtrip is
      Test_Cases : constant array (1 .. 5) of Natural := [0, 1, 32, 64, 128];
   begin
      for Len of Test_Cases loop
         declare
            Digest : Ada.Streams.Stream_Element_Array (1 .. Ada.Streams.Stream_Element_Offset (Len));
         begin
            for I in Digest'Range loop
               Digest (I) := Ada.Streams.Stream_Element (I mod 256);
            end loop;
            
            declare
               Encoded : constant Ada.Streams.Stream_Element_Array := IPFS.Multihash.Encode (16#12#, Digest);
               H : constant IPFS.Multihash.Hash_Type := IPFS.Multihash.Decode (Encoded);
               Decoded : constant Ada.Streams.Stream_Element_Array := IPFS.Multihash.Digest_Of (H);
            begin
               Assert (IPFS.Multihash.Code (H) = 16#12#, "Round-trip code len=" & Natural'Image (Len));
               Assert (Decoded'Length = Digest'Length, "Round-trip length len=" & Natural'Image (Len));
               
               declare
                  Match : Boolean := True;
               begin
                  for I in Digest'Range loop
                     if Decoded (Decoded'First + I - Digest'First) /= Digest (I) then
                        Match := False;
                        exit;
                     end if;
                  end loop;
                  Assert (Match, "Round-trip digest len=" & Natural'Image (Len));
               end;
            end;
         end;
      end loop;
   end Test_Encode_Decode_Roundtrip;

   procedure Test_Reject_Empty is
      Empty : Ada.Streams.Stream_Element_Array (1 .. 0);
      Rejected : Boolean := False;
      pragma Warnings (Off);
      H : IPFS.Multihash.Hash_Type;
      pragma Warnings (On);
      pragma Unreferenced (H);
   begin
      begin
         H := IPFS.Multihash.Decode (Empty);
      exception
         when IPFS.Multihash.Malformed_Multihash =>
            Rejected := True;
      end;
      Assert (Rejected, "Reject empty");
   end Test_Reject_Empty;

   procedure Test_Reject_Code_Only is
      Code_Only : constant Ada.Streams.Stream_Element_Array := [1 => 16#12#];
      Rejected : Boolean := False;
      pragma Warnings (Off);
      H : IPFS.Multihash.Hash_Type;
      pragma Warnings (On);
      pragma Unreferenced (H);
   begin
      begin
         H := IPFS.Multihash.Decode (Code_Only);
      exception
         when IPFS.Multihash.Malformed_Multihash =>
            Rejected := True;
      end;
      Assert (Rejected, "Reject code without length");
   end Test_Reject_Code_Only;

   procedure Test_Reject_Truncated is
      Truncated : constant Ada.Streams.Stream_Element_Array := [16#12#, 16#05#, 16#AA#];
      Rejected : Boolean := False;
      pragma Warnings (Off);
      H : IPFS.Multihash.Hash_Type;
      pragma Warnings (On);
      pragma Unreferenced (H);
   begin
      begin
         H := IPFS.Multihash.Decode (Truncated);
      exception
         when IPFS.Multihash.Malformed_Multihash =>
            Rejected := True;
      end;
      Assert (Rejected, "Reject truncated digest");
   end Test_Reject_Truncated;

   procedure Test_Sha2_256_Empty is
      Empty : Ada.Streams.Stream_Element_Array (1 .. 0);
      Hash : constant Ada.Streams.Stream_Element_Array := IPFS.Multihash.Sha2_256 (Empty);
   begin
      Assert (Hash'Length = 34, "Sha2_256 empty length");
      Assert (Hash (Hash'First) = 16#12#, "Sha2_256 empty code");
      Assert (Hash (Hash'First + 1) = 16#20#, "Sha2_256 empty digest length");
      
      declare
         H : constant IPFS.Multihash.Hash_Type := IPFS.Multihash.Decode (Hash);
      begin
         Assert (IPFS.Multihash.Code (H) = 16#12#, "Sha2_256 empty decoded code");
         Assert (IPFS.Multihash.Digest_Of (H)'Length = 32, "Sha2_256 empty decoded length");
      end;
   end Test_Sha2_256_Empty;

   procedure Test_Verify_Positive is
      Data : constant Ada.Streams.Stream_Element_Array := [16#AA#, 16#BB#, 16#CC#];
      Hash : constant Ada.Streams.Stream_Element_Array := IPFS.Multihash.Sha2_256 (Data);
   begin
      Assert (IPFS.Multihash.Verify (Data, Hash), "Verify positive");
   end Test_Verify_Positive;

   procedure Test_Verify_Negative is
      Data : constant Ada.Streams.Stream_Element_Array := [16#AA#, 16#BB#, 16#CC#];
      Hash : Ada.Streams.Stream_Element_Array := IPFS.Multihash.Sha2_256 (Data);
   begin
      Hash (Hash'Last) := Hash (Hash'Last) xor 16#01#;
      Assert (not IPFS.Multihash.Verify (Data, Hash), "Verify negative");
   end Test_Verify_Negative;

   procedure Test_Verify_Identity is
      Data : constant Ada.Streams.Stream_Element_Array := [16#DE#, 16#AD#, 16#BE#, 16#EF#];
      Hash : constant Ada.Streams.Stream_Element_Array := IPFS.Multihash.Encode (IPFS.Multihash.Identity_Code, Data);
   begin
      Assert (IPFS.Multihash.Verify (Data, Hash), "Verify identity positive");
      
      declare
         Wrong_Data : constant Ada.Streams.Stream_Element_Array := [16#DE#, 16#AD#, 16#BE#, 16#FF#];
      begin
         Assert (not IPFS.Multihash.Verify (Wrong_Data, Hash), "Verify identity negative");
      end;
   end Test_Verify_Identity;

   procedure Test_Verify_Unsupported_Code is
      Data : constant Ada.Streams.Stream_Element_Array := [16#AA#, 16#BB#];
      Digest : constant Ada.Streams.Stream_Element_Array := [16#11#, 16#22#];
      Hash : constant Ada.Streams.Stream_Element_Array := IPFS.Multihash.Encode (16#99#, Digest);
   begin
      Assert (not IPFS.Multihash.Verify (Data, Hash), "Verify unsupported code");
   end Test_Verify_Unsupported_Code;

   procedure Run is
   begin
      Tests_Run := 0;
      Tests_Passed := 0;

      Test_Encode_Decode_Roundtrip;
      Test_Reject_Empty;
      Test_Reject_Code_Only;
      Test_Reject_Truncated;
      Test_Sha2_256_Empty;
      Test_Verify_Positive;
      Test_Verify_Negative;
      Test_Verify_Identity;
      Test_Verify_Unsupported_Code;

      Ada.Text_IO.Put_Line ("Multihash tests:" & Natural'Image (Tests_Run) & " run," & Natural'Image (Tests_Passed) & " passed");
   end Run;

end Multihash_Tests;
