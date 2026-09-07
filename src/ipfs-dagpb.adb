--  DAG-PB codec implementation.
pragma SPARK_Mode;

with IPFS.Varint;

package body IPFS.DagPB is

   use type Interfaces.Unsigned_64;
   use type Interfaces.Unsigned_8;

   --  Decode a Link message (field 1=Hash, field 2=Name, field 3=Tsize).
   procedure Decode_Link
     (Bytes  :     Ada.Streams.Stream_Element_Array;
      Link   : out Link_Type;
      Last   : out Ada.Streams.Stream_Element_Offset)
   is
      I     : Ada.Streams.Stream_Element_Offset := Bytes'First;
      Tag   : Interfaces.Unsigned_8;
      Field : Natural;
      Wire  : Natural;
      Len   : Ada.Streams.Stream_Element_Offset;
      Val   : Interfaces.Unsigned_64;
      VLast : Ada.Streams.Stream_Element_Offset;
   begin
      Link.Name_Len := 0;
      Link.Hash_Len := 0;
      Link.Tsize    := 0;

      while I <= Bytes'Last loop
         Tag   := Interfaces.Unsigned_8 (Bytes (I));
         Field := Natural (Interfaces.Shift_Right (Tag, 3));
         Wire  := Natural (Tag and 16#07#);
         I     := I + 1;

         case Wire is
            when 0 =>  --  Varint
               IPFS.Varint.Decode (Bytes, I, Val, VLast);
               I := VLast + 1;
               if Field = 3 then
                  Link.Tsize := Val;
               end if;

            when 2 =>  --  Length-delimited
               IPFS.Varint.Decode (Bytes, I, Val, VLast);
               Len := Ada.Streams.Stream_Element_Offset (Val);
               I   := VLast + 1;

               if Field = 1 then  --  Hash
                  if Len > Ada.Streams.Stream_Element_Offset (Link.Hash'Length) then
                     raise Malformed_DagPB with "Link Hash too long";
                  end if;
                  declare
                     Hash_Last : constant Ada.Streams.Stream_Element_Offset := Link.Hash'First + Len - 1;
                  begin
                     Link.Hash (Link.Hash'First .. Hash_Last) := Bytes (I .. I + Len - 1);
                     Link.Hash_Len := Natural (Len);
                  end;

               elsif Field = 2 then  --  Name
                  if Len > Ada.Streams.Stream_Element_Offset (Max_Name_Length) then
                     raise Malformed_DagPB with "Link Name too long";
                  end if;
                  for J in 0 .. Len - 1 loop
                     Link.Name (Natural (J) + 1) :=
                       Character'Val (Bytes (I + J));
                  end loop;
                  Link.Name_Len := Natural (Len);
               end if;

               I := I + Len;

            when 1 | 5 =>  --  Fixed64 / Fixed32: skip
               if Wire = 1 then
                  I := I + 8;
               else
                  I := I + 4;
               end if;

            when others =>
               raise Malformed_DagPB with "Unknown wire type in Link";
         end case;
      end loop;

      Last := I - 1;
   end Decode_Link;

   ------------
   --  Decode --
   ------------

   function Decode
     (Bytes : Ada.Streams.Stream_Element_Array)
      return Node_Type
   is
      Node  : Node_Type;
      I     : Ada.Streams.Stream_Element_Offset := Bytes'First;
      Tag   : Interfaces.Unsigned_8;
      Field : Natural;
      Wire  : Natural;
      Len   : Ada.Streams.Stream_Element_Offset;
      Val   : Interfaces.Unsigned_64;
      VLast : Ada.Streams.Stream_Element_Offset;
      Link  : Link_Type;
      LLast : Ada.Streams.Stream_Element_Offset;
   begin
      Node.Links_Count := 0;
      Node.Data_Len    := 0;

      while I <= Bytes'Last loop
         Tag   := Interfaces.Unsigned_8 (Bytes (I));
         Field := Natural (Interfaces.Shift_Right (Tag, 3));
         Wire  := Natural (Tag and 16#07#);
         I     := I + 1;

         case Wire is
            when 0 =>  --  Varint (skip unknown fields)
               IPFS.Varint.Decode (Bytes, I, Val, VLast);
               I := VLast + 1;

            when 2 =>  --  Length-delimited
               IPFS.Varint.Decode (Bytes, I, Val, VLast);
               Len := Ada.Streams.Stream_Element_Offset (Val);
               I   := VLast + 1;

               if Field = 1 then  --  Data
                  if Len > Ada.Streams.Stream_Element_Offset (Max_Data_Length) then
                     raise Malformed_DagPB with "Data field too long";
                  end if;
                  declare
                     Data_Last : constant Ada.Streams.Stream_Element_Offset := Node.Data'First + Len - 1;
                  begin
                     Node.Data (Node.Data'First .. Data_Last) := Bytes (I .. I + Len - 1);
                     Node.Data_Len := Natural (Len);
                  end;

               elsif Field = 2 then  --  Link
                  if Node.Links_Count >= Max_Links then
                     raise Malformed_DagPB with "Too many links";
                  end if;
                  Decode_Link (Bytes (I .. I + Len - 1), Link, LLast);
                  Node.Links_Count                 := Node.Links_Count + 1;
                  Node.Links (Node.Links_Count) := Link;
               end if;

               I := I + Len;

            when 1 | 5 =>  --  Fixed64 / Fixed32: skip
               if Wire = 1 then
                  I := I + 8;
               else
                  I := I + 4;
               end if;

            when others =>
               raise Malformed_DagPB with "Unknown wire type";
         end case;
      end loop;

      return Node;
   end Decode;

end IPFS.DagPB;
