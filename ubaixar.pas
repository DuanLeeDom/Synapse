unit uBaixar;

{$mode ObjFPC}{$H+}

interface

uses
    Classes, SysUtils, Forms, Controls, ExtCtrls,
    StdCtrls, EditBtn, ComCtrls, Dialogs, Process, uSystemAssistant;

type

  { TfrBaixar }

  TfrBaixar = class(TFrame)
    button_process_DiretoDaVinci1: TButton;
    ComboBox_Format_Audios1: TComboBox;
    ComboBox_Format_Videos1: TComboBox;
    DirectoryEdit1: TDirectoryEdit;
    edt_definir1: TEdit;
    grp_console1: TGroupBox;
    grp_convertionFormate1: TGroupBox;
    grp_definicao1: TGroupBox;
    grp_fileConfig1: TGroupBox;
    Label12: TLabel;
    Label13: TLabel;
    Label14: TLabel;
    Memo_visual_console1: TMemo;
    pbar_console1: TProgressBar;
    pnl_Baixador: TPanel;
    pnl_button1: TPanel;
    pnl_DiretoDaVinci_Group1: TPanel;
    rbtm_definir1: TRadioButton;
    rbtm_padrao1: TRadioButton;
    rbtm_ytdlp1: TRadioButton;
    url_web1: TEdit;
  private

  public

  end;

implementation

{$R *.lfm}

end.

