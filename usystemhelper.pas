unit uSystemAssistant;

// uSystemHelper
// UnitHelpHelper
{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Controls, StdCtrls, Graphics, Forms, Types;

type

  { TSystemAssistant }

  TSystemAssistant = class
  private
    class function WrapText(AText: string; AMaxChars: Integer = 50): string;
  public
    class procedure AddHelp(AControl: TControl; const AHelpText: string;
                            OffsetX: integer; OffsetY: integer;
                            AMaxWidth: Integer = 50);
    class procedure RecarregarDependentes(
                            const APai: TComboBox;
                            const ADpendentes: array of TComboBox
                            );
  end;

implementation

{ TSystemAssistant }

class function TSystemAssistant.WrapText(AText: string; AMaxChars: Integer): string;
var
  i: Integer;
  LineLen: Integer;
begin
  Result := '';
  LineLen := 0;
  for i := 1 to Length(AText) do
  begin
    Result := Result + AText[i];
    Inc(LineLen);
    if (LineLen >= AMaxChars) and (AText[i] = ' ') then
    begin
      Result := Result + LineEnding;
      LineLen := 0;
    end;

  end;
end;

class procedure TSystemAssistant.AddHelp(AControl: TControl;
  const AHelpText: string; OffsetX: integer; OffsetY: integer;
  AMaxWidth: Integer);
var
  HelpIcon: TLabel;
begin
  if not Assigned(AControl) then Exit;

  HelpIcon := TLabel.Create(AControl.Owner);
  HelpIcon.Parent := AControl.Parent;

  // Configuração Visual
  HelpIcon.Caption := 'ⓘ';
  //HelpIcon.Font.Color := $00FF8000;
  HelpIcon.Font.Color := clGray;
  HelpIcon.Font.Style := [fsBold];
  HelpIcon.Cursor := crHandPoint;
  HelpIcon.Hint := AHelpText;
  HelpIcon.ShowHint := True;

  // Aplica a quebra de linha automáticamente no texto antes de salvar
  HelpIcon.Hint := WrapText(AHelpText, AMaxWidth);
  HelpIcon.ShowHint := True;

  // Posicionamento: Colocar logo à direita do componente alvo
  HelpIcon.Left := AControl.Left + AControl.Width + OffsetX;
  HelpIcon.Top := AControl.Top + AControl.Height - (HelpIcon.Height div 2) + OffsetY;

  // Garante que o ícone fique na frente de outros componentes
  HelpIcon.BringToFront;
end;

class procedure TSystemAssistant.RecarregarDependentes(const APai: TComboBox; const ADpendentes: array of TComboBox);
var
  i: Integer;
begin
  for i := 0 to High(ADependentes) do
  begin
    ADpendentes[i].Items.Clear;
    ADpendentes[i].ItemIndex := -1;
  end;
end;



end.

