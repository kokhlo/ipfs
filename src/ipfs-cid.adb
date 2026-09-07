--  Content Identifier (CID) implementation body.
pragma SPARK_Mode (Off);

with IPFS.Varint;

package body IPFS.CID is

   use type Ada.Streams.Stream_Element;
   use type Ada.Streams.Stream_Element_Offset;
   use type Ada.Streams.Stream_Element_Array;

   V0_Length      : constant := 46;
   V0_Prefix      : constant String := "Qm";
   V0_Binary_Size : constant := 34;
   V0_Hash_Prefix : constant Ada.Streams.Stream_Element := 16#12#;
   V0_Hash_Size   : constant Ada.Streams.Stream_Element := 16#20#;

   -----------
   -- Parse --
   -----------

   function Parse (Text : String) return CID_Type is
      Result : CID_Type;
   begin
      if Text'Length = 0 then
         raise Malformed_CID with "Empty CID string";
      end if;

      --  Check for CIDv0: exactly 46 chars starting with "Qm"
      if Text'Length = V0_Length and then
         Text (Text'First .. Text'First + 1) = V0_Prefix
      then
         --  CIDv0: base58btc encoded, decodes to 34 bytes (0x12 0x20 + 32-byte hash)
         declare
            Raw : constant Ada.Streams.Stream_Element_Array :=
              IPFS.Multibase.Decode ("z" & Text);
         begin
            if Raw'Length /= V0_Binary_Size then
               raise Malformed_CID with
                 "CIDv0 must decode to 34 bytes";
            end if;

            if Raw (Raw'First) /= V0_Hash_Prefix or else
               Raw (Raw'First + 1) /= V0_Hash_Size
            then
               raise Malformed_CID with
                 "CIDv0 must be sha2-256 multihash (0x12 0x20)";
            end if;

            Result.CID_Version := 0;
            Result.CID_Codec := Dag_Pb_Code;
            Result.Binary_Data (1 .. Raw'Length) := Raw;
            Result.Binary_Length := Raw'Length;
            return Result;
         end;
      end if;

      --  CIDv1: multibase-prefixed
      if Text'Length < 2 then
         raise Malformed_CID with "CIDv1 too short";
      end if;

      --  Detect and decode multibase
      declare
         Raw : constant Ada.Streams.Stream_Element_Array :=
           IPFS.Multibase.Decode (Text);
         Offset : Ada.Streams.Stream_Element_Offset := Raw'First;
         Ver : Interfaces.Unsigned_64;
         Codec_Val : Interfaces.Unsigned_64;
         Last : Ada.Streams.Stream_Element_Offset;
      begin
         if Raw'Length < 3 then
            raise Malformed_CID with "CIDv1 binary too short";
         end if;

         --  Decode version varint
         IPFS.Varint.Decode (Raw, Offset, Ver, Last);
         Offset := Last + 1;

         if Ver /= 1 then
            raise Malformed_CID with "Invalid CID version (expected 0 or 1)";
         end if;

         if Offset > Raw'Last then
            raise Malformed_CID with "Missing codec in CIDv1";
         end if;

         --  Decode codec varint
         IPFS.Varint.Decode (Raw, Offset, Codec_Val, Last);
         Offset := Last + 1;

         if Offset > Raw'Last then
            raise Malformed_CID with "Missing multihash in CIDv1";
         end if;

         --  Remaining bytes are the multihash
         Result.CID_Version := 1;
         Result.CID_Codec := Codec_Val;
         Result.Binary_Data (1 .. Raw'Length) := Raw;
         Result.Binary_Length := Raw'Length;

         return Result;
      end;

   exception
      when IPFS.Multibase.Malformed_Encoding =>
         raise Malformed_CID with "Invalid multibase encoding";
      when IPFS.Varint.Malformed_Varint =>
         raise Malformed_CID with "Invalid varint in CIDv1";
   end Parse;

   ---------------
   -- To_String --
   ---------------

   function To_String
     (C    : CID_Type;
      Base : IPFS.Multibase.Base_Type := IPFS.Multibase.Base_32_Lower)
      return String
   is
   begin
      if C.CID_Version = 0 then
         --  CIDv0 always uses base58btc without multibase prefix
         declare
            Encoded : constant String :=
              IPFS.Multibase.Encode
                (IPFS.Multibase.Base_58_BTC,
                 C.Binary_Data (1 .. C.Binary_Length));
         begin
            return Encoded (Encoded'First + 1 .. Encoded'Last);
         end;
      else
         --  CIDv1: use requested base
         return IPFS.Multibase.Encode
           (Base,
            C.Binary_Data (1 .. C.Binary_Length));
      end if;
   end To_String;

   ----------
   -- To_V1 --
   ----------

   function To_V1 (C : CID_Type) return CID_Type is
      Result : CID_Type;
      Offset : Ada.Streams.Stream_Element_Offset := 1;
      Last : Ada.Streams.Stream_Element_Offset;
   begin
      if C.CID_Version = 1 then
         return C;
      end if;

      --  Convert CIDv0 to CIDv1: prefix with varint(1) + varint(dag-pb) + multihash
      IPFS.Varint.Encode (1, Result.Binary_Data, Offset, Last);
      Offset := Last + 1;

      IPFS.Varint.Encode (Dag_Pb_Code, Result.Binary_Data, Offset, Last);
      Offset := Last + 1;

      --  Append original multihash
      Result.Binary_Data (Offset .. Offset + C.Binary_Length - 1) :=
        C.Binary_Data (1 .. C.Binary_Length);
      Result.Binary_Length := Offset + C.Binary_Length - 1;

      Result.CID_Version := 1;
      Result.CID_Codec := Dag_Pb_Code;

      return Result;
   end To_V1;

   ----------
   -- To_V0 --
   ----------

   function To_V0 (C : CID_Type) return CID_Type is
   begin
      if C.CID_Version = 0 then
         return C;
      end if;

      --  CIDv1 -> CIDv0 only valid for dag-pb codec with sha2-256 hash
      if C.CID_Codec /= Dag_Pb_Code then
         raise Constraint_Error with
           "Can only convert dag-pb CIDs to v0";
      end if;

      --  Extract multihash from CIDv1 binary (skip version and codec varints)
      declare
         Offset : Ada.Streams.Stream_Element_Offset := 1;
         Ver : Interfaces.Unsigned_64;
         Codec_Val : Interfaces.Unsigned_64;
         Last : Ada.Streams.Stream_Element_Offset;
         Raw : Ada.Streams.Stream_Element_Array renames C.Binary_Data;
         Result : CID_Type;
      begin
         IPFS.Varint.Decode (Raw, Offset, Ver, Last);
         Offset := Last + 1;

         IPFS.Varint.Decode (Raw, Offset, Codec_Val, Last);
         Offset := Last + 1;

         --  Remaining is multihash
         declare
            Hash_Start : constant Ada.Streams.Stream_Element_Offset := Offset;
            Hash_Len : constant Ada.Streams.Stream_Element_Offset :=
              C.Binary_Length - Offset + 1;
         begin
            --  Verify it's sha2-256 (0x12 0x20)
            if Hash_Len < 2 or else
               Raw (Hash_Start) /= V0_Hash_Prefix or else
               Raw (Hash_Start + 1) /= V0_Hash_Size
            then
               raise Constraint_Error with
                 "Can only convert sha2-256 hashes to CIDv0";
            end if;

            Result.CID_Version := 0;
            Result.CID_Codec := Dag_Pb_Code;
            Result.Binary_Data (1 .. Hash_Len) :=
              Raw (Hash_Start .. C.Binary_Length);
            Result.Binary_Length := Hash_Len;

            return Result;
         end;
      end;
   end To_V0;

   -------------
   -- Version --
   -------------

   function Version (C : CID_Type) return Natural is
   begin
      return C.CID_Version;
   end Version;

   -----------
   -- Codec --
   -----------

   function Codec (C : CID_Type) return Interfaces.Unsigned_64 is
   begin
      return C.CID_Codec;
   end Codec;

   ------------------
   -- Multihash_Of --
   ------------------

   function Multihash_Of (C : CID_Type) return IPFS.Multihash.Hash_Type is
   begin
      if C.CID_Version = 0 then
         --  CIDv0: entire binary is the multihash
         return IPFS.Multihash.Decode
           (C.Binary_Data (1 .. C.Binary_Length));
      else
         --  CIDv1: skip version and codec varints
         declare
            Offset : Ada.Streams.Stream_Element_Offset := 1;
            Ver : Interfaces.Unsigned_64;
            Codec_Val : Interfaces.Unsigned_64;
            Last : Ada.Streams.Stream_Element_Offset;
         begin
            IPFS.Varint.Decode (C.Binary_Data, Offset, Ver, Last);
            Offset := Last + 1;

            IPFS.Varint.Decode (C.Binary_Data, Offset, Codec_Val, Last);
            Offset := Last + 1;

            return IPFS.Multihash.Decode
              (C.Binary_Data (Offset .. C.Binary_Length));
         end;
      end if;
   end Multihash_Of;

   -------------------
   -- From_Multihash --
   -------------------

   function From_Multihash
     (V     : Natural;
      Codec : Interfaces.Unsigned_64;
      H     : IPFS.Multihash.Hash_Type)
      return CID_Type
   is
      Result : CID_Type;
      Hash_Bytes : constant Ada.Streams.Stream_Element_Array :=
        IPFS.Multihash.Encode (IPFS.Multihash.Code (H),
                               IPFS.Multihash.Digest_Of (H));
      Offset : Ada.Streams.Stream_Element_Offset := 1;
      Last : Ada.Streams.Stream_Element_Offset;
   begin
      if V /= 0 and V /= 1 then
         raise Malformed_CID with "Invalid CID version";
      end if;

      Result.CID_Version := V;
      Result.CID_Codec := Codec;

      if V = 0 then
         --  CIDv0: just the multihash bytes
         Result.Binary_Data (1 .. Hash_Bytes'Length) := Hash_Bytes;
         Result.Binary_Length := Hash_Bytes'Length;
      else
         --  CIDv1: varint(version) + varint(codec) + multihash
         IPFS.Varint.Encode (1, Result.Binary_Data, Offset, Last);
         Offset := Last + 1;

         IPFS.Varint.Encode (Codec, Result.Binary_Data, Offset, Last);
         Offset := Last + 1;

         Result.Binary_Data (Offset .. Offset + Hash_Bytes'Length - 1) :=
           Hash_Bytes;
         Result.Binary_Length := Offset + Hash_Bytes'Length - 1;
      end if;

      return Result;
   end From_Multihash;

   --------------
   -- To_Bytes --
   --------------

   function To_Bytes (C : CID_Type) return Ada.Streams.Stream_Element_Array is
   begin
      return C.Binary_Data (1 .. C.Binary_Length);
   end To_Bytes;

   ----------------
   -- From_Bytes --
   ----------------

   function From_Bytes
     (Bytes : Ada.Streams.Stream_Element_Array)
      return CID_Type
   is
      Result : CID_Type;
   begin
      if Bytes'Length = 0 then
         raise Malformed_CID with "Empty byte array";
      end if;

      if Bytes'Length > 128 then
         raise Malformed_CID with "CID binary too large";
      end if;

      --  Check if CIDv0 (starts with 0x12 0x20)
      if Bytes'Length = V0_Binary_Size and then
         Bytes (Bytes'First) = V0_Hash_Prefix and then
         Bytes (Bytes'First + 1) = V0_Hash_Size
      then
         Result.CID_Version := 0;
         Result.CID_Codec := Dag_Pb_Code;
         Result.Binary_Data (1 .. Bytes'Length) := Bytes;
         Result.Binary_Length := Bytes'Length;
         return Result;
      end if;

      --  Otherwise try CIDv1
      declare
         Offset : Ada.Streams.Stream_Element_Offset := Bytes'First;
         Ver : Interfaces.Unsigned_64;
         Codec_Val : Interfaces.Unsigned_64;
         Last : Ada.Streams.Stream_Element_Offset;
      begin
         IPFS.Varint.Decode (Bytes, Offset, Ver, Last);
         Offset := Last + 1;

         if Ver /= 1 then
            raise Malformed_CID with "Invalid CID version in bytes";
         end if;

         if Offset > Bytes'Last then
            raise Malformed_CID with "Missing codec in CIDv1 bytes";
         end if;

         IPFS.Varint.Decode (Bytes, Offset, Codec_Val, Last);

         Result.CID_Version := 1;
         Result.CID_Codec := Codec_Val;
         Result.Binary_Data (1 .. Bytes'Length) := Bytes;
         Result.Binary_Length := Bytes'Length;

         return Result;
      end;

   exception
      when IPFS.Varint.Malformed_Varint =>
         raise Malformed_CID with "Invalid varint in CID bytes";
   end From_Bytes;

   ------------
   -- Equals --
   ------------

   function Equals (L, R : CID_Type) return Boolean is
   begin
      if L.CID_Version /= R.CID_Version or else
         L.CID_Codec /= R.CID_Codec or else
         L.Binary_Length /= R.Binary_Length
      then
         return False;
      end if;

      return L.Binary_Data (1 .. L.Binary_Length) =
             R.Binary_Data (1 .. R.Binary_Length);
   end Equals;

end IPFS.CID;
