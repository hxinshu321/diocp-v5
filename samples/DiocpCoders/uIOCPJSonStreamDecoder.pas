unit uIOCPJSonStreamDecoder;

interface

uses
  diocp.coder.baseObject, diocp.tcp.server, Classes, JSonStream, uIOCPFileLogger, SysUtils,
  uMyTypes, diocp.tcp.server;

const
  MAX_OBJECT_SIZE = 1024 * 1024 * 10;  //�������С 10M , ����10M �����Ϊ����İ��� 

type
  TIOCPJSonStreamDecoder = class(TIOCPDecoder)
  public
    /// <summary>
    ///   �����յ�������,����н��յ�����,���ø÷���,���н���
    /// </summary>
    /// <returns>
    ///   ���ؽ���õĶ���
    /// </returns>
    /// <param name="inBuf"> ���յ��������� </param>
    function Decode(const inBuf: TBufferLink; pvContext: TObject): TObject;
        override;
  end;


implementation

uses
  Windows, superobject, uZipTools, FileLogger, uByteTools, AnsiStringTools;

function TIOCPJSonStreamDecoder.Decode(const inBuf: TBufferLink; pvContext:
    TObject): TObject;
var
  lvJSonLength, lvStreamLength:Integer;
  lvMsg, lvData:String;


  lvBufData:PAnsiChar;
  lvStream:TMemoryStream;
  lvJsonStream:TJsonStream;
  lvBytes:TBytes;
  lvValidCount:Integer;
begin
  Result := nil;

  //��������е����ݳ��Ȳ�����ͷ���ȣ�����ʧ��<json�ַ�������,������>
  lvValidCount := inBuf.validCount;
  if (lvValidCount < SizeOf(Integer) + SizeOf(Integer)) then
  begin
    Exit;
  end;

  //��¼��ȡλ��
  inBuf.markReaderIndex;
  inBuf.readBuffer(@lvJSonLength, SizeOf(Integer));
  inBuf.readBuffer(@lvStreamLength, SizeOf(Integer));


  lvJSonLength := TByteTools.swap32(lvJSonLength);
  lvStreamLength := TByteTools.swap32(lvStreamLength);


  ///������ݹ���
  if (lvJSonLength > MAX_OBJECT_SIZE)
     or (lvStreamLength > MAX_OBJECT_SIZE)
     or ((lvJSonLength + lvStreamLength) >= MAX_OBJECT_SIZE)  then
  begin
    
    lvMsg := Format('������������������δ�������ݰ���С%d, %d, ������ݰ�(%d)',
      [lvJSonLength , lvStreamLength, MAX_OBJECT_SIZE]);
    TFileLogger.instance.logMessage(lvMsg, 'DECODER_Warning_');

    //����������
    inBuf.clearBuffer;

    lvJsonStream := TJsonStream.Create;
    lvJsonStream.setResult(False);
    lvJsonStream.setResultMsg('������������������δ�������ݰ���С');
    Result := lvJsonStream;
    Exit;
  end;
  

  //��������е����ݲ���json�ĳ��Ⱥ�������<˵�����ݻ�û����ȡ���>����ʧ��
  lvValidCount := inBuf.validCount;
  if lvValidCount < (lvJSonLength + lvStreamLength) then
  begin
    //����buf�Ķ�ȡλ��
    inBuf.restoreReaderIndex;
    exit;
  end else if (lvJSonLength + lvStreamLength) = 0 then
  begin
    //������Ϊ0<����0>�ͻ��˿���������Ϊ�Զ�����ʹ��
    TIOCPFileLogger.logMessage('���յ�һ��[00]����!', 'DECODER_Warning_');
    Exit;
  end;



  //����ɹ�
  lvJsonStream := TJsonStream.Create;
  Result := lvJsonStream;

  //��ȡjson�ַ���
  if lvJSonLength > 0 then
  begin
    SetLength(lvBytes, lvJSonLength);
    ZeroMemory(@lvBytes[0], lvJSonLength);
    inBuf.readBuffer(@lvBytes[0], lvJSonLength);

    lvData := TAnsiStringTools.Utf8Bytes2AnsiString(lvBytes);

    lvJsonStream.Json := SO(lvData);
  end else
  begin
    TFileLogger.instance.logMessage('���յ�һ��JSonΪ�յ�һ����������!', 'DECODER_Warning_');
  end;


  //��ȡ������ 
  if lvStreamLength > 0 then
  begin
    GetMem(lvBufData, lvStreamLength);
    try
      inBuf.readBuffer(lvBufData, lvStreamLength);
      lvJsonStream.Stream.Size := 0;
      lvJsonStream.Stream.WriteBuffer(lvBufData^, lvStreamLength);

      //��ѹ��
      if lvJsonStream.Json.B['config.stream.zip'] then
      begin
        //��ѹ
        TZipTools.unCompressStreamEX(lvJsonStream.Stream);
      end;
    finally
      FreeMem(lvBufData, lvStreamLength);
    end;
  end;
end;

end.