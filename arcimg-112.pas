{********** modified October 2001 by Tom Humphrey to cope with F format (1.6 Mb) disks}


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
    buffer:array[1..10240] of byte; {******* changed from 5120}
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
    sectors_per_track:byte; {***** d/e formats use 5, f uses 10}
    param_read:boolean;
    param_write:boolean;
    param_format:boolean;
    i:integer;

function upstr(s:string):string;
var i:integer;
begin
   for i:=1 to length(s) do s[i]:=upcase(s[i]);
   upstr:=s;
end;

procedure init_arc_dsk;
var Reg: Registers;
begin
  with Reg do
  begin
    AH:=0;
    DL:=0;
  end;
  Intr($13,Reg);

  getintvec($1e,oldDDTP);
  pDDTP:=oldDDTP;
  vDDTP:=pDDTP^;
  vDDTP.sectorsize:=3; {1024 bytes}
  vDDTP.lastsector:=sectors_per_track; {this is correct, not sectors-1}
  vDDTP.gap:=32;
  vDDTP.sectorgap:=90;
  setintvec($1e,@vddtp);
  last_buff:=-1;
end;

function sec_offs(vTRACK,vSECTOR,vHEAD:byte):integer;
var tmp:integer;
begin
  sec_offs:=(vTRACK*10)+(vHEAD*5)+vSECTOR;
end;

function set_media_for_format:byte;
var Reg:Registers;
    result:byte;
begin
  with Reg do
  begin
    AH:=$18; {Set media type for format}
    CH:=80; {number of tracks}
    CL:=sectors_per_track;
    DL:=0; {drive A:}

    {AH:=$17;
    AL:=2;
    DL:=0;}

  end;
  Intr($13,Reg);
  result:=Reg.AH;
  writeln('Media init result:',result:3);
  set_media_for_format:=result;
end;


function format_arc_track(vTRACK,vHEAD:byte):byte;
var result:byte;
    af:array[0..10] of address_fields;
    af_seg:word;
    af_ofs:word;
    Reg:Registers;
    i:integer;
    skew:array[0..10] of byte;
