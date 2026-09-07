--  Unsigned varint codec (multiformats/unsigned-varint spec).
pragma SPARK_Mode;

package body IPFS.Varint is

   use type Interfaces.Unsigned_64;
   use type Interfaces.Unsigned_8;

   -------------
   --  Encode  --
   -------------

   procedure Encode
     (Value  :     Interfaces.Unsigned_64;
      Buffer : in out Ada.Streams.Stream_Element_Array;
      Offset :     Ada.Streams.Stream_Element_Offset := 1;
      Last   :    out Ada.Streams.Stream_Element_Offset)
   is
      V : Interfaces.Unsigned_64 := Value;
      I : Ada.Streams.Stream_Element_Offset := Offset;
      B : Interfaces.Unsigned_8;
   begin
      loop
         B := (if V >= 128
                 then Interfaces.Unsigned_8 (V and 16#7F#) or 16#80#
                 else Interfaces.Unsigned_8 (V));
         Buffer (I) := Ada.Streams.Stream_Element (B);
         V := Interfaces.Shift_Right (V, 7);
         exit when V = 0;
         I := I + 1;
      end loop;
      Last := I;
   end Encode;

   -------------
   --  Decode  --
   -------------

   procedure Decode
     (Buffer :     Ada.Streams.Stream_Element_Array;
      Offset :     Ada.Streams.Stream_Element_Offset;
      Value  :    out Interfaces.Unsigned_64;
      Last   :    out Ada.Streams.Stream_Element_Offset)
   is
      Result : Interfaces.Unsigned_64 := 0;
      Shift  : Natural := 0;
      I      : Ada.Streams.Stream_Element_Offset := Offset;
      B      : Interfaces.Unsigned_8;
      Done   : Boolean := False;
   begin
      Value := 0;
      Last  := Offset;
      while not Done loop
         if I > Buffer'Last
           or else I - Offset + 1 > Max_Length
         then
            raise Malformed_Varint with "unterminated or overlong varint";
         end if;
         B := Interfaces.Unsigned_8 (Buffer (I));
         Result :=
           Result or
             Interfaces.Shift_Left
               (Interfaces.Unsigned_64 (B and Payload_Mask), Shift);
         if (B and Continuation_Bit) = 0 then
            Done := True;
         else
            I     := I + 1;
            Shift := Shift + 7;
         end if;
      end loop;
      Value := Result;
      Last  := I;
   end Decode;

   ----------------------
   --  Encoded_Length  --
   ----------------------

   function Encoded_Length (Value : Interfaces.Unsigned_64) return Positive is
      V : Interfaces.Unsigned_64 := Value;
      N : Positive := 1;
   begin
      while V >= 128 loop
         V := Interfaces.Shift_Right (V, 7);
         N := N + 1;
      end loop;
      return N;
   end Encoded_Length;

   -----------------
   --  Decode_One --
   -----------------

   function Decode_One
     (Buffer : Ada.Streams.Stream_Element_Array)
      return Interfaces.Unsigned_64
   is
      V : Interfaces.Unsigned_64;
      L : Ada.Streams.Stream_Element_Offset;
   begin
      Decode (Buffer, Buffer'First, V, L);
      return V;
   end Decode_One;

end IPFS.Varint;
