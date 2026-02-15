program project1;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces,
  Forms, runtimetypeinfocontrols,
  Unit1,
  Unit_Setup;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Title:='Synapse';
  Application.Scaled:=True;
  Application.Initialize;
  Application.CreateForm(TfrmPrincipal, frmPrincipal);
  Application.CreateForm(TForm_Setup, Form_Setup);
  Application.Run;
end.
