unit uUIResources;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Controls, StdCtrls, Graphics, Process, uProcessos;

type
  { TProcessoControlado
    Controle de um processo de conversão (yt-dlp/ffmpeg) vinculado a um
    botão da interface, permitindo cancelamento e rótulos Processar/Cancelar. }
  TProcessoControlado = class
  private
    FProcessoAtivo : TProcess;
    FCancelado     : Boolean;
    FBotao         : TButton;
    FLabelProcessar: string;
    FLabelCancelar : string;

    procedure MatarProcessoFilho;
  public
    constructor Create(ABotao: TButton;
                       const ALabelProcessar: string = 'PROCESSAR';
                       const ALabelCancelar: string  = 'Cancelar');

    procedure IniciarProcesso;
    procedure FinalizarProcesso;
    procedure RegistrarProcesso(AProcesso: TProcess);
    procedure Cancelar;
    function EstaCancelado: Boolean;
  end;

  { TSystemAssistant
    Recursos visuais da interface: tooltips de ajuda (ícone ⓘ) e
    recarga de listas dependentes. (Pesquisa de hardware fica em
    uHardwareDetector.) }
  TSystemAssistant = class
  private
    function WrapText(AText: string; AMaxChars: Integer = 50): string;
  public
    procedure AddHelp(AControl: TControl; const AHelpText: string;
                      OffsetX: Integer; OffsetY: Integer;
                      AMaxWidth: Integer = 50);
    procedure RecarregarDependentes(
                      const ADependentes: array of TComboBox);
  end;

implementation

{ TProcessoControlado }

procedure TProcessoControlado.MatarProcessoFilho;
var
  Pid: LongWord;
begin
  { A versao anterior montava 'taskkill /F /IM ffmpeg.exe /T', que encerrava
    o ffmpeg de qualquer programa da maquina, inclusive de outros usuarios,
    e nunca chegou a ser executada. O que e preciso e derrubar a arvore que
    nasceu deste processo, e nada mais. }
  if not Assigned(FProcessoAtivo) then
    Exit;

  Pid := LongWord(FProcessoAtivo.ProcessID);
  if (Pid = 0) or (Pid = LongWord(GetProcessID)) then
    Exit;

  TGerenciadorProcessos.EncerrarArvorePorPid(DWORD(Pid));
end;

constructor TProcessoControlado.Create(ABotao: TButton;
  const ALabelProcessar: string; const ALabelCancelar: string);
begin
  inherited Create;
  FBotao         := ABotao;
  FLabelProcessar:= ALabelProcessar;
  FLabelCancelar := ALabelCancelar;
  FProcessoAtivo := nil;
  FCancelado     := False;
end;

procedure TProcessoControlado.IniciarProcesso;
begin
  FCancelado := False;
  if Assigned(FBotao) then
  begin
    FBotao.Caption := FLabelCancelar;
    FBotao.Enabled := True;
  end;
end;

procedure TProcessoControlado.FinalizarProcesso;
begin
  FProcessoAtivo := nil;
  FCancelado     := False;
  if Assigned(FBotao) then
  begin
    FBotao.Caption := FLabelProcessar;
    FBotao.Enabled := True;
  end;
end;

procedure TProcessoControlado.RegistrarProcesso(AProcesso: TProcess);
begin
  FProcessoAtivo := AProcesso;
end;

procedure TProcessoControlado.Cancelar;
var
  Cmd: string;
begin
  FCancelado := True;

  if Assigned(FProcessoAtivo) and FProcessoAtivo.Running then
  begin
    try
      Cmd := 'q';
      FProcessoAtivo.Input.Write(Cmd[1], Length(Cmd));
    Except
    end;
  end;

  if Assigned(FProcessoAtivo) and FProcessoAtivo.Running then
  begin
    { Terminar so o pai deixaria o ffmpeg que ele iniciou rodando e ainda
      gravando. A arvore e derrubada antes de soltar a referencia, porque
      depois disso nao haveria mais de onde tirar o PID. }
    MatarProcessoFilho;
    FProcessoAtivo.Terminate(1);
    FProcessoAtivo := nil;
  end;
end;

function TProcessoControlado.EstaCancelado: Boolean;
begin
  Result := FCancelado;
end;

{ TSystemAssistant }

function TSystemAssistant.WrapText(AText: string; AMaxChars: Integer): string;
var
  i, LineLen: Integer;
begin
  Result  := '';
  LineLen := 0;
  for i := 1 to Length(AText) do
  begin
    Result := Result + AText[i];
    Inc(LineLen);
    if (LineLen >= AMaxChars) and (AText[i] = ' ') then
    begin
      Result  := Result + LineEnding;
      LineLen := 0;
    end;
  end;
end;

procedure TSystemAssistant.AddHelp(AControl: TControl;
  const AHelpText: string; OffsetX: Integer; OffsetY: Integer;
  AMaxWidth: Integer);
var
  HelpIcon: TLabel;
begin
  if not Assigned(AControl) then Exit;

  HelpIcon        := TLabel.Create(AControl.Owner);
  HelpIcon.Parent := AControl.Parent;

  HelpIcon.Caption    := 'ⓘ';
  HelpIcon.Font.Color := clGray;
  HelpIcon.Font.Style := [fsBold];
  HelpIcon.Cursor     := crHandPoint;
  HelpIcon.Hint       := WrapText(AHelpText, AMaxWidth);
  HelpIcon.ShowHint   := True;

  HelpIcon.Left := AControl.Left + AControl.Width + OffsetX;
  HelpIcon.Top  := AControl.Top + AControl.Height - (HelpIcon.Height div 2) + OffsetY;

  HelpIcon.BringToFront;
end;

procedure TSystemAssistant.RecarregarDependentes(
  const ADependentes: array of TComboBox);
var
  i: Integer;
begin
  for i := 0 to High(ADependentes) do
  begin
    ADependentes[i].Items.Clear;
    ADependentes[i].ItemIndex := -1;
  end;
end;

end.
