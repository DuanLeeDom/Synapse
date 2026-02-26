unit uSetup;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ComCtrls,
  ExtCtrls, Process;

type
  { TfrmSetup }
  TfrmSetup = class(TForm)
    btn_instalar: TButton;
    Button1: TButton; // Botão Cancelar/Sair
    GroupBox1: TGroupBox;
    GroupBox2: TGroupBox;
    lbl_info: TLabel;
    Memo_Log: TMemo;
    ProgressBar1: TProgressBar;
    procedure btn_instalarClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure FormShow(Sender: TObject); // Adicionei isso para garantir a leitura
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
  frmSetup: TfrmSetup;

implementation

{$R *.lfm}

procedure TfrmSetup.IdentificarSistema;
var
  List: TStringList;
  i: Integer;
begin
  FDistroID := 'generic';
  FDistroName := 'Linux'; // Valor padrão

  if FileExists('/etc/os-release') then
  begin
    List := TStringList.Create;
    try
      List.LoadFromFile('/etc/os-release');
      for i := 0 to List.Count - 1 do
      begin
        // Pega o nome bonito (ex: "Arch Linux")
        if Pos('PRETTY_NAME=', List[i]) = 1 then
          FDistroName := StringReplace(Copy(List[i], 13, Length(List[i])), '"', '', [rfReplaceAll]);

        // Identifica a base (arch, debian, fedora)
        if (Pos('ID=', List[i]) = 1) or (Pos('ID_LIKE=', List[i]) = 1) then
        begin
          if Pos('arch', List[i]) > 0 then FDistroID := 'arch';
          if (Pos('ubuntu', List[i]) > 0) or (Pos('debian', List[i]) > 0) then FDistroID := 'debian';
          if Pos('fedora', List[i]) > 0 then FDistroID := 'fedora';
          if Pos('suse', List[i]) > 0 then FDistroID := 'opensuse';
        end;
      end;
    finally
      List.Free;
    end;
  end;
end;

function TfrmSetup.ProgramaExiste(NomeBinario: string): Boolean;
begin
  // CORREÇÃO: Adicionado espaço após o 'which '
  // O retorno 0 significa sucesso (encontrou o programa)
  //Result := fpSystem('which ' + NomeBinario + ' > /dev/null 2>&1') = 0;
end;

function TfrmSetup.VerificarAmbiente: Boolean;
begin
  IdentificarSistema;

  // Verifica se AMBOS existem
  Result := ProgramaExiste('yt-dlp') and ProgramaExiste('ffmpeg');
end;

procedure TfrmSetup.FormShow(Sender: TObject);
begin
  // Garante que sabemos qual é o sistema assim que a tela abre
  IdentificarSistema;
  lbl_info.Caption := 'Sistema Detectado: ' + FDistroName;
end;

procedure TfrmSetup.btn_instalarClick(Sender: TObject);
var
  P: TProcess;
begin
  // Se não identificou ainda, identifica agora
  if FDistroID = '' then IdentificarSistema;

  btn_instalar.Enabled := False;
  Button1.Enabled := False; // Trava o botão cancelar durante a instalação
  ProgressBar1.Style := pbstMarquee; // Animação de "carregando"
  Memo_Log.Lines.Add('[INFO] Iniciando instalação para base: ' + FDistroID);

  P := TProcess.Create(nil);
  try
    P.Executable := '/usr/bin/pkexec'; // Pede senha de root visualmente

    // Lógica Universal por Família de Distro
    if FDistroID = 'arch' then
    begin
      P.Parameters.Add('pacman');
      P.Parameters.Add('-S');
      P.Parameters.Add('--noconfirm'); // Não pergunta S/N
      P.Parameters.Add('yt-dlp');
      P.Parameters.Add('ffmpeg');
    end
    else if FDistroID = 'debian' then
    begin
      // Debian/Ubuntu precisam de sh -c para rodar update && install
      P.Parameters.Add('sh');
      P.Parameters.Add('-c');
      P.Parameters.Add('apt-get update && apt-get install -y yt-dlp ffmpeg');
    end
    else if FDistroID = 'fedora' then
    begin
      P.Parameters.Add('dnf');
      P.Parameters.Add('install');
      P.Parameters.Add('-y');
      P.Parameters.Add('yt-dlp');
      P.Parameters.Add('ffmpeg');
    end
    else if FDistroID = 'opensuse' then
    begin
       P.Parameters.Add('zypper');
       P.Parameters.Add('install');
       P.Parameters.Add('-n');
       P.Parameters.Add('yt-dlp');
       P.Parameters.Add('ffmpeg');
    end
    else
    begin
      Memo_Log.Lines.Add('[ERRO] Distribuição não suportada automaticamente.');
      Memo_Log.Lines.Add('Instale yt-dlp e ffmpeg manualmente.');
      Exit;
    end;

    P.Options := [poWaitOnExit, poUsePipes, poStderrToOutPut];
    P.Execute;

    // Captura o log para mostrar ao usuário
    Memo_Log.Lines.LoadFromStream(P.Output);

    if P.ExitCode = 0 then
    begin
      Memo_Log.Lines.Add('[SUCESSO] Instalação concluída!');
      ShowMessage('Instalação completa! O programa irá iniciar.');

      // IMPORTANTE: Isso avisa o .lpr que deu tudo certo
      Self.ModalResult := mrOk;
    end
    else
    begin
      Memo_Log.Lines.Add('[ERRO] Falha na instalação. Código: ' + IntToStr(P.ExitCode));
      ShowMessage('Ocorreu um erro. Veja o log.');
    end;
  finally
    btn_instalar.Enabled := True;
    Button1.Enabled := True;
    ProgressBar1.Style := pbstNormal;
    P.Free;
  end;
end;

procedure TfrmSetup.Button1Click(Sender: TObject);
begin
  // CORREÇÃO: Isso avisa o .lpr que o usuário desistiu
  Self.ModalResult := mrCancel;
end;

end.
