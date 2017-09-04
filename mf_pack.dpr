program mf_pack;

{$WEAKLINKRTTI ON}
{$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}

{$APPTYPE CONSOLE}

{$R *.res}

uses
  Windows, System.SysUtils, System.Classes, LZSS;

{$SETPEFLAGS IMAGE_FILE_RELOCS_STRIPPED}

procedure UnpackMF;
var
  FileStream1, FileStream2: TFileStream;
  MemoryStream1, MemoryStream2: TMemoryStream;
  StringList1: TStringList;
  LZSS1: TLZSS;
  LongWord1, NumOfFiles, DataStart, CompSize, DataPos, CompFlag, UncSize, DataMagic: LongWord;
  i: Integer;
  s, s2, DataExt, OutFolder: String;
begin
  FileStream1:=TFileStream.Create(ParamStr(1), fmOpenRead or fmShareDenyWrite);
  try
    FileStream1.ReadBuffer(LongWord1, 4);
    if LongWord1<>$464D then begin Writeln('Input file is not a valid MF UFFA archive file'); Readln; exit end;
    FileStream1.ReadBuffer(NumOfFiles, 4);
    FileStream1.ReadBuffer(DataStart, 4);
    s := IntToStr(NumOfFiles);
    i := Length(s);

    if ParamCount>1 then begin
      OutFolder := ExpandFileName(ParamStr(2));
      repeat if OutFolder[Length(OutFolder)]='\' then SetLength(OutFolder, Length(OutFolder)-1) until not (OutFolder[Length(OutFolder)]='\');
    end else OutFolder:=ExpandFileName(Copy(ParamStr(1),1,Length(ParamStr(1))-Length(ExtractFileExt(ParamStr(1)))));

    FileStream1.Position := $10;
    MemoryStream1:=TMemoryStream.Create; MemoryStream2:=TMemoryStream.Create; StringList1:=TStringList.Create;
    try
      if DataStart <> NumOfFiles*$10+$10 then StringList1.Append('#pad=true') else StringList1.Append('#pad=false');
      MemoryStream1.CopyFrom(FileStream1, NumOfFiles*$10);
      MemoryStream1.Position := 0;
      if not (DirectoryExists(OutFolder)) then CreateDir(OutFolder);
      for LongWord1:=1 to NumOfFiles do begin
        MemoryStream1.ReadBuffer(CompSize, 4);
        MemoryStream1.ReadBuffer(DataPos, 4);
        MemoryStream1.ReadBuffer(CompFlag, 4);
        MemoryStream1.ReadBuffer(UncSize, 4);
        s2 := IntToStr(LongWord1);
        s2 := StringOfChar('0', i-Length(s2)) + s2;

        if CompFlag=1 then begin
          FileStream1.Position := DataPos+$10;
          LZSS1:=TLZSS.Create;
          try
            LZSS1.Decode(FileStream1, MemoryStream2, UncSize);
          finally LZSS1.Free end;
          MemoryStream2.Position := 0;
          MemoryStream2.ReadBuffer(DataMagic, 4);
          if DataMagic=$464D then DataExt:='.mf' else DataExt:='.dat';
          MemoryStream2.SaveToFile(OutFolder+'\'+s2+DataExt);
          MemoryStream2.Clear;
          StringList1.Append(s2+DataExt+';'+'1');
          Writeln('['+s2+'/'+s+'] '+s2+DataExt);
        end else begin
          FileStream1.Position := DataPos;
          FileStream1.ReadBuffer(DataMagic, 4);
          if DataMagic=$464D then DataExt:='.mf' else DataExt:='.dat';
          FileStream1.Position := DataPos;
          FileStream2:=TFileStream.Create(OutFolder+'\'+s2+DataExt, fmCreate or fmOpenWrite or fmShareDenyWrite);
          try
            FileStream2.CopyFrom(FileStream1, UncSize);
          finally FileStream2.Free end;
          StringList1.Append(s2+DataExt+';'+'0');
          Writeln('['+s2+'/'+s+'] '+s2+DataExt);
        end;
      end;
      StringList1.SaveToFile(OutFolder+'\filelist.txt');
    finally MemoryStream1.Free; MemoryStream2.Free; StringList1.Free end;
  finally FileStream1.Free end;
end;

procedure PackMF;
const
  ZeroLongWord: LongWord=0;
  UffaMagic: LongWord=$41464655;
  FFByte: Byte=$FF;
var
  MemoryStream1: TMemoryStream;
  FileStream1, FileStream2: TFileStream;
  StringList1: TStringList;
  LZSS1: TLZSS;
  LongWord1, LongWord2, LongWord3, CmpFlag: LongWord;
  PadFlag: Boolean;
  s, s2, InputDir: String;
  i, x: Integer;
begin
  InputDir:=ExpandFileName(ParamStr(1));
  repeat if InputDir[Length(InputDir)]='\' then SetLength(InputDir, Length(InputDir)-1) until not (InputDir[Length(InputDir)]='\');
  if not (FileExists(InputDir+'\filelist.txt')) then begin Writeln(#39'filelist.txt'#39' not found in selected folder'); Readln; exit end;

  StringList1:=TStringList.Create;
  try
    StringList1.LoadFromFile(InputDir+'\filelist.txt');
    if StringList1.Count=0 then begin Writeln(#39'filelist.txt'#39' is empty'); Readln; exit end;

    for i:=0 to StringList1.Count-1 do begin
      s := LowerCase(StringList1[i]);
      LongWord1 := Pos('#pad=', s);
      if LongWord1>0 then break;
    end;
    if LongWord1>0 then begin
      if Copy(s,LongWord1+5)='true' then PadFlag:=True else PadFlag:=False;
      StringList1.Delete(i);
    end else PadFlag:=False;
    StringList1.Text:=Trim(StringList1.Text);
    if StringList1.Count=0 then begin Writeln(#39'filelist.txt'#39' is empty'); Readln; exit end;

    s := IntToStr(StringList1.Count);
    x := Length(s);

    MemoryStream1:=TMemoryStream.Create;
    try
      LongWord1 := $464D;
      MemoryStream1.WriteBuffer(LongWord1, 4);
      LongWord1 := StringList1.Count;
      MemoryStream1.WriteBuffer(LongWord1, 4);

      LongWord1 := LongWord1*$10+$10;
      if PadFlag=True then begin
        LongWord2 := LongWord1;
        LongWord1 := LongWord2 mod 2048;
        if LongWord1 > 0 then begin
          LongWord1 := LongWord2 + 2048 - LongWord1;
        end;
      end;
      MemoryStream1.WriteBuffer(LongWord1, 4);

      for i:=1 to StringList1.Count*4+1 do MemoryStream1.WriteBuffer(ZeroLongWord, 4);
      if PadFlag=True then for LongWord1:=MemoryStream1.Size to LongWord1-1 do MemoryStream1.WriteBuffer(FFByte, 1);
      MemoryStream1.Position := $10;

      if ParamCount>1 then FileStream1:=TFileStream.Create(ParamStr(2), fmCreate or fmOpenWrite or fmShareDenyWrite) else FileStream1:=TFileStream.Create(InputDir+'.mf', fmCreate or fmOpenWrite or fmShareDenyWrite);
      try
        FileStream1.Size := MemoryStream1.Size;
        for i:=0 to StringList1.Count-1 do begin
          s2 := IntToStr(i+1);
          s2 := StringOfChar('0', x-Length(s2)) + s2;

          LongWord1 := LastDelimiter(';',StringList1[i]);
          if LongWord1>0 then begin
            if Copy(StringList1[i],LongWord1+1)='1' then CmpFlag:=1 else CmpFlag:=0;
            StringList1[i] := Copy(StringList1[i], 1, LongWord1-1);
          end else CmpFlag:=0;

          LongWord3 := FileStream1.Position;
          FileStream2:=TFileStream.Create(InputDir+'\'+StringList1[i], fmOpenRead or fmShareDenyWrite);
          try
            LongWord1 := FileStream2.Size;
            if CmpFlag=1 then begin
              FileStream1.WriteBuffer(UffaMagic, 4);
              FileStream1.WriteBuffer(ZeroLongWord, 4);
              FileStream1.WriteBuffer(LongWord1, 4);
              FileStream1.WriteBuffer(ZeroLongWord, 4);
              LZSS1:=TLZSS.Create;
              try
                LZSS1.Encode(FileStream2, FileStream1, LongWord1, LongWord2);
              finally LZSS1.Free end;
              FileStream1.Position := LongWord3+4;
              FileStream1.WriteBuffer(LongWord2, 4);
              FileStream1.Position := FileStream1.Size;
              LongWord2 := LongWord2+$10;
              MemoryStream1.WriteBuffer(LongWord2, 4);
            end else begin
              FileStream1.CopyFrom(FileStream2, FileStream2.Size);
              MemoryStream1.WriteBuffer(LongWord1, 4);
            end;
          finally FileStream2.Free end;
          MemoryStream1.WriteBuffer(LongWord3, 4);
          MemoryStream1.WriteBuffer(CmpFlag, 4);
          MemoryStream1.WriteBuffer(LongWord1, 4);

          if i<StringList1.Count-1 then begin
            if PadFlag=True then LongWord2:=2048 else LongWord2:=16;
            LongWord1 := FileStream1.Size mod LongWord2;
            if LongWord1 > 0 then begin
              LongWord1 := FileStream1.Size + LongWord2 - 1 - LongWord1;
              for LongWord1:=FileStream1.Size to LongWord1 do FileStream1.WriteBuffer(FFByte, 1);
            end
          end;
          Writeln('['+s2+'/'+s+'] '+StringList1[i]);
        end;

        MemoryStream1.Position := 0;
        FileStream1.Position := 0;
        FileStream1.CopyFrom(MemoryStream1, MemoryStream1.Size);
      finally FileStream1.Free end;
    finally MemoryStream1.Free end;
  finally StringList1.Free end;
end;

begin
  try
    Writeln('MF UFFA Unpacker/Packer v1.0 by RikuKH3');
    Writeln('---------------------------------------');
    if ParamCount=0 then begin Writeln('Usage: '+ExtractFileName(ParamStr(0))+' <input file or folder> [output file or folder]'); Readln; exit end;
    if Pos('.', ExtractFileName(ParamStr(1)))=0 then PackMF else UnpackMF;
  except on E: Exception do begin Writeln(E.Message); Readln end end;
end.
