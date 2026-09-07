--  Multihash implementation.
pragma SPARK_Mode;

with IPFS.Varint;
with IPFS.SHA256;

package body IPFS.Multihash is

   use type Interfaces.Unsigned_64;
   use type Ada.Streams.Stream_Element;

   function Encode
     (Code   : Interfaces.Unsigned_64;
      Digest : Ada.Streams.Stream_Element_Array)
      return Ada.Streams.Stream_Element_Array
   is
      Code_Len   : constant Positive := Varint.Encoded_Length (Code);
      Digest_Len_Val : constant Interfaces.Unsigned_64 :=
        Interfaces.Unsigned_64 (Digest'Length);
      Length_Len : constant Positive := Varint.Encoded_Length (Digest_Len_Val);
      Total_Len  : constant Positive := Code_Len + Length_Len + Digest'Length;
      Buffer     : Ada.Streams.Stream_Element_Array (1 .. Ada.Streams.Stream_Element_Offset (Total_Len));
      Last       : Ada.Streams.Stream_Element_Offset;
   begin
      --  Encode code varint.
      Varint.Encode (Code, Buffer, 1, Last);
      
      --  Encode length varint.
      declare
         Length_Start : constant Ada.Streams.Stream_Element_Offset := Last + 1;
      begin
         Varint.Encode (Digest_Len_Val, Buffer, Length_Start, Last);
      end;
      
      --  Copy digest bytes.
      declare
         Digest_Start : constant Ada.Streams.Stream_Element_Offset := Last + 1;
      begin
         Buffer (Digest_Start .. Digest_Start + Digest'Length - 1) := Digest;
      end;
      
      return Buffer;
   end Encode;

   function Decode
     (Bytes : Ada.Streams.Stream_Element_Array)
      return Hash_Type
   is
      Code_Val    : Interfaces.Unsigned_64;
      Length_Val  : Interfaces.Unsigned_64;
      Last        : Ada.Streams.Stream_Element_Offset;
      Digest_Start : Ada.Streams.Stream_Element_Offset;
      Digest_End  : Ada.Streams.Stream_Element_Offset;
      Result      : Hash_Type;
   begin
      if Bytes'Length = 0 then
         raise Malformed_Multihash with "Empty multihash";
      end if;

      --  Decode code varint.
      begin
         Varint.Decode (Bytes, Bytes'First, Code_Val, Last);
      exception
         when Varint.Malformed_Varint =>
            raise Malformed_Multihash with "Invalid code varint";
      end;

      --  Decode length varint.
      if Last >= Bytes'Last then
         raise Malformed_Multihash with "Missing length field";
      end if;

      begin
         Varint.Decode (Bytes, Last + 1, Length_Val, Last);
      exception
         when Varint.Malformed_Varint =>
            raise Malformed_Multihash with "Invalid length varint";
      end;

      --  Validate digest length.
      if Length_Val > Interfaces.Unsigned_64 (Max_Digest_Length) then
         raise Malformed_Multihash with "Digest length exceeds maximum";
      end if;

      Digest_Start := Last + 1;
      Digest_End := Digest_Start + Ada.Streams.Stream_Element_Offset (Length_Val) - 1;

      if Digest_End > Bytes'Last then
         raise Malformed_Multihash with "Truncated digest";
      end if;

      if Digest_End /= Bytes'Last then
         raise Malformed_Multihash with "Trailing bytes after digest";
      end if;

      --  Populate result.
      Result.Hash_Code := Code_Val;
      Result.Digest_Length := Natural (Length_Val);
      
      for I in 1 .. Result.Digest_Length loop
         Result.Digest_Data (I) := Bytes (Digest_Start + Ada.Streams.Stream_Element_Offset (I - 1));
      end loop;

      return Result;
   end Decode;

   function Code (H : Hash_Type) return Interfaces.Unsigned_64 is
   begin
      return H.Hash_Code;
   end Code;

   function Digest_Of (H : Hash_Type) return Ada.Streams.Stream_Element_Array is
      Result : Ada.Streams.Stream_Element_Array (1 .. Ada.Streams.Stream_Element_Offset (H.Digest_Length));
   begin
      for I in Result'Range loop
         Result (I) := H.Digest_Data (Integer (I));
      end loop;
      return Result;
   end Digest_Of;

   function Sha2_256
     (Data : Ada.Streams.Stream_Element_Array)
      return Ada.Streams.Stream_Element_Array
   is
      Digest : constant Ada.Streams.Stream_Element_Array := SHA256.Digest (Data);
   begin
      return Encode (Sha2_256_Code, Digest);
   end Sha2_256;

   function Verify
     (Data       : Ada.Streams.Stream_Element_Array;
      Hash_Bytes : Ada.Streams.Stream_Element_Array)
      return Boolean
   is
      H : Hash_Type;
   begin
      begin
         H := Decode (Hash_Bytes);
      exception
         when Malformed_Multihash =>
            return False;
      end;

      if H.Hash_Code = Sha2_256_Code then
         declare
            Computed : constant Ada.Streams.Stream_Element_Array := SHA256.Digest (Data);
            Stored   : constant Ada.Streams.Stream_Element_Array := Digest_Of (H);
         begin
            if Computed'Length /= Stored'Length then
               return False;
            end if;
            for I in Computed'Range loop
               if Computed (I) /= Stored (I - Computed'First + Stored'First) then
                  return False;
               end if;
            end loop;
            return True;
         end;
      elsif H.Hash_Code = Identity_Code then
         declare
            Stored : constant Ada.Streams.Stream_Element_Array := Digest_Of (H);
         begin
            if Data'Length /= Stored'Length then
               return False;
            end if;
            for I in Data'Range loop
               if Data (I) /= Stored (I - Data'First + Stored'First) then
                  return False;
               end if;
            end loop;
            return True;
         end;
      else
         return False;
      end if;
   end Verify;

end IPFS.Multihash;
