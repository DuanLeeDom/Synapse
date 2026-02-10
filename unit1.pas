unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, EditBtn,
  Menus, Process, Unit_Setup;

type
  { TForm1 }
  TForm1 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    Button4: TButton;
    Button5: TButton;
    Button6: TButton;
    Button7: TButton;
    button_process: TButton;
    ComboBox_options: TComboBox;
    DirectoryEdit: TDirectoryEdit;
    mnuPrincipal_Partes: TGroupBox;
    GroupBox_Source: TGroupBox;
    GroupBox_Export: TGroupBox;
    GroupBox_Console: TGroupBox;
    MenuItem1: TMenuItem;
    MenuItem10: TMenuItem;
    MenuItem11: TMenuItem;
    MenuItem12: TMenuItem;
    MenuItem13: TMenuItem;
    MenuItem14: TMenuItem;
    MenuItem15: TMenuItem;
    MenuItem16: TMenuItem;
    MenuItem17: TMenuItem;
    MenuItem18: TMenuItem;
    MenuItem19: TMenuItem;
    MenuItem2: TMenuItem;
    MenuItem20: TMenuItem;
    MenuItem21: TMenuItem;
    MenuItem22: TMenuItem;
    MenuItem23: TMenuItem;
    MenuItem24: TMenuItem;
    MenuItem25: TMenuItem;
    MenuItem26: TMenuItem;
    MenuItem27: TMenuItem;
    MenuItem28: TMenuItem;
    MenuItem29: TMenuItem;
    MenuItem3: TMenuItem;
    MenuItem30: TMenuItem;
    MenuItem31: TMenuItem;
    MenuItem4: TMenuItem;
    MenuItem5: TMenuItem;
    MenuItem6: TMenuItem;
    MenuItem7: TMenuItem;
    MenuItem8: TMenuItem;
    MenuItem9: TMenuItem;
    mnuPrincipal: TMainMenu;
    Separator1: TMenuItem;
    Separator2: TMenuItem;
    Separator3: TMenuItem;
    Separator4: TMenuItem;
    Separator5: TMenuItem;
    Separator6: TMenuItem;
    url_web: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    Memo_visual_console: TMemo;
    procedure button_processClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure MenuItem10Click(Sender: TObject);
  private
    FVerificado: Boolean;
    function GetFFmpegProfile(Index: Integer): string;
  public
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.FormCreate(Sender: TObject);
begin
  FVerificado := False; // Garante que a verificação comece do zero
end;

procedure TForm1.FormShow(Sender: TObject);
var
  DistroNome, Msg: string;
begin
  // 1. Evita que a verificação rode em loop (ex: ao minimizar/restaurar)
  if FVerificado then Exit;

  // 2. Verificação Profissional de Dependências via Unit_Setup
  if not Form_Setup.VerificarAmbiente then
  begin
    DistroNome := Form_Setup.NomeDoSistema;
    if DistroNome = '' then DistroNome := 'Linux';

    Msg := 'Sistema Detectado: ' + DistroNome + sLineBreak +
           '🛠️ Status: yt-dlp ou ffmpeg não encontrados.' + sLineBreak +
           'O instalador será iniciado agora para configurar seu ambiente.';

    MessageDlg('Assistente de Dependências', Msg, mtInformation, [mbOK], 0);

    // Abre o setup. Se o usuário fechar sem instalar (não retornar mrOk), encerra o app.
    if Form_Setup.ShowModal <> mrOk then
    begin
      Application.Terminate;
      Exit;
    end;

    // Se chegou aqui, instalou com sucesso. Força o foco de volta para a Unit1.
    Application.ProcessMessages;
    Self.BringToFront;
    Self.SetFocus;
  end;

  // 3. Configurações de Interface (Só rodam após validação do ambiente)
  // Preenche o ComboBox e define o item padrão
  ComboBox_options.Items.Clear;
  ComboBox_options.Items.Add('Master: DNxHR HQX (10-bit .MOV)');
  ComboBox_options.Items.Add('Proxy: DNxHR LB (Leve .MOV)');
  ComboBox_options.Items.Add('Audio: PCM High-End (24-bit .WAV)');
  ComboBox_options.ItemIndex := 0;

  // Força o componente a se desenhar na tela (evita ficar invisível no GTK/Qt)
  ComboBox_options.Invalidate;

  // 4. Define a pasta padrão de vídeos no Linux
  if DirectoryExists(GetEnvironmentVariable('HOME') + '/Vídeos') then
     DirectoryEdit.Directory := GetEnvironmentVariable('HOME') + '/Vídeos'
  else
     DirectoryEdit.Directory := GetCurrentDir;

  // 5. Finalização do Log Inicial
  Memo_visual_console.Lines.Clear;
  Memo_visual_console.Lines.Add('[SISTEMA] Ambiente verificado com sucesso.');
  Memo_visual_console.Lines.Add('[SISTEMA] Distribuição: ' + Form_Setup.NomeDoSistema);
  Memo_visual_console.Lines.Add('[OK] Tudo pronto para preparar sua mídia!');

  // Marca como verificado para não repetir este bloco
  FVerificado := True;
  Self.Repaint;
