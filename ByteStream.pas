{***************************************************************
 *
 * Unit Name: ByteStream
 * Purpose  : 一バイトごとにデータを読み書きするクラス
 * Author   : Fuwa Sakaki
 * History  : 2002/12/12
 *
 ****************************************************************}

unit ByteStream;

interface

uses
  Classes, Windows;

const
  BYTE_STREAM_BUFF_LENGTH = 4095;

type
  TByteWriter = class
  protected
    mStream: TStream;
    mBuff: array[0..BYTE_STREAM_BUFF_LENGTH] of Byte;
    mBuffCount: Cardinal; //バッファに貯められたデータのバイト数
  public
    constructor Create(iStream: TStream);
    destructor Destroy; override;
    procedure Flash;
    procedure PutByte(ibyte: Byte);
  end;

  TByteReader = class
  protected
    mBuffIndex, mBuffDataSize: Cardinal;
    mStream: TStream;
    mBuff: array[0..BYTE_STREAM_BUFF_LENGTH] of Byte;
    mIsEOF: Boolean;
  public
    constructor Create(iStream: TStream);
    destructor Destroy; override;
    function GetByte: Byte;

    property IsEOF: Boolean read mIsEOF;
  end;
 

implementation

constructor TByteReader.Create(iStream: TStream);
begin
  mBuffIndex := 0;
  mBuffDataSize := 0;
  mStream := iStream;
  mIsEOF := False;
end;

destructor TByteReader.Destroy;
begin
  inherited Destroy;
end;
 
 

function TByteReader.GetByte: Byte;
begin
  Result := 0;

  // ストリームから読み出す場合
  if (mBuffDataSize <= 0) or (mBuffIndex >= mBuffDataSize) then
  begin
    if mIsEOF then Exit;
    mBuffDataSize := mStream.Read(mBuff, BYTE_STREAM_BUFF_LENGTH);
    if (mBuffDataSize < BYTE_STREAM_BUFF_LENGTH) then mIsEOF := True;
    mBuffIndex := 0;
  end;
  Result := mBuff[mBuffIndex];
  Inc(mBuffIndex);

end;

//-----------------------------------------------
// TByteWriter
//-----------------------------------------------
constructor TByteWriter.Create(iStream: TStream);
begin
  mBuffCount := 0;
  mStream := iStream;
end;

destructor TByteWriter.Destroy;
begin
  Self.Flash;
  inherited Destroy;
end;

procedure TByteWriter.Flash;
begin
  // ストリーム用バッファ処理
  if mBuffCount > 0 then mStream.Write(mBuff, mBuffCount);
  mBuffCount := 0;
end;

procedure TByteWriter.PutByte(ibyte: Byte);
begin

  mBuff[mBuffCount] := iByte;
  Inc(mBuffCount);
  if mBuffCount >= BYTE_STREAM_BUFF_LENGTH then
  begin
    mStream.Write(mBuff, mBuffCount);
    mBuffCount := 0;
  end;
end;
 

end.