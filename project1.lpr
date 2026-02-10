program project1;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces,
  Forms,
  Unit1,
  Unit_Setup;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Title:='DaVinci Resolve - Media Prep Tool';
  Application.Scaled:=True;
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.CreateForm(TForm_Setup, Form_Setup);
  Application.Run;
end.
