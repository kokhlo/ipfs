--  UnixFS codec implementation.
pragma SPARK_Mode;

with IPFS.Varint;

package body IPFS.UnixFS is

   use type Interfaces.Unsigned_64;
   use type Interfaces.Unsigned_8;

   -----------------
   --  Decode_Data --
   -----------------

   function Decode_Data
     (Block_Bytes : Ada.Streams.Stream_Element_Array)
      return Data_Type
   is
      Result : Data_Type;
      I      : Ada.Streams.Stream_Element_Offset := Block_Bytes'First;
      Tag    : Interfaces.Unsigned_8;
      Field  : Natural;
      Wire   : Natural;
      Val    : Interfaces.Unsigned_64;
      VLast  : Ada.Streams.Stream_Element_Offset;
      Len    : Ada.Streams.Stream_Element_Offset;
   begin
      Result.Format           := Raw;
      Result.FileSize         := 0;
      Result.Blocksizes_Count := 0;

      while I <= Block_Bytes'Last loop
         Tag   := Interfaces.Unsigned_8 (Block_Bytes (I));
         Field := Natural (Interfaces.Shift_Right (Tag, 3));
         Wire  := Natural (Tag and 16#07#);
         I     := I + 1;

         case Wire is
            when 0 =>  --  Varint
               IPFS.Varint.Decode (Block_Bytes, I, Val, VLast);
               I := VLast + 1;

               if Field = 1 then  --  Type
                  case Val is
                     when 0 =>
                        Result.Format := Raw;
                     when 1 =>
                        Result.Format := Directory;
                     when 2 =>
                        Result.Format := File;
                     when 3 =>
                        Result.Format := Metadata;
                     when 4 =>
                        Result.Format := Symlink;
                     when 5 =>
                        Result.Format := HAMT_Shard;
                     when others =>
                        raise Malformed_UnixFS with "Unknown UnixFS type";
                  end case;

               elsif Field = 3 then  --  FileSize
                  Result.FileSize := Val;

               elsif Field = 4 then  --  BlockSizes (repeated)
                  if Result.Blocksizes_Count >= Max_Blocksizes then
                     raise Malformed_UnixFS with "Too many blocksizes";
                  end if;
                  Result.Blocksizes_Count := Result.Blocksizes_Count + 1;
                  Result.Blocksizes (Result.Blocksizes_Count) := Val;
               end if;

            when 2 =>  --  Length-delimited (field 2 = Data, or unknown)
               IPFS.Varint.Decode (Block_Bytes, I, Val, VLast);
               Len := Ada.Streams.Stream_Element_Offset (Val);
               I   := VLast + 1;
               --  Skip Data field (we don't store embedded file content here)
               I := I + Len;

            when 1 | 5 =>  --  Fixed: skip
               I := I + (if Wire = 1 then 8 else 4);

            when others =>
               raise Malformed_UnixFS with "Unknown wire type";
         end case;
      end loop;

      return Result;
   end Decode_Data;

   -------------
   --  Is_File --
   -------------

   function Is_File (N : IPFS.DagPB.Node_Type) return Boolean is
      D : Data_Type;
   begin
      if N.Data_Len = 0 then
         return False;
      end if;
      declare
         Data_Last : constant Ada.Streams.Stream_Element_Offset := N.Data'First + Ada.Streams.Stream_Element_Offset (N.Data_Len) - 1;
      begin
         D := Decode_Data (N.Data (N.Data'First .. Data_Last));
         return D.Format = File or else D.Format = Raw;
      end;
   end Is_File;

   ---------------
   --  File_Data --
   ---------------

   function File_Data
     (N : IPFS.DagPB.Node_Type)
      return Ada.Streams.Stream_Element_Array
   is
      I     : Ada.Streams.Stream_Element_Offset := 1;
      Tag   : Interfaces.Unsigned_8;
      Field : Natural;
      Wire  : Natural;
      Val   : Interfaces.Unsigned_64;
      VLast : Ada.Streams.Stream_Element_Offset;
      Len   : Ada.Streams.Stream_Element_Offset;
      D     : Data_Type;
   begin
      if N.Links_Count > 0 then
         raise Malformed_UnixFS with "Not a single-block file (has links)";
      end if;

      if N.Data_Len = 0 then
         raise Malformed_UnixFS with "Empty Data field";
      end if;

      declare
         Data_Last : constant Ada.Streams.Stream_Element_Offset := N.Data'First + Ada.Streams.Stream_Element_Offset (N.Data_Len) - 1;
      begin
         D := Decode_Data (N.Data (N.Data'First .. Data_Last));
         if D.Format /= File and then D.Format /= Raw then
            raise Malformed_UnixFS with "Not a file type";
         end if;
      end;

      --  Re-parse to extract field 2 (Data bytes)
      while I <= Ada.Streams.Stream_Element_Offset (N.Data_Len) loop
         Tag   := Interfaces.Unsigned_8 (N.Data (I));
         Field := Natural (Interfaces.Shift_Right (Tag, 3));
         Wire  := Natural (Tag and 16#07#);
         I     := I + 1;

         if Wire = 2 then
            declare
               Data_Last : constant Ada.Streams.Stream_Element_Offset := N.Data'First + Ada.Streams.Stream_Element_Offset (N.Data_Len) - 1;
            begin
               IPFS.Varint.Decode (N.Data (N.Data'First .. Data_Last), I, Val, VLast);
            end;
            Len := Ada.Streams.Stream_Element_Offset (Val);
            I   := VLast + 1;

            if Field = 2 then  --  Data
               return N.Data (I .. I + Len - 1);
            end if;

            I := I + Len;

         elsif Wire = 0 then
            declare
               Data_Last : constant Ada.Streams.Stream_Element_Offset := N.Data'First + Ada.Streams.Stream_Element_Offset (N.Data_Len) - 1;
            begin
               IPFS.Varint.Decode (N.Data (N.Data'First .. Data_Last), I, Val, VLast);
            end;
            I := VLast + 1;

         elsif Wire = 1 then
            I := I + 8;

         elsif Wire = 5 then
            I := I + 4;
         end if;
      end loop;

      raise Malformed_UnixFS with "No Data field in UnixFS";
   end File_Data;

   ----------------
   --  Link_Count --
   ----------------

   function Link_Count (N : IPFS.DagPB.Node_Type) return Natural is
   begin
      return N.Links_Count;
   end Link_Count;

   ---------------
   --  Link_Name --
   ---------------

   function Link_Name
     (N : IPFS.DagPB.Node_Type; Index : Positive)
      return String
   is
   begin
      if Index > N.Links_Count then
         raise Constraint_Error with "Link index out of bounds";
      end if;
      return N.Links (Index).Name (1 .. N.Links (Index).Name_Len);
   end Link_Name;

   ---------------
   --  Link_Hash --
   ---------------

   function Link_Hash
     (N : IPFS.DagPB.Node_Type; Index : Positive)
      return Ada.Streams.Stream_Element_Array
   is
   begin
      if Index > N.Links_Count then
         raise Constraint_Error with "Link index out of bounds";
      end if;
      declare
         Hash_Last : constant Ada.Streams.Stream_Element_Offset := N.Links (Index).Hash'First + Ada.Streams.Stream_Element_Offset (N.Links (Index).Hash_Len) - 1;
      begin
         return N.Links (Index).Hash (N.Links (Index).Hash'First .. Hash_Last);
      end;
   end Link_Hash;

end IPFS.UnixFS;
