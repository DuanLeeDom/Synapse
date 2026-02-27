program synapse;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces,
  Forms, Controls, runtimetypeinfocontrols,
  uMain,
  uSetup,
  uDependencyManager;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Title:='DaVinci Resolve - Media Prep Tool';
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

  Application.CreateForm(TfrmPrincipal, frmPrincipal);
  Application.CreateForm(TfrmSetup, frmSetup);
  Application.Run;
end.
