unit uUpdater;

{ uUpdater

  Camada de interface do verificador de atualizacoes. Faz a consulta em uma
  thread de fundo (uUpdaterCore.ConsultarUltimaRelease) e mostra o resultado na
  thread principal. Nao baixa nem instala nada: apenas avisa e oferece abrir a
  pagina de download.

  O nucleo de rede/parsing fica em uUpdaterCore, sem LCL, o que permite testa-lo
  em console. }

{$mode ObjFPC}{$H+}
{$CODEPAGE UTF8}

interface

uses
  Classes, SysUtils;

{ Dispara a checagem em segundo plano e mostra o resultado na thread da
  interface. AInterativo=True mostra sempre (inclusive "ja atualizado" ou o
  erro); False so mostra quando ha atualizacao (usado na abertura do app). }
procedure VerificarAtualizacoesAsync(AInterativo: Boolean);

implementation

uses
  Controls, Forms, Dialogs, LCLIntf, uVersao, uUpdaterCore;

procedure AbrirURL(const AUrl: string);
var
  Link: UnicodeString;
  Abriu: Boolean;
begin
  Link := UnicodeString(AUrl);
  {$IFDEF WINDOWS}
  Abriu := OpenURL(PWideChar(Link));
  {$ELSE}
  Abriu := OpenURL(Link);
  {$ENDIF}
  if not Abriu then
    ShowMessage('Não foi possível abrir a página: ' + LineEnding + AUrl);
end;

procedure MostrarResultadoAtualizacao(const AInfo: TInfoAtualizacao;
  const AErro: string; AInterativo: Boolean);
begin
  if AErro <> '' then
  begin
    if AInterativo then
      MessageDlg('Verificar atualizações', AErro, mtWarning, [mbOK], 0);
    Exit;
  end;

  if AInfo.Disponivel then
  begin
    if MessageDlg('Atualização disponível',
      'Uma nova versão do Synapse está disponível.' + #13#10 + #13#10 +
      'Você tem a versão ' + AInfo.VersaoAtual + ' e a mais recente é ' +
      AInfo.VersaoNova + '.' + #13#10 + #13#10 +
      'Deseja abrir a página de download agora?',
      mtInformation, [mbYes, mbNo], 0) = mrYes then
      AbrirURL(AInfo.UrlPagina);
  end
  else if AInterativo then
    MessageDlg('Verificar atualizações',
      'Você já está usando a versão mais recente (' + AInfo.VersaoAtual + ').',
      mtInformation, [mbOK], 0);
end;

type
  TThreadAtualizacao = class(TThread)
  private
    FInterativo: Boolean;
    FInfo: TInfoAtualizacao;
    FErro: string;
  protected
    procedure Execute; override;
    procedure Notificar;
  end;

procedure TThreadAtualizacao.Notificar;
begin
  MostrarResultadoAtualizacao(FInfo, FErro, FInterativo);
end;

procedure TThreadAtualizacao.Execute;
begin
  ConsultarUltimaRelease(FInfo, FErro);
  if not Terminated then
    Synchronize(@Notificar);
end;

procedure VerificarAtualizacoesAsync(AInterativo: Boolean);
var
  T: TThreadAtualizacao;
begin
  T := TThreadAtualizacao.Create(True);
  T.FInterativo := AInterativo;
  T.FreeOnTerminate := True;
  T.Start;
end;

end.
