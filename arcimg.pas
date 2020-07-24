uses dos,crt;

type DDTP=record
       filla:array[0..2] of byte;
       sectorsize:byte;
       lastsector:byte;
       gap:byte;
       translength:byte;
       sectorgap:byte;
       fillbyte:byte;
       fillb:word;
     end;

type address_fields=record
       cylinder:byte;
       head:byte;
       sector:byte;
       bytes_per_sec:byte;
     end;

var prompt,command:string;
    buffer:array[1..5120] of byte;
    last_buff:integer;
    no_dsk,arc_disk:boolean;
    pDDTP:^DDTP;
    vDDTP:DDTP;
    oldDDTP:pointer;
    total_filesize:longint;
    arc_title:string;
    job:string;
    outfile:file;
    key:char;
    AvTRACK:byte;
    AvSECTOR:byte;
    AvHEAD:byte;
    read_result:byte;
    format_result:byte;
    sectors_to_read:byte;
    re_read_count:byte;
    numread:integer;

function upstr(s:string):string;
var i:integer;
begin
   for i:=1 to length(s) do s[i]:=upcase(s[i]);
   upstr:=s;
end;

procedure init_arc_dsk;
begin
  asm {Init Disk system}
    mov ah,0
    mov dl,0
    int $13
  end;
  getintvec($1e,oldDDTP);
  pDDTP:=oldDDTP;
  vDDTP:=pDDTP^;
  vDDTP.sectorsize:=3; {1024 bytes}
  vDDTP.lastsector:=4;
  setintvec($1e,@vddtp);
  last_buff:=-1;
end;

function sec_offs(vTRACK,vSECTOR,vHEAD:byte):integer;
var tmp:integer;
begin
  sec_offs:=(vTRACK*10)+(vHEAD*5)+vSECTOR;
end;

function format_arc_track(vTRACK,vSECTOR,vHEAD:byte):byte;
var result:byte;
    af:address_fields;
    af_seg:word;
    af_ofs:word;
begin
  if ((vHEAD in[0,1]) and (vTRACK in[0..79]) and (vSECTOR in[0..4])) then
  begin

    with af do
    begin
      cylinder:=vTRACK;
      head:=vHEAD;
      sector:=vSECTOR;
      bytes_per_sec:=3; {1024 byte sectors}
    end;

    af_seg:=seg(af); af_ofs:=ofs(af);

    asm
      mov ah,$05
      mov al,$01
      mov ch,vTRACK
      mov cl,vSECTOR
      mov dh,vHEAD
      mov dl,0
      mov es,af_seg
      mov bx,af_ofs
      int $13
      mov result,ah
    end;
  end;
  format_arc_track:=result;
end;

function read_arc_sectors(vSECTORS,vTRACK,vSECTOR,vHEAD:byte):byte;
var buf_seg,buf_ofs:word;
    result:byte;
begin
  if ((vSECTORS in[1..5]) and (vHEAD in[0,1]) and
     (vTRACK in[0..79]) and (vSECTOR in[0..4])) then
  begin
    buf_seg:=seg(buffer[1]); buf_ofs:=ofs(buffer[1]);
    asm {Read a sector}
      mov ah,2
      mov al,vSECTORS
      mov ch,vTRACK
      mov cl,vSECTOR
      mov dh,vHEAD
      mov dl,0
      mov es,buf_seg
      mov bx,buf_ofs
      int $13
      mov result,ah
    end;
    last_buff:=sec_offs(vTRACK,vSECTOR,vHEAD);
    read_arc_sectors:=result;
  end
 else read_arc_sectors:=$ff;
end;

function write_arc_sectors(vSECTORS,vTRACK,vSECTOR,vHEAD:byte):byte;
var buf_seg,buf_ofs:word;
    result:byte;
begin
  if ((vSECTORS in[1..5]) and (vHEAD in[0,1]) and
     (vTRACK in[0..79]) and (vSECTOR in[0..4])) then
  begin
    buf_seg:=seg(buffer[1]); buf_ofs:=ofs(buffer[1]);
    asm {Write a sector}
      mov ah,3
      mov al,vSECTORS
      mov ch,vTRACK
      mov cl,vSECTOR
      mov dh,vHEAD
      mov dl,0
      mov es,buf_seg
      mov bx,buf_ofs
      int $13
      mov result,ah
    end;
    write_arc_sectors:=result;
  end
 else write_arc_sectors:=$ff;
end;

procedure done_arc_dsk;
begin
  if oldDDTP<>nil then setintvec($1e,oldDDTP);
  oldDDTP:=nil;
  arc_disk:=false;
  last_buff:=-1;
end;