end;

procedure TForm1.MenuItem10Click(Sender: TObject);
begin
  Close;
end;

function TForm1.GetFFmpegProfile(Index: Integer): string;
begin
  // Perfis otimizados para edição no DaVinci Resolve (DNxHR)
  case Index of
    0: Result := '-c:v dnxhd -profile:v 4 -pix_fmt yuv422p10le -c:a pcm_s16le';
    1: Result := '-c:v dnxhd -profile:v 1 -pix_fmt yuv422p -c:a pcm_s16le';
    2: Result := '-vn -c:a pcm_s24le';
    else Result := '-c:v copy -c:a copy';
  end;
end;

procedure TForm1.button_processClick(Sender: TObject);
var
  AProcess: TProcess;
  Cmd, Ext: string;
begin
  // Validação básica de entrada
  if (url_web.Text = '') or (DirectoryEdit.Directory = '') then
  begin
    ShowMessage('Por favor, insira a URL e selecione a pasta de destino!');
    Exit;
  end;

  // Define extensão baseada na escolha do ComboBox (Audio = .wav, Vídeo = .mov)
  if ComboBox_options.ItemIndex = 2 then Ext := '.wav' else Ext := '.mov';

  Memo_visual_console.Clear;
  Memo_visual_console.Lines.Add('[INFO] Iniciando processo via Terminal...');

  AProcess := TProcess.Create(nil);
  try
    // Montagem do comando: baixa via yt-dlp e converte via FFmpeg em pipeline
    Cmd := Format('yt-dlp -P "%s" "%s" --exec "ffmpeg -y -i {} %s ''%s/davinci_ready_%s%s''"', [
      DirectoryEdit.Directory,
      url_web.Text,
      GetFFmpegProfile(ComboBox_options.ItemIndex),
      DirectoryEdit.Directory,
      FormatDateTime('hhnnss', Now),
      Ext
    ]);

    AProcess.Executable := '/usr/bin/bash';
    AProcess.Parameters.Add('-c');
    AProcess.Parameters.Add(Cmd);

    // poStderrToOutPut é vital para ver o progresso do ffmpeg no Memo
    AProcess.Options := [poUsePipes, poStderrToOutPut, poWaitOnExit];

    button_process.Enabled := False;
    button_process.Caption := 'AGUARDE...';
    Application.ProcessMessages;

    AProcess.Execute;

    // Carrega a saída do terminal no Memo para o usuário acompanhar
    Memo_visual_console.Lines.LoadFromStream(AProcess.Output);

    if AProcess.ExitCode <> 0 then
       Memo_visual_console.Lines.Add('[ERRO] Ocorreu um problema no processamento.')
    else
       Memo_visual_console.Lines.Add('[SUCESSO] Arquivo pronto para o DaVinci Resolve!');

  finally
    button_process.Enabled := True;
    button_process.Caption := 'PROCESSAR';
    AProcess.Free;
  end;
end;

end.
