pragma SPARK_Mode (Off);

with Ada.IO_Exceptions;
with GNAT.Sockets;

package body IPFS.Gateway is

   use GNAT.Sockets;
   use Ada.Streams;

   Socket_Timeout : constant Duration := 30.0;

   CR : constant Stream_Element := Stream_Element (Character'Pos (ASCII.CR));
   LF : constant Stream_Element := Stream_Element (Character'Pos (ASCII.LF));

   --  Parse HTTP response and return (status_code, body_start_index).
   procedure Parse_HTTP_Response
     (Data        : Stream_Element_Array;
      Status_Code : out Natural;
      Body_Start  : out Stream_Element_Offset)
   is
      Line_Start : constant Stream_Element_Offset := Data'First;
      Line_End : Stream_Element_Offset := Data'First;
   begin
      Status_Code := 0;
      Body_Start := Data'Last + 1;

      --  Find first line (status line).
      for I in Data'Range loop
         if I < Data'Last and then Data (I) = CR and then Data (I + 1) = LF then
            Line_End := I - 1;
            exit;
         end if;
      end loop;

      --  Parse status line: HTTP/1.1 200 OK
      if Line_End >= Line_Start then
         declare
            Status_Line : String (1 .. Natural (Line_End - Line_Start + 1));
         begin
            for I in Status_Line'Range loop
               Status_Line (I) := Character'Val (Data (Line_Start + Stream_Element_Offset (I - 1)));
            end loop;

            --  Extract status code (second token after space).
            declare
               First_Space : Natural := 0;
               Second_Space : Natural := 0;
            begin
               for I in Status_Line'Range loop
                  if Status_Line (I) = ' ' then
                     if First_Space = 0 then
                        First_Space := I;
                     else
                        Second_Space := I;
                        exit;
                     end if;
                  end if;
               end loop;

               if First_Space > 0 and then Second_Space > First_Space then
                  Status_Code := Natural'Value (Status_Line (First_Space + 1 .. Second_Space - 1));
               end if;
            end;
         end;
      end if;

      --  Find headers end (empty line = CRLF CRLF).
      for I in Data'Range loop
         if I + 3 <= Data'Last
           and then Data (I) = CR
           and then Data (I + 1) = LF
           and then Data (I + 2) = CR
           and then Data (I + 3) = LF
         then
            Body_Start := I + 4;
            exit;
         end if;
      end loop;
   end Parse_HTTP_Response;

   --  HTTP GET request with redirect handling.
   function HTTP_Get
     (Config        : Gateway_Config;
      Path          : String;
      Accept_Header : String)
      return Stream_Element_Array
   is
      Address   : Sock_Addr_Type;
      Socket    : Socket_Type;
      Channel   : Stream_Access;
      Host_Str  : constant String := Config.Host (1 .. Config.Host_Len);
      Request   : constant String :=
        "GET " & Path & " HTTP/1.1" & ASCII.CR & ASCII.LF &
        "Host: " & Host_Str & ASCII.CR & ASCII.LF &
        "Accept: " & Accept_Header & ASCII.CR & ASCII.LF &
        "Connection: close" & ASCII.CR & ASCII.LF &
        ASCII.CR & ASCII.LF;

      Response_Buffer : Stream_Element_Array (1 .. 524_288);
      Last            : Stream_Element_Offset := 0;
      Status_Code     : Natural;
      Body_Start      : Stream_Element_Offset;
   begin
      --  Resolve and connect.
      Address.Addr := Inet_Addr (Host_Str);
      Address.Port := Port_Type (Config.Port);

      Create_Socket (Socket);
      Set_Socket_Option (Socket, Socket_Level, (Receive_Timeout, Timeout => Socket_Timeout));
      Set_Socket_Option (Socket, Socket_Level, (Send_Timeout, Timeout => Socket_Timeout));

      begin
         Connect_Socket (Socket, Address);
      exception
         when Socket_Error =>
            Close_Socket (Socket);
            raise Connection_Error with "Failed to connect to " & Host_Str;
      end;

      Channel := Stream (Socket);

      --  Send request.
      declare
         Req_Array : Stream_Element_Array (1 .. Request'Length);
      begin
         for I in Request'Range loop
            Req_Array (Stream_Element_Offset (I)) :=
              Stream_Element (Character'Pos (Request (I)));
         end loop;

         Write (Channel.all, Req_Array);
      end;

      --  Read response until EOF (Connection: close) or buffer full.
      Read_Loop :
      loop
         declare
            Chunk : Stream_Element_Array (1 .. 4096);
            Chunk_Last : Stream_Element_Offset;
         begin
            Read (Channel.all, Chunk, Chunk_Last);
            exit Read_Loop when Chunk_Last < Chunk'First;

            Response_Buffer (Last + 1 .. Last + (Chunk_Last - Chunk'First + 1)) :=
              Chunk (Chunk'First .. Chunk_Last);
            Last := Last + (Chunk_Last - Chunk'First + 1);

            exit Read_Loop when Last >= Response_Buffer'Last;
         exception
            when Ada.IO_Exceptions.Device_Error
               | Ada.IO_Exceptions.End_Error =>
               --  Peer closed mid-read: treat as end of body.
               exit Read_Loop;
         end;
      end loop Read_Loop;

      Close_Socket (Socket);

      if Last = 0 then
         raise Connection_Error with "Empty response from gateway";
      end if;

      --  Parse response.
      Parse_HTTP_Response (Response_Buffer (1 .. Last), Status_Code, Body_Start);

      if Status_Code = 200 then
         if Body_Start > Last then
            return [1 .. 0 => 0];
         else
            return Response_Buffer (Body_Start .. Last);
         end if;
      elsif Status_Code = 301 or Status_Code = 302 then
         raise Gateway_Error with "Redirect not implemented in v0.1";
      elsif Status_Code = 404 then
         raise Gateway_Error with "CID not found (404)";
      else
         raise Gateway_Error with "HTTP" & Natural'Image (Status_Code);
      end if;

   exception
      when Socket_Error =>
         begin
            Close_Socket (Socket);
         exception
            when others => null;
         end;
         raise Connection_Error with "Socket error during HTTP GET";
   end HTTP_Get;

   function Fetch_Raw_Block
     (Config   : Gateway_Config;
      Cid_Text : String)
      return Stream_Element_Array
   is
   begin
      return HTTP_Get (Config, "/ipfs/" & Cid_Text & "?format=raw", "application/vnd.ipld.raw");
   end Fetch_Raw_Block;

   function Fetch_CAR
     (Config   : Gateway_Config;
      Cid_Text : String)
      return Stream_Element_Array
   is
   begin
      return HTTP_Get (Config, "/ipfs/" & Cid_Text & "?format=car", "application/vnd.ipld.car");
   end Fetch_CAR;

end IPFS.Gateway;
