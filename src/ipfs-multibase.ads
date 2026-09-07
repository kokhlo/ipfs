pragma Ada_2022;
pragma SPARK_Mode;

with Ada.Streams;

package IPFS.Multibase is

   type Base_Type is (Base_32_Lower, Base_58_BTC);

   Unsupported_Base : exception;
   Malformed_Encoding : exception;

   --  Encode bytes to multibase string with prefix
   --  'b' for Base_32_Lower, 'z' for Base_58_BTC
   function Encode
     (Base  : Base_Type;
      Bytes : Ada.Streams.Stream_Element_Array) return String;

   --  Decode multibase string (auto-detect base from prefix)
   --  'b'/'B' -> base32, 'z' -> base58btc
   --  Raises Malformed_Encoding if no prefix or unknown prefix
   function Decode (Text : String) return Ada.Streams.Stream_Element_Array;

   --  Detect base encoding from prefix character
   --  Raises Malformed_Encoding if empty or unknown prefix
   function Detect_Base (Text : String) return Base_Type;

end IPFS.Multibase;
