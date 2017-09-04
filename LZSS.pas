{***************************************************************
 *
 * Unit Name: LZSS
 * Purpose  : スライド辞書法(LZSS)による圧縮
 * Author   : Fuwa Sakaki
 * History  : 2002/12/13
              参考
              奥村晴彦著『C言語による最新アルゴリズム事典』／技術評論社

              yaneSDK
 *
 ****************************************************************}

unit LZSS;

interface

uses
  Classes, Windows, ByteStream;

const
  LZSS_RING_BUFF = 4096;
  LZSS_LONGEST_MATCH = 18;

type
  TLZSS = class
  protected
    mOutCount: Cardinal; // 出力カウンタ

    mMatchPos, mMatchLen: Integer;

    mDad: array[0..LZSS_RING_BUFF] of Integer;
    mLSon: array[0..LZSS_RING_BUFF] of Integer;
    mRSon: array[0..LZSS_RING_BUFF+256] of Integer;

    // テキストバッファ
    mText: array[0..LZSS_LONGEST_MATCH+LZSS_RING_BUFF-1] of Byte;

    procedure InitTree;
    procedure InsertNode(iNode: Integer);
    procedure DeleteNode(p: Integer);

    function CommonEncode(iStream, oStream: TStream; iSize: Cardinal; var oSize: Cardinal; iWriter: TByteWriter; iReader: TByteReader): Boolean;
    function CommonDecode(iStream, oStream: TStream; iSize: Cardinal; iWriter: TByteWriter; iReader: TByteReader): Boolean;
  public
    function Encode(iStream, oStream: TStream; iSize: Cardinal; var oSize: Cardinal): Boolean;
    function Decode(iStream, oStream: TStream; iSize: Cardinal): Boolean;

  end;



implementation

const
  TREE_NIL = LZSS_RING_BUFF; // 木の末端

function TLZSS.CommonEncode(iStream, oStream: TStream; iSize: Cardinal; var oSize: Cardinal; iWriter: TByteWriter; iReader: TByteReader): Boolean;
var
  i, c, len, r, s, lastmatchlen, codeptr: Integer;
  code: array[0..17] of Byte;
  mask: Byte;
  aSize: Cardinal;
begin
  Result := False;

  aSize := iSize-8; // これを上回るならば圧縮する価値が無い

  self.InitTree;
  code[0]:= 0; codeptr := 1; mask := 1;
  s := 0; r := LZSS_RING_BUFF - LZSS_LONGEST_MATCH;

  // バッファの初期化
  for i:=s to r-1 do
  begin
    mText[i] := 0; 
  end;

  len := 0;
  for i:=0 to LZSS_LONGEST_MATCH-1 do
  begin
    c := iReader.GetByte;
    Dec(iSize);
    if (iSize <= 0) then Exit;
    mText[r+len] := c;
    Inc(len);
  end;

  if len = 0 then Exit;
  
  for i:=1 to LZSS_LONGEST_MATCH do Self.InsertNode(r-i);
  Self.InsertNode(r);

  oSize := 0;

  repeat
    if mMatchLen > len then mMatchLen := len;
    if mMatchLen < 3 then
    begin
      mMatchLen := 1; code[0] := code[0] or mask;
      code[codeptr] := Byte(mText[r]);
      Inc(codeptr);
    end
    else
    begin
      code[codeptr] := mMatchPos;
      Inc(codeptr);
      code[codeptr] := (((mMatchpos shr 4) and $F0) or (mMatchlen-3));
      Inc(codeptr);
    end;
    mask := mask shl 1;
    if (mask = 0) then
    begin
      oSize := oSize + codeptr;
      if aSize <= oSize then Exit; // 入力より出力サイズが大きくなった
      for i:=0 to codeptr-1 do iWriter.PutByte(code[i]);
      code[0] := 0; codeptr := 1; mask := 1;
    end;

    lastmatchlen := mMatchlen;
    for i:=0 to lastmatchlen-1 do
    begin
      if iSize = 0 then Break;
      Dec(iSize);
      c := iReader.GetByte;
      Self.DeleteNode(s); mText[s] := c;
      if s < LZSS_LONGEST_MATCH-1 then
        mText[s+LZSS_RING_BUFF] := c;
      s := (s+1) and (LZSS_RING_BUFF - 1);
      r := (r+1) and (LZSS_RING_BUFF - 1);
      Self.InsertNode(r);
    end;
    while (i<lastmatchlen) do
    begin
      Self.DeleteNode(s);
      s := (s+1) and (LZSS_RING_BUFF-1);
      r := (r+1) and (LZSS_RING_BUFF-1);
      Dec(len);
      if len > 0 then Self.InsertNode(r);

      Inc(i);
    end;
  until len <= 0;

  if (codeptr>1) then
  begin
    oSize := oSize+codeptr;
    if (not (aSize <= oSize)) then
    begin
      for i:=0 to codeptr-1 do iWriter.PutByte(code[i]);
    end;

  end;

  if (aSize <= oSize) then Exit;

  Result := True; //圧縮成功！


end;

//  エンコードする
//
// 引数
// 入力ストリーム、出力ストリーム、エンコードするファイルのサイズ、エンコードされた戻り値（var）
// 戻り値
// 成功すればTrue
function TLZSS.Encode(iStream, oStream: TStream; iSize: Cardinal; var oSize: Cardinal): Boolean;
var
  aWriter: TByteWriter;
  aReader: TByteReader;
