pragma Ada_2022;
pragma SPARK_Mode;

package Multibase_Tests is

   procedure Run;

private

   type String_Access is access constant String;

   type Test_Vector is record
      Name : String_Access;
      Hex  : String_Access;
      B32  : String_Access;
      B58  : String_Access;
   end record;

   --  Test vectors generated with Python (fixed seed, cross-validated)
   Test_Vectors : constant array (Positive range <>) of Test_Vector :=
     [(new String'("official"),
       new String'("446563656e7472616c697a652065766572797468696e672121"),
       new String'("birswgzloorzgc3djpjssazlwmvzhs5dinfxgoijb"),
       new String'("zUXE7GvtEk8XTXs1GF8HSGbVA9FCX9SEBPe")),
(new String'("yes_mani"),
       new String'("796573206d616e692021"),
       new String'("bpfsxgidnmfxgsibb"),
       new String'("z7paNL19xttacUY")),
      (new String'("empty"),
       new String'(""),
       new String'("b"),
       new String'("z")),
(new String'("single_0"),
       new String'("00"),
       new String'("baa"),
       new String'("z1")),
(new String'("single_1"),
       new String'("01"),
       new String'("bae"),
       new String'("z2")),
(new String'("single_127"),
       new String'("7f"),
       new String'("bp4"),
       new String'("z3C")),
(new String'("single_128"),
       new String'("80"),
       new String'("bqa"),
       new String'("z3D")),
(new String'("single_255"),
       new String'("ff"),
       new String'("b74"),
       new String'("z5Q")),
(new String'("random_1"),
       new String'("39"),
       new String'("bhe"),
       new String'("zz")),
(new String'("random_2"),
       new String'("0c8c"),
       new String'("bbsga"),
       new String'("zxP")),
(new String'("random_3"),
       new String'("7d7247"),
       new String'("bpvzeo"),
       new String'("zj8tn")),
(new String'("leading_zeros_1"),
       new String'("00"),
       new String'("baa"),
       new String'("z1")),
(new String'("leading_zeros_2"),
       new String'("0000"),
       new String'("baaaa"),
       new String'("z11")),
(new String'("leading_zeros_mixed"),
       new String'("0000010203"),
       new String'("baaaacaqd"),
       new String'("z11Ldp")),
      (new String'("all_zeros_4"),
       new String'("00000000"),
       new String'("baaaaaaa"),
       new String'("z1111"))];

end Multibase_Tests;
