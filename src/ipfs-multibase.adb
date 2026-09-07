pragma Ada_2022;
pragma SPARK_Mode;

package body IPFS.Multibase is

   --  RFC 4648 base32 alphabet (lowercase, no padding)
   Base32_Alphabet : constant String := "abcdefghijklmnopqrstuvwxyz234567";

   --  Bitcoin base58 alphabet
   Base58_Alphabet : constant String :=
     "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";

   function Encode_Base32
     (Bytes : Ada.Streams.Stream_Element_Array) return String;

   function Decode_Base32
     (Text : String) return Ada.Streams.Stream_Element_Array;

   function Encode_Base58
     (Bytes : Ada.Streams.Stream_Element_Array) return String;

   function Decode_Base58
     (Text : String) return Ada.Streams.Stream_Element_Array;

   ------------
   -- Encode --
   ------------

   function Encode
     (Base  : Base_Type;
      Bytes : Ada.Streams.Stream_Element_Array) return String
   is
   begin
      case Base is
         when Base_32_Lower =>
            return 'b' & Encode_Base32 (Bytes);
         when Base_58_BTC =>
            return 'z' & Encode_Base58 (Bytes);
      end case;
   end Encode;

   ------------
   -- Decode --
   ------------

   function Decode (Text : String) return Ada.Streams.Stream_Element_Array is
      Base : constant Base_Type := Detect_Base (Text);
   begin
      if Text'Length < 1 then
         raise Malformed_Encoding with "Input too short";
      end if;

      --  Handle prefix-only case (empty data)
      if Text'Length = 1 then
         return [1 .. 0 => 0];
      end if;

      case Base is
         when Base_32_Lower =>
            return Decode_Base32 (Text (Text'First + 1 .. Text'Last));
         when Base_58_BTC =>
            return Decode_Base58 (Text (Text'First + 1 .. Text'Last));
      end case;
   end Decode;

   -----------------
   -- Detect_Base --
   -----------------

   function Detect_Base (Text : String) return Base_Type is
   begin
      if Text'Length = 0 then
         raise Malformed_Encoding with "Empty input";
      end if;

      case Text (Text'First) is
         when 'b' | 'B' =>
            return Base_32_Lower;
         when 'z' =>
            return Base_58_BTC;
         when others =>
            raise Malformed_Encoding with "Unknown prefix";
      end case;
   end Detect_Base;

   -------------------
   -- Encode_Base32 --
   -------------------

   function Encode_Base32
     (Bytes : Ada.Streams.Stream_Element_Array) return String
   is
      Max_Length : constant Natural := ((Bytes'Length * 8 + 4) / 5);
      Result     : String (1 .. Max_Length);
      Bits       : Natural := 0;
      Buffer     : Natural := 0;
      Idx        : Positive := 1;
   begin
      if Bytes'Length = 0 then
         return "";
      end if;

      for Byte of Bytes loop
         Buffer := Buffer * 256 + Natural (Byte);
         Bits := Bits + 8;

         while Bits >= 5 loop
            Bits := Bits - 5;
            declare
               Index : constant Natural := (Buffer / (2**Bits)) mod 32;
            begin
               Result (Idx) := Base32_Alphabet (Index + 1);
               Buffer := Buffer mod (2**Bits);
            end;
            Idx := Idx + 1;
         end loop;
      end loop;

      --  Handle remaining bits
      if Bits > 0 then
         declare
            Index : constant Natural := (Buffer * (2 ** (5 - Bits))) mod 32;
         begin
            Result (Idx) := Base32_Alphabet (Index + 1);
         end;
         Idx := Idx + 1;
      end if;

      return Result (1 .. Idx - 1);
   end Encode_Base32;

   -------------------
   -- Decode_Base32 --
   -------------------

   function Decode_Base32
     (Text : String) return Ada.Streams.Stream_Element_Array
   is
      use Ada.Streams;
      Result : Stream_Element_Array (1 .. Stream_Element_Offset ((Text'Length * 5) / 8));
      Bits   : Natural := 0;
      Buffer : Natural := 0;
      Idx    : Stream_Element_Offset := 1;
      Value  : Natural;
   begin
      if Text'Length = 0 then
         return [1 .. 0 => 0];
      end if;

      for Char of Text loop
         --  Find character in alphabet (case-insensitive)
         Value := 0;
         for J in Base32_Alphabet'Range loop
            if Char = Base32_Alphabet (J)
              or else Char = Character'Val
                (Character'Pos (Base32_Alphabet (J)) - 32)
            then
               Value := J - 1;
               exit;
            end if;
         end loop;

         --  Check for padding (not allowed in multibase base32)
         if Char = '=' then
            raise Malformed_Encoding with "Padding not allowed";
         end if;

         Buffer := Buffer * 32 + Value;
         Bits := Bits + 5;

         if Bits >= 8 then
            Bits := Bits - 8;
            declare
               Byte_Val : constant Natural := (Buffer / (2**Bits)) mod 256;
            begin
               Result (Idx) := Stream_Element (Byte_Val);
               Buffer := Buffer mod (2**Bits);
            end;
            Idx := Idx + 1;
         end if;
      end loop;

      return Result (1 .. Idx - 1);
   end Decode_Base32;

   -------------------
   -- Encode_Base58 --
   -------------------

   function Encode_Base58
     (Bytes : Ada.Streams.Stream_Element_Array) return String
   is
      use Ada.Streams;
      Leading_Zeros : Natural := 0;
      Temp          : array (1 .. Bytes'Length * 2) of Natural := [others => 0];
      Temp_Len      : Natural := 0;
      Result_Array  : String (1 .. Bytes'Length * 2);
      Result_Len    : Natural := 0;
   begin
      if Bytes'Length = 0 then
         return "";
      end if;

      --  Count leading zeros
      for Byte of Bytes loop
         exit when Byte /= 0;
         Leading_Zeros := Leading_Zeros + 1;
      end loop;

      --  Convert bytes to base58 using array division
      for Byte of Bytes loop
         declare
            Carry : Natural := Natural (Byte);
         begin
            for I in 1 .. Temp_Len loop
               Carry := Carry + Temp (I) * 256;
               Temp (I) := Carry mod 58;
               Carry := Carry / 58;
            end loop;

            while Carry > 0 loop
               Temp_Len := Temp_Len + 1;
               Temp (Temp_Len) := Carry mod 58;
               Carry := Carry / 58;
            end loop;
         end;
      end loop;

      --  Build result string: leading '1's + digits in correct order
      for I in 1 .. Leading_Zeros loop
         Result_Len := Result_Len + 1;
         Result_Array (Result_Len) := '1';
      end loop;

      for I in reverse 1 .. Temp_Len loop
         Result_Len := Result_Len + 1;
         Result_Array (Result_Len) := Base58_Alphabet (Temp (I) + 1);
      end loop;

      return Result_Array (1 .. Result_Len);
   end Encode_Base58;

   -------------------
   -- Decode_Base58 --
   -------------------

   function Decode_Base58
     (Text : String) return Ada.Streams.Stream_Element_Array
   is
      use Ada.Streams;
      Leading_Ones : Natural := 0;
      Temp         : array (1 .. Text'Length) of Natural := [others => 0];
      Temp_Len     : Natural := 0;
      Result_Array : Stream_Element_Array (1 .. Stream_Element_Offset (Text'Length));
      Result_Len   : Stream_Element_Offset := 0;
   begin
      if Text'Length = 0 then
         return [1 .. 0 => 0];
      end if;

      --  Count leading '1's
      for Char of Text loop
         exit when Char /= '1';
         Leading_Ones := Leading_Ones + 1;
      end loop;

      --  Decode each character
      for Char of Text loop
         --  Check for invalid '0'
         if Char = '0' then
            raise Malformed_Encoding with "Invalid base58 character '0'";
         end if;

         --  Find value
         declare
            Value : Natural := 0;
         begin
            for J in Base58_Alphabet'Range loop
               if Char = Base58_Alphabet (J) then
                  Value := J - 1;
                  exit;
               end if;
            end loop;

            --  Multiply temp by 58 and add value
            declare
               Carry : Natural := Value;
            begin
               for I in 1 .. Temp_Len loop
                  Carry := Carry + Temp (I) * 58;
                  Temp (I) := Carry mod 256;
                  Carry := Carry / 256;
               end loop;

               while Carry > 0 loop
                  Temp_Len := Temp_Len + 1;
                  Temp (Temp_Len) := Carry mod 256;
                  Carry := Carry / 256;
               end loop;
            end;
         end;
      end loop;

      --  Build result: leading zeros + reversed temp
      for I in 1 .. Leading_Ones loop
         Result_Len := Result_Len + 1;
         Result_Array (Result_Len) := 0;
      end loop;

      for I in reverse 1 .. Temp_Len loop
         Result_Len := Result_Len + 1;
         Result_Array (Result_Len) := Stream_Element (Temp (I));
      end loop;

      return Result_Array (1 .. Result_Len);
   end Decode_Base58;

end IPFS.Multibase;
