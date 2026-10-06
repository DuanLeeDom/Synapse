program synapse;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces,
  Forms, Controls, runtimetypeinfocontrols, uMainView,
  uDependencyManager, uMediaPipeline, uAboutView, uDownloadService, uUIResources,
  uHardwareDetector, uProcessos;

{R *.res}

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Title:='Synapse';
  Application.Scaled:=True;
  Application.Initialize;

  {$IFDEF UNIX}
  if not TDependencyManager.VerificarTudo then
  begin
    Application.CreateForm(TfrmSetup, frmSetup);
    if frmSetup.ShowModal <> mrOk then
    begin
      Application.Terminate;
      Exit;
    end;
  end;
  {$ENDIF}
  Application.CreateForm(TfrmMainView, frmMainView);
  Application.Run;

  { Fechar o handle do Job dispara KILL_ON_JOB_CLOSE. Sem esta liberacao, um
    ffmpeg, yt-dlp ou magick em andamento continuaria gravando arquivos
    depois que a janela ja sumiu da tela. }
  TGerenciadorProcessos.EncerrarTodos;
  TGerenciadorProcessos.LiberarJob;
end.