function is_arc_dsk:boolean;
var result:byte;
begin
  init_arc_dsk;
  result:=read_arc_sectors(1,0,0,0);
  if result<>128 then no_dsk:=false else no_dsk:=true;
  if result=6 then result:=read_arc_sectors(1,0,0,0);
  is_arc_dsk:=(result=0);
end;

procedure ver;
begin
  writeln(#13#10'Archimedes disk image program for PC');
  writeln('Version 1.1 - Jasper Renow-Clarke 1997,99 (jasperr@osl1.co.uk)');
end;

procedure show_syntax;
begin
  ver;
  writeln('Syntax :');
  writeln('  ARCIMG diskimage [operation]'#13#10);
  writeln('    Operations :');
  writeln('    /read    - Reads disk into image (Default)');
  writeln('    /write   - Writes disk from image');
  writeln('               (Disk must be formatted already using real Archimedes)');
  writeln('    /format  - Formats disk (Doesnt Work !!!)');
  halt;
end;

begin
  if paramcount < 1 then show_syntax;
  ver;
  arc_disk:=false; no_dsk:=true; job:='/read';
  if paramcount>1 then job:=paramstr(2);

  if job='/format' then {/format}
  begin
     writeln('Formating Archimedes disk ... (Doesnt Work !!!)');
     init_arc_dsk;
     AvHEAD:=0; AvSECTOR:=0; AvTRACK:=0;

     repeat
       format_result:=format_arc_track(AvTRACK,AvSECTOR,AvHEAD);

       inc(AvSECTOR);
       if AvSECTOR=5 then
       begin
         AvSECTOR:=0;
         inc(AvHEAD);
         if AvHEAD=2 then
         begin
           AvHEAD:=0;
           inc(AvTRACK);
           if (AvTRACK>79) then AvTRACK:=255 else write(AvTRACK:3);
         end;
       end;

     until (AvTRACK=255) or keypressed;
     done_arc_dsk;
  end;

  if job='/write' then {/write}
    if is_arc_dsk then
    begin
      writeln('Archimedes disk in drive A');
      writeln('Writing disk from image : ',paramstr(1));
      arc_disk:=true;
      AvHEAD:=0; AvSECTOR:=0; AvTRACK:=0;
      sectors_to_read:=5;

      assign(outfile, paramstr(1));
      reset(outfile,1);

      {Main loop to make diskimage}
      repeat
        {Clear Buffer}
        fillchar(buffer,sizeof(buffer),$AF);

        blockread(outfile,buffer,sectors_to_read*1024,numread);
        if numread>0 then
        begin
          read_result:=write_arc_sectors(sectors_to_read,AvTRACK,AvSECTOR,AvHEAD);
          if read_result=0 then
            if AvHEAD=1 then write(AvTRACK:3);
        end;

        inc(AvHEAD);
        if AvHEAD=2 then
        begin
          AvHEAD:=0;
          inc(AvTRACK);
          if (AvTRACK>79) then AvTRACK:=255;
        end;
      until (AvTRACK=255) or keypressed;
      close(outfile);
      writeln;
      writeln(#13#10'Finished writing disk from image');
    end;

  if job='/read' then {/read (default)}
  if is_arc_dsk then
  begin
    writeln('Archimedes disk in drive A');
    writeln('Reading image from disk : ', paramstr(1));
    arc_disk:=true;
    AvHEAD:=0; AvSECTOR:=0; AvTRACK:=0;
    sectors_to_read:=5;

    assign(outfile, paramstr(1));
    rewrite(outfile,1);

    {Main loop to make diskimage}
    repeat
      read_result:=read_arc_sectors(sectors_to_read,AvTRACK,AvSECTOR,AvHEAD);

      if read_result <> 0 then {Attempt to read those 5 individualy}
      begin
        textcolor(red);
        for re_read_count:=AvTRACK to AvTRACK+5 do
        begin
          read_result:=read_arc_sectors(1,re_read_count,AvSECTOR,AvHEAD);
          if read_result=0 then
            blockwrite(outfile,buffer,1024)
          else
            write(re_read_count:3);
        end;
        textcolor(lightgray); writeln;
      end
     else
      begin
        if AvHEAD=1 then write(AvTRACK:3);
        blockwrite(outfile,buffer,sectors_to_read*1024);
      end;

      inc(AvHEAD);
      if AvHEAD=2 then
      begin
        AvHEAD:=0;
        inc(AvTRACK);
        if (AvTRACK>79) then AvTRACK:=255;
      end;
    until (AvTRACK=255) or keypressed;
    close(outfile);
    writeln;
    writeln(#13#10'Finished reading image from disk');
  end
 else
 begin
   writeln('Not an Archimedes disk');
   done_arc_dsk;
 end;

 if no_dsk then writeln('No disk in drive A');

 if arc_disk then done_arc_dsk;
end.
