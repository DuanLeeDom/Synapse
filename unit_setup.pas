unit Unit_Setup;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ComCtrls,
  ExtCtrls, Process, Unix;

type
  { TForm_Setup }
  TForm_Setup = class(TForm)
    btn_instalar: TButton;
    Button1: TButton;
    GroupBox1: TGroupBox;
    GroupBox2: TGroupBox;
    lbl_info: TLabel;
    Memo_Log: TMemo;
    ProgressBar1: TProgressBar;
    procedure btn_instalarClick(Sender: TObject);
  private
    FDistroID: string;
    FDistroName: string;
    procedure IdentificarSistema;
    function ProgramaExiste(NomeBinario: string): Boolean;
  public
    function VerificarAmbiente: Boolean;
    property NomeDoSistema: string read FDistroName;
  end;

var
  Form_Setup: TForm_Setup;

implementation

{$R *.lfm}

procedure TForm_Setup.IdentificarSistema;
var
  List: TStringList;
  i: Integer;
begin
  FDistroID := 'generic';
  FDistroName := 'Linux';
  if FileExists('/etc/os-release') then
  begin
    List := TStringList.Create;
    try
      List.LoadFromFile('/etc/os-release');
      for i := 0 to List.Count - 1 do
      begin
        if Pos('PRETTY_NAME=', List[i]) = 1 then
          FDistroName := StringReplace(Copy(List[i], 13, Length(List[i])), '"', '', [rfReplaceAll]);
        if (Pos('ID=', List[i]) = 1) or (Pos('ID_LIKE=', List[i]) = 1) then
        begin
          if Pos('arch', List[i]) > 0 then FDistroID := 'arch';
          if (Pos('ubuntu', List[i]) > 0) or (Pos('debian', List[i]) > 0) then FDistroID := 'debian';
          if Pos('fedora', List[i]) > 0 then FDistroID := 'fedora';
        end;
      end;
    finally
      List.Free;
    end;
  end;
end;

function TForm_Setup.ProgramaExiste(NomeBinario: string): Boolean;
  // S: string;
begin
  // Uso do 'command -v' para encontrar o programa em qualquer lugar do sistema
  // Result := RunCommand('/usr/bin/bash', ['-c', 'command -v ' + NomeBinario], S);
  Result := fpSystem('which' + NomeBinario + '> /dev/null 2>&1') = 0;
end;

function TForm_Setup.VerificarAmbiente: Boolean;
begin
  IdentificarSistema;
  // Retorna TRUE se ambos os comandos existirem (retorno 0)
  // Retorna FALSE se faltar qualquer um deles
  Result := (fpSystem('which yt-dlp > /dev/null 2>&1') = 0) and
            (fpSystem('which ffmpeg > /dev/null 2>&1') = 0);
  // Result := ProgramaExiste('yt-dlp') and ProgramaExiste('ffmpeg');
end;

procedure TForm_Setup.btn_instalarClick(Sender: TObject);
var
  P: TProcess;
begin
  btn_instalar.Enabled := False;
  ProgressBar1.Style := pbstMarquee;
  Memo_Log.Lines.Add('[INFO] Iniciando instalação para ' + FDistroName);

  P := TProcess.Create(nil);
  try
    P.Executable := '/usr/bin/pkexec';

    // Lógica Universal por Família de Distro
    if FDistroID = 'arch' then
    begin
      P.Parameters.Add('pacman'); P.Parameters.Add('-S'); P.Parameters.Add('--noconfirm');
      P.Parameters.Add('yt-dlp'); P.Parameters.Add('ffmpeg');
    end
    else if FDistroID = 'debian' then
    begin
      P.Parameters.Add('sh'); P.Parameters.Add('-c');
      P.Parameters.Add('apt-get update && apt-get install -y yt-dlp ffmpeg');
    end
    else if FDistroID = 'fedora' then
    begin
      P.Parameters.Add('dnf'); P.Parameters.Add('install'); P.Parameters.Add('-y');
      P.Parameters.Add('yt-dlp'); P.Parameters.Add('ffmpeg');
    end;

    P.Options := [poWaitOnExit, poUsePipes, poStderrToOutPut];
    P.Execute;
    Memo_Log.Lines.LoadFromStream(P.Output);

    if P.ExitCode = 0 then
    begin
      ShowMessage('Instalação completa!');
      Self.ModalResult := mrOk; // ESTA LINHA FECHA O SETUP E LIBERA O UNIT1
    end
    else
      Memo_Log.Lines.Add('[ERRO] Falha na instalação.');
  finally
    btn_instalar.Enabled := True;
    ProgressBar1.Style := pbstNormal;
    P.Free;
  end;
end;

end.