begin
  aReader := TByteReader.Create(iStream);
  try
    aWriter := TByteWriter.Create(oStream);
    try
      Result := CommonEncode(iStream, oStream,iSize,oSize, aWriter, aReader );
    finally
      aWriter.Free;
    end;
  finally
    aReader.Free;
  end;
end;

function TLZSS.Decode(iStream, oStream: TStream; iSize: Cardinal): Boolean;
var
  aWriter: TByteWriter;
  aReader: TByteReader;
begin
  aReader := TByteReader.Create(iStream);
  try
    aWriter := TByteWriter.Create(oStream);
    try
      Result := CommonDecode(iStream, oStream,iSize, aWriter, aReader );
    finally
      aWriter.Free;
    end;
  finally
    aReader.Free;
  end;
end;

function TLZSS.CommonDecode(iStream, oStream: TStream;  iSize: Cardinal; iWriter: TByteWriter; iReader: TByteReader): Boolean;
var
  i,j,k,r,c: Integer;
  aFlag: DWORD;

begin
  Result := True;

  r := LZSS_RING_BUFF - LZSS_LONGEST_MATCH;

  FillChar(mText, LZSS_LONGEST_MATCH+LZSS_RING_BUFF-1, 0); // ゼロクリア
  aFlag := 0;

 while(True) do
 begin
   aFlag := aFlag shr 1;
   if (aFlag and 256) = 0 then
   begin
     c := iReader.GetByte;
     aFlag := c or $FF00;
   end;
   if (aFlag and 1) = 1 then
   begin
     c := iReader.GetByte;
     iWriter.PutByte(c);

     Dec(iSize);
     if iSize = 0 then Exit;
     mText[r] := c;
     Inc(r);
     r := r and (LZSS_RING_BUFF-1);
   end
   else
   begin
     i := iReader.GetByte;
     j := iReader.GetByte;

     i := i or ((j and $F0) shl 4);
     j := (j and $0F) +2;

     k := 0;
     while k <= j do
     begin
       c := Integer(mText[(i+k) and (LZSS_RING_BUFF-1)]);
       iWriter.PutByte(c);

       Dec(iSize);
       if iSize =0 then Exit;

       mText[r] := c;
       Inc(r);
       r := r and (LZSS_RING_BUFF-1);
       
       Inc(k);
     end;
     
   end;

 end;

end;



// 木の初期化
procedure TLZSS.InitTree;
var
  i: Integer;
begin
  for i:=LZSS_RING_BUFF+1 to LZSS_RING_BUFF+256 do mRSon[i] := TREE_NIL;
  for i:=0 to LZSS_RING_BUFF do mDad[i] := TREE_NIL;
end;

// ノードの追加
procedure TLZSS.InsertNode(iNode: Integer);
var
  i, p, cmp, key_num: Integer;
  //key : PChar;

begin
  cmp:=1; key_num:=iNode; p:=LZSS_RING_BUFF+ 1+ Integer(mText[key_num]); 
  mRSon[iNode] := TREE_NIL; mLSon[iNode]:= TREE_NIL;
  mMatchLen := 0;

  while (True) do
  begin
    if cmp>0 then
    begin
      if mRSon[p] <> TREE_NIL then
        p := mRSon[p]
      else
      begin
        mRSon[p] := iNode;
        mDad[iNode] := p;
        Exit;
      end;
    end
    else
    begin
      if mLSon[p] <> TREE_NIL then
        p := mLSon[p]
      else
      begin
        mLSon[p] := iNode;
        mDad[iNode] := p;
        Exit;
      end;
    end;

    for i:=1 to LZSS_LONGEST_MATCH-1 do
    begin
      cmp := Integer(mText[key_num+i])-Integer(mText[p+i]);
      if cmp <> 0 then Break;
    end;
    if i > mMatchLen then
    begin
      mMatchPos := p;
      mMatchLen := i;
      if i >= LZSS_LONGEST_MATCH then Break;
    end;
  end;
  mDad[iNode] := mDad[p]; mLSon[iNode]:=mLson[p]; mRSon[iNode]:= mRSon[p];
  mDad[mLSon[p]] := iNode; mDad[mRSon[p]] := iNode;

  if mRSon[mDad[p]] = p then
    mRSon[mDad[p]] := iNode
  else
    mLSon[mDad[p]] := iNode;

  mDad[p] := TREE_NIL;

end;

procedure TLZSS.DeleteNode(p: Integer);
var
  q: Integer;
begin
  if (mDad[p] = TREE_NIL) then Exit;
  if (mRSon[p] = TREE_NIL) then q:= mLSon[p]
  else if (mLSon[p] = TREE_NIL) then q := mRSon[p]
  else
  begin
    q := mLSon[p];
    if (mRSon[q] <> TREE_NIL) then
    begin
      repeat
        q := mRSon[q];
      until mRSon[q] = TREE_NIL;
      
      mRSon[mDad[q]] := mLSon[q];
      mDad[mLSon[q]] := mDad[q];
      mLSon[q] := mLSon[p];
      mDad[mLSon[p]] := q;

    end;
    mRSon[q] := mRSon[p];
    mDad[mRSon[p]] := q;
  end;
  mDad[q] := mDad[p];

  if (mRSon[mDad[p]] = p) then
    mRSon[mDad[p]] := q
  else
    mLSon[mDad[p]] := q;
  mDad[p] := TREE_NIL;



end;



end.

