--  CID test suite implementation
pragma SPARK_Mode (Off);

with Ada.Text_IO;
with IPFS.CID;
with IPFS.Multibase;
with Interfaces;

package body CID_Tests is

   use Ada.Text_IO;
   use IPFS.CID;
   use type Interfaces.Unsigned_64;

   Tests_Run    : Natural := 0;
   Tests_Passed : Natural := 0;

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      Tests_Run := Tests_Run + 1;
      if Condition then
         Tests_Passed := Tests_Passed + 1;
      else
         Put_Line ("FAIL: " & Message);
      end if;
   end Assert;

   procedure Test_CID_Constants is
      pragma Warnings (Off, "condition is always *");
   begin
      Assert (Raw_Code = 16#55#, "Raw codec constant");
      Assert (Dag_Pb_Code = 16#70#, "Dag-pb codec constant");
      pragma Warnings (On, "condition is always *");
   exception
      when others =>
         Assert (False, "CID constants test raised exception");
   end Test_CID_Constants;

   procedure Test_Parse_CIDv1_Raw is
      Text : constant String :=
        "bafkreiexwmlay7yehnir7u554rrpgtxtc4lnlxxggwhpvdemykfsmw2xqi";
      C : CID_Type;
   begin
      C := Parse (Text);
      Assert (Version (C) = 1, "CIDv1 raw version");
      Assert (Codec (C) = Raw_Code, "CIDv1 raw codec = 0x55");
   exception
      when others =>
         Assert (False, "Parse CIDv1 raw raised exception");
   end Test_Parse_CIDv1_Raw;

   procedure Test_Round_Trip_CIDv1_Raw is
      Text : constant String :=
        "bafkreiexwmlay7yehnir7u554rrpgtxtc4lnlxxggwhpvdemykfsmw2xqi";
      C : CID_Type;
   begin
      C := Parse (Text);
      declare
         Result : constant String := To_String (C);
      begin
         Assert (Result = Text, "CIDv1 raw round-trip exact");
      end;
   exception
      when others =>
         Assert (False, "CIDv1 raw round-trip raised exception");
   end Test_Round_Trip_CIDv1_Raw;

   procedure Test_Parse_CIDv0 is
      Text : constant String :=
        "QmarWQsVmm85BgiJxB3GkgegSzJuqyEXAhAWPxQUmWvEGQ";
      C : CID_Type;
   begin
      C := Parse (Text);
      Assert (Version (C) = 0, "CIDv0 version = 0");
      Assert (Codec (C) = Dag_Pb_Code, "CIDv0 codec = dag-pb");
   exception
      when others =>
         Assert (False, "Parse CIDv0 raised exception");
   end Test_Parse_CIDv0;

   procedure Test_CIDv0_To_V1 is
      Text : constant String :=
        "QmarWQsVmm85BgiJxB3GkgegSzJuqyEXAhAWPxQUmWvEGQ";
      C  : CID_Type;
      C1 : CID_Type;
   begin
      C := Parse (Text);
      C1 := To_V1 (C);
      Assert (Version (C1) = 1, "To_V1 converts to version 1");
      declare
         Result : constant String := To_String (C1);
      begin
         Assert (Result'Length >= 4, "CIDv1 string not empty");
         Assert (Result (Result'First .. Result'First + 3) = "bafy",
                 "CIDv1 dag-pb starts with 'bafy' (base32 + dag-pb)");
      end;
   exception
      when others =>
         Assert (False, "CIDv0 to v1 raised exception");
   end Test_CIDv0_To_V1;

   procedure Test_CIDv0_Round_Trip is
      Text    : constant String :=
        "QmarWQsVmm85BgiJxB3GkgegSzJuqyEXAhAWPxQUmWvEGQ";
      C       : CID_Type;
      C1      : CID_Type;
      C0_Back : CID_Type;
   begin
      C := Parse (Text);
      C1 := To_V1 (C);
      C0_Back := To_V0 (C1);
      Assert (Version (C0_Back) = 0, "To_V0 round-trip back to v0");
      declare
         use IPFS.Multibase;
         Result : constant String := To_String (C0_Back, Base_58_BTC);
      begin
         Assert (Result = Text, "CIDv0 round-trip preserves exact value");
      end;
   exception
      when others =>
         Assert (False, "CIDv0 round-trip raised exception");
   end Test_CIDv0_Round_Trip;

   procedure Test_Parse_CIDv1_Dag_Pb is
      Text : constant String :=
        "bafybeiboykq3jz7gmjduzzcqde5xai4gtcroypzzogmemqmxcgaa3gfyg4";
      C : CID_Type;
   begin
      C := Parse (Text);
      Assert (Version (C) = 1, "CIDv1 dag-pb version = 1");
      Assert (Codec (C) = Dag_Pb_Code, "CIDv1 dag-pb codec = 0x70");
   exception
      when others =>
         Assert (False, "Parse CIDv1 dag-pb raised exception");
   end Test_Parse_CIDv1_Dag_Pb;

   procedure Test_Reject_Empty_String is
      C : CID_Type;
      pragma Unreferenced (C);
   begin
      C := Parse ("");
      Assert (False, "Should reject empty string");
   exception
      when Malformed_CID =>
         Assert (True, "Rejects empty string with Malformed_CID");
      when others =>
         Assert (False, "Wrong exception for empty string");
   end Test_Reject_Empty_String;

   procedure Test_Reject_Short_Qm is
      Text : constant String :=
        "QmarWQsVmm85BgiJxB3GkgegSzJuqyEXAhAWPxQUmWvEG";
      C : CID_Type;
      pragma Unreferenced (C);
   begin
      C := Parse (Text);
      Assert (False, "Should reject 45-char Qm string (v0 must be 46)");
   exception
      when Malformed_CID =>
         Assert (True, "Rejects short Qm string");
      when others =>
         Assert (False, "Wrong exception for short Qm");
   end Test_Reject_Short_Qm;

   procedure Test_Equals is
      Text1 : constant String :=
        "QmarWQsVmm85BgiJxB3GkgegSzJuqyEXAhAWPxQUmWvEGQ";
      Text2 : constant String :=
        "bafkreiexwmlay7yehnir7u554rrpgtxtc4lnlxxggwhpvdemykfsmw2xqi";
      C1     : constant CID_Type := Parse (Text1);
      C1_Dup : constant CID_Type := Parse (Text1);
      C2     : constant CID_Type := Parse (Text2);
   begin
      Assert (C1 = C1_Dup, "Equal CIDs match (operator =)");
      Assert (not (C1 = C2), "Different CIDs don't match");
   exception
      when others =>
         Assert (False, "Equals test raised exception");
   end Test_Equals;

   procedure Test_To_V0_Non_Dag_Pb is
      Text : constant String :=
        "bafkreiexwmlay7yehnir7u554rrpgtxtc4lnlxxggwhpvdemykfsmw2xqi";
      C  : constant CID_Type := Parse (Text);
      C0 : CID_Type;
      pragma Unreferenced (C0);
   begin
      C0 := To_V0 (C);
      Assert (False, "Should reject raw codec to v0");
   exception
      when Constraint_Error =>
         Assert (True, "Rejects non-dag-pb codec when converting to v0");
      when others =>
         Assert (False, "Wrong exception for raw codec to v0");
   end Test_To_V0_Non_Dag_Pb;

   procedure Run is
   begin
      Tests_Run := 0;
      Tests_Passed := 0;

      Test_CID_Constants;
      Test_Parse_CIDv1_Raw;
      Test_Round_Trip_CIDv1_Raw;
      Test_Parse_CIDv0;
      Test_CIDv0_To_V1;
      Test_CIDv0_Round_Trip;
      Test_Parse_CIDv1_Dag_Pb;
      Test_Reject_Empty_String;
      Test_Reject_Short_Qm;
      Test_Equals;
      Test_To_V0_Non_Dag_Pb;

      Put_Line ("CID tests:" & Tests_Run'Image & " run," &
                Tests_Passed'Image & " passed");
   end Run;

end CID_Tests;
