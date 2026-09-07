pragma SPARK_Mode;

with Interfaces;
with Ada.Streams; use Ada.Streams;

package body IPFS.SHA256 is

   --  Initial hash values (first 32 bits of the fractional parts of the square roots of the first 8 primes)
   Initial_State : constant State_Array :=
     [16#6a09e667#, 16#bb67ae85#, 16#3c6ef372#, 16#a54ff53a#,
      16#510e527f#, 16#9b05688c#, 16#1f83d9ab#, 16#5be0cd19#];

   --  Round constants (first 32 bits of the fractional parts of the cube roots of the first 64 primes)
   K : constant array (0 .. 63) of Word :=
     [16#428a2f98#, 16#71374491#, 16#b5c0fbcf#, 16#e9b5dba5#,
      16#3956c25b#, 16#59f111f1#, 16#923f82a4#, 16#ab1c5ed5#,
      16#d807aa98#, 16#12835b01#, 16#243185be#, 16#550c7dc3#,
      16#72be5d74#, 16#80deb1fe#, 16#9bdc06a7#, 16#c19bf174#,
      16#e49b69c1#, 16#efbe4786#, 16#0fc19dc6#, 16#240ca1cc#,
      16#2de92c6f#, 16#4a7484aa#, 16#5cb0a9dc#, 16#76f988da#,
      16#983e5152#, 16#a831c66d#, 16#b00327c8#, 16#bf597fc7#,
      16#c6e00bf3#, 16#d5a79147#, 16#06ca6351#, 16#14292967#,
      16#27b70a85#, 16#2e1b2138#, 16#4d2c6dfc#, 16#53380d13#,
      16#650a7354#, 16#766a0abb#, 16#81c2c92e#, 16#92722c85#,
      16#a2bfe8a1#, 16#a81a664b#, 16#c24b8b70#, 16#c76c51a3#,
      16#d192e819#, 16#d6990624#, 16#f40e3585#, 16#106aa070#,
      16#19a4c116#, 16#1e376c08#, 16#2748774c#, 16#34b0bcb5#,
      16#391c0cb3#, 16#4ed8aa4a#, 16#5b9cca4f#, 16#682e6ff3#,
      16#748f82ee#, 16#78a5636f#, 16#84c87814#, 16#8cc70208#,
      16#90befffa#, 16#a4506ceb#, 16#bef9a3f7#, 16#c67178f2#];

   --  Rotate right operation
   function Rotr (X : Word; N : Natural) return Word is
     (Word (Interfaces.Rotate_Right (Interfaces.Unsigned_32 (X), N)));

   --  SHA-256 logical functions
   function Ch (X, Y, Z : Word) return Word is
     ((X and Y) xor ((not X) and Z));

   function Maj (X, Y, Z : Word) return Word is
     ((X and Y) xor (X and Z) xor (Y and Z));

   function Sigma0 (X : Word) return Word is
     (Rotr (X, 2) xor Rotr (X, 13) xor Rotr (X, 22));

   function Sigma1 (X : Word) return Word is
     (Rotr (X, 6) xor Rotr (X, 11) xor Rotr (X, 25));

   function Gamma0 (X : Word) return Word is
     (Rotr (X, 7) xor Rotr (X, 18) xor (X / 2**3));

   function Gamma1 (X : Word) return Word is
     (Rotr (X, 17) xor Rotr (X, 19) xor (X / 2**10));

   --  Process a single 512-bit block
   procedure Process_Block
     (State : in out State_Array;
      Block : Block_Array)
   is
      W : array (0 .. 63) of Word;
      A, B, C, D, E, F, G, H : Word;
      T1, T2 : Word;
   begin
      --  Prepare message schedule
      for T in 0 .. 15 loop
         W (T) := Word (Block (T * 4)) * 2**24 +
                  Word (Block (T * 4 + 1)) * 2**16 +
                  Word (Block (T * 4 + 2)) * 2**8 +
                  Word (Block (T * 4 + 3));
      end loop;

      for T in 16 .. 63 loop
         W (T) := Gamma1 (W (T - 2)) + W (T - 7) + Gamma0 (W (T - 15)) + W (T - 16);
      end loop;

      --  Initialize working variables
      A := State (0);
      B := State (1);
      C := State (2);
      D := State (3);
      E := State (4);
      F := State (5);
      G := State (6);
      H := State (7);

      --  Main loop
      for T in 0 .. 63 loop
         T1 := H + Sigma1 (E) + Ch (E, F, G) + K (T) + W (T);
         T2 := Sigma0 (A) + Maj (A, B, C);
         H := G;
         G := F;
         F := E;
         E := D + T1;
         D := C;
         C := B;
         B := A;
         A := T1 + T2;
      end loop;

      --  Update state
      State (0) := State (0) + A;
      State (1) := State (1) + B;
      State (2) := State (2) + C;
      State (3) := State (3) + D;
      State (4) := State (4) + E;
      State (5) := State (5) + F;
      State (6) := State (6) + G;
      State (7) := State (7) + H;
   end Process_Block;

   function Initial return Context is
   begin
      return Ctx : Context do
         Ctx.State := Initial_State;
         Ctx.Buffer := [others => 0];
         Ctx.Buffer_Len := 0;
         Ctx.Total_Bytes := 0;
      end return;
   end Initial;

   procedure Update
     (Ctx  : in out Context;
      Data : Ada.Streams.Stream_Element_Array)
   is
      Data_Offset : Ada.Streams.Stream_Element_Offset := Data'First;
   begin
      Ctx.Total_Bytes := Ctx.Total_Bytes + Long_Long_Integer (Data'Length);

      --  Fill buffer and process complete blocks
      while Data_Offset <= Data'Last loop
         declare
            Space : constant Natural := 64 - Ctx.Buffer_Len;
            Remaining : constant Natural := Natural (Data'Last - Data_Offset + 1);
            To_Copy : constant Natural := Natural'Min (Space, Remaining);
         begin
            for I in 0 .. To_Copy - 1 loop
               Ctx.Buffer (Ctx.Buffer_Len + I) := Data (Data_Offset + Ada.Streams.Stream_Element_Offset (I));
            end loop;

            Ctx.Buffer_Len := Ctx.Buffer_Len + To_Copy;
            Data_Offset := Data_Offset + Ada.Streams.Stream_Element_Offset (To_Copy);

            if Ctx.Buffer_Len = 64 then
               Process_Block (Ctx.State, Ctx.Buffer);
               Ctx.Buffer_Len := 0;
            end if;
         end;
      end loop;
   end Update;

   function Finish (Ctx : Context) return Ada.Streams.Stream_Element_Array is
      Final_Ctx : Context := Ctx;
      Bit_Length : constant Long_Long_Integer := Final_Ctx.Total_Bytes * 8;
      Padding_Len : Natural;
   begin
      --  Append padding bit (0x80)
      Final_Ctx.Buffer (Final_Ctx.Buffer_Len) := 16#80#;
      Final_Ctx.Buffer_Len := Final_Ctx.Buffer_Len + 1;

      --  Calculate padding length
      if Final_Ctx.Buffer_Len > 56 then
         Padding_Len := 64 - Final_Ctx.Buffer_Len;
      else
         Padding_Len := 56 - Final_Ctx.Buffer_Len;
      end if;

      --  Add zero padding
      for I in Final_Ctx.Buffer_Len .. Final_Ctx.Buffer_Len + Padding_Len - 1 loop
         Final_Ctx.Buffer (I) := 0;
      end loop;
      Final_Ctx.Buffer_Len := Final_Ctx.Buffer_Len + Padding_Len;

      --  If we need another block
      if Final_Ctx.Buffer_Len = 64 then
         Process_Block (Final_Ctx.State, Final_Ctx.Buffer);
         Final_Ctx.Buffer := [others => 0];
         Final_Ctx.Buffer_Len := 0;
      end if;

      --  Append length as 64-bit big-endian
      for I in 0 .. 7 loop
         Final_Ctx.Buffer (56 + I) := Ada.Streams.Stream_Element
           ((Bit_Length / (2 ** (56 - I * 8))) mod 256);
      end loop;
      Final_Ctx.Buffer_Len := 64;

      Process_Block (Final_Ctx.State, Final_Ctx.Buffer);

      --  Convert state to byte array (big-endian)
      return Result : Ada.Streams.Stream_Element_Array (1 .. Digest_Length) do
         for I in 0 .. 7 loop
            Result (Ada.Streams.Stream_Element_Offset (1 + I * 4)) :=
              Ada.Streams.Stream_Element ((Final_Ctx.State (I) / 2**24) mod 256);
            Result (Ada.Streams.Stream_Element_Offset (2 + I * 4)) :=
              Ada.Streams.Stream_Element ((Final_Ctx.State (I) / 2**16) mod 256);
            Result (Ada.Streams.Stream_Element_Offset (3 + I * 4)) :=
              Ada.Streams.Stream_Element ((Final_Ctx.State (I) / 2**8) mod 256);
            Result (Ada.Streams.Stream_Element_Offset (4 + I * 4)) :=
              Ada.Streams.Stream_Element (Final_Ctx.State (I) mod 256);
         end loop;
      end return;
   end Finish;

   function Digest (Data : Ada.Streams.Stream_Element_Array)
     return Ada.Streams.Stream_Element_Array
   is
      Ctx : Context := Initial;
   begin
      Update (Ctx, Data);
      return Finish (Ctx);
   end Digest;

end IPFS.SHA256;