begin

  if sectors_per_track=10 then
  begin
        {attempt to set proper skew for sectors on HD disk
         this doesn't seem to work quite right ... any ideas?}
    skew[0]:=0;
    skew[1]:=7;
    skew[2]:=4;
    skew[3]:=1;
    skew[4]:=8;
    skew[5]:=5;
    skew[6]:=2;
    skew[7]:=9;
    skew[8]:=6;
    skew[9]:=3;
  end
  else
  begin
    for i:=0 to 4 do skew[i]:=i; {no skew on 800k discs}

    {skew[0]:=0
    skew[1]:=3
    skew[2]:=1
    skew[3]:=4
    skew[4]:=2
    }
  end;

  for i:=0 to (sectors_per_track-1) do
  begin
    af[i].cylinder:=vTRACK;
    af[i].head:=vHEAD;
    af[i].sector:=skew[i];  {sector number} 
    af[i].bytes_per_sec:=3; {3=1024}
  end;

  af_seg:=seg(af[0]); af_ofs:=ofs(af[0]);

  {Most of the documentation I could find on formatting floppies appears to be WRONG.}
  {the correct approach appears to be to use the parameters required for formatting a hard disc!}

  with Reg do
  begin
    AH:=$05;
    CH:=vTRACK;
    DH:=vHEAD;
    DL:=0;
    ES:=af_seg; {for each sector, four bytes as above}
    BX:=af_ofs;
  end;
  Intr($13,Reg);

  {result:=Reg.AH;}

  format_arc_track:=Reg.AH;
  {write('=',result:3);}
end;

function read_arc_sectors(vSECTORS,vTRACK,vSECTOR,vHEAD:byte):byte;
var buf_seg,buf_ofs:word;
    result:byte;
    Reg:Registers;
begin
  if ((vSECTORS in[1..sectors_per_track]) and (vHEAD in[0,1]) and
     (vTRACK in[0..79]) and (vSECTOR in[0..(sectors_per_track-1)])) then

     {********* Changed sector values from 1..5 and 0..4 respectively}
  begin
    buf_seg:=seg(buffer[1]); buf_ofs:=ofs(buffer[1]);

    with Reg do
    begin {Read a sector}

      AH:=2;
      AL:=vSECTORS;
      CH:=vTRACK;
      CL:=vSECTOR;
      DH:=vHEAD;
      DL:=0;
      ES:=buf_seg;
      BX:=buf_ofs;
    end;
    intr($13,Reg);
    result:=Reg.AH;

    last_buff:=sec_offs(vTRACK,vSECTOR,vHEAD);
    read_arc_sectors:=result;
  end
 else read_arc_sectors:=$ff;
end;

function write_arc_sectors(vSECTORS,vTRACK,vSECTOR,vHEAD:byte):byte;
var buf_seg,buf_ofs:word;
    result:byte;
    Reg:Registers;
begin
  if ((vSECTORS in[1..sectors_per_track]) and (vHEAD in[0,1]) and
     (vTRACK in[0..79]) and (vSECTOR in[0..(sectors_per_track-1)])) then

     {********* Changed sector values from 1..5 and 0..4 respectively}
  begin
    buf_seg:=seg(buffer[1]); buf_ofs:=ofs(buffer[1]);


    with Reg do
    begin {Write a sector}
      ah:=3;
      al:=vSECTORS;
      ch:=vTRACK;
      cl:=vSECTOR;
      dh:=vHEAD;
      dl:=0;
      es:=buf_seg;
      bx:=buf_ofs;
    end;
    intr($13,Reg);
    result:=Reg.ah;

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
  {I've altered this to try to autodetect if 800 or 1600k disk}
  sectors_per_track:=10;

  init_arc_dsk;
  result:=read_arc_sectors(1,0,5,0); {try to read sector 5, (only there on big disks)}
  if result=6 then result:=read_arc_sectors(1,0,5,0);

  if result=4 then
  begin
    sectors_per_track:=5;
    done_arc_dsk; {put back old values before they are overwritten again!}
    init_arc_dsk;
    result:=read_arc_sectors(1,0,0,0);
    if (result=0) then writeln('800k Archimedes disk in drive A:');
  end
  else if (result=0) then writeln('1.6Mb Archimedes disk in drive A:');


  if result<>128 then no_dsk:=false else no_dsk:=true;

  {writeln('Disk result',result:3)}

  is_arc_dsk:=(result=0);
end;

procedure ver;
begin
  writeln(#13#10'Archimedes disk image program for PC');
  writeln('Version 1.1 - Jasper Renow-Clarke 1997,99 (jasperr@osl1.co.uk)');
  writeln('Version 1.1.2 modified Tom Humphrey 2001 (t.humphrey@bigfoot.com)');
end;

procedure show_syntax;
begin
  ver;
  writeln('Syntax :');
  writeln('  ARCIMG diskimage [operation]'#13#10);
  writeln('    Operation :');
  writeln('    /read       - Reads disk into image (Default)');
  writeln('    /write      - Writes disk from image');
  writeln('    /format800  - Formats 800k disk  ***DOESN''T WORK***');
  writeln('    /format1600 - Formats 1.6Mb disk');
  writeln(#10'  NB: discs formatted on an Archimedes are quicker and more reliable.');
  writeln(   '      than those formatted here.');
  halt;
end;

begin

  param_read:=false;param_format:=false;param_write:=false;

  if paramcount < 1 then show_syntax;
  ver;
  arc_disk:=false; no_dsk:=true;{job:='/read';}

  if paramcount=1 then
    param_read:=true
  else
  begin
    for i:=2 to paramcount do
    begin
      if paramstr(i)='/format800' then
      begin
        param_format:=TRUE;
        sectors_per_track:=5;
      end

      else if paramstr(i)='/format1600' then
      begin
        param_format:=TRUE;
        sectors_per_track:=10;
      end

      else if paramstr(i)='/read' then param_read:=TRUE
      else if paramstr(i)='/write' then param_write:=TRUE
      else
        show_syntax;
    end;
  end;

  if ( ((param_format and param_read)=TRUE) or ((param_write and param_read)=TRUE) ) then
    show_syntax;

  {writeln('file=',paramstr(1),#10#13'read=',param_read,' write=',param_write,' format=',param_format);}

  if param_format then {/format}
  begin
     writeln('Formating Archimedes disk...');
     init_arc_dsk;

     AvTRACK:=0;

     i:=set_media_for_format;

     repeat
       format_result:=format_arc_track(AvTRACK,0); {head 0}
       format_result:=format_arc_track(AvTRACK,1); {head 1}

       inc(AvTRACK);
       write(AvTRACK:3);

     until (AvTRACK>79) or keypressed or (format_result=128);
     done_arc_dsk;

     if format_result=128 then
     begin
       Writeln(#10#13'No disc in drive A:');
       halt;
     end;
  end;

  if param_write then {/write}
    if is_arc_dsk then
    begin
      writeln('Writing disk from image : ',paramstr(1));
      arc_disk:=true;
      AvHEAD:=0; AvSECTOR:=0; AvTRACK:=0;
      sectors_to_read:=sectors_per_track; {******** was 5}

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
    end
    else
    begin
      Writeln('Not an Archimdes disc');
      done_arc_dsk;
    end;

  if param_read then {/read (default)}
    if is_arc_dsk then
    begin
      writeln('Reading image from disk : ', paramstr(1));
      arc_disk:=true;
      AvHEAD:=0; AvSECTOR:=0; AvTRACK:=0;
      sectors_to_read:=sectors_per_track; {******** was 5}

      assign(outfile, paramstr(1));
      rewrite(outfile,1);

      {Main loop to make diskimage}
      repeat
        read_result:=read_arc_sectors(sectors_to_read,AvTRACK,AvSECTOR,AvHEAD);

        if read_result <> 0 then {Attempt to each sector individualy}
        begin
          for AvSECTOR:=0 to (sectors_per_track-1) do
          begin
            re_read_count :=0; {will do up to 3 retries / sector}
            repeat
              read_result:=read_arc_sectors(1,AvTRACK,AvSECTOR,AvHEAD);
              if read_result=0 then
              begin
                blockwrite(outfile,buffer,1024); {read success}
              end;

              inc(re_read_count);
            until (re_read_count=3) or (read_result=0);

            if read_result <> 0 then
            begin
              {need to write dummy block so that image file is still correct size}
              fillchar(buffer,1024,$af);
              {for i:=0 TO 1023 do buffer[i]=255;}
              blockwrite(outfile,buffer,1024); {write dummy block to image}

              textcolor(red);
              writeln('Error:',AvTRACK:3,' ?',AvSector:3);
              textcolor(lightgray);
            end;
          end;

          AvSECTOR:=0; {reset back to start value}
        end
        else {have good data}
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
