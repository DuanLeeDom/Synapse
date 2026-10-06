unit uAboutView;

{$mode ObjFPC}{$H+}
{$CODEPAGE UTF8}

interface

uses
  Classes, SysUtils, Forms, Controls, ExtCtrls,
  StdCtrls, Dialogs, LCLIntf;

const
  { Pagina oficial do projeto. Usada pelo menu e pelos botoes desta tela,
    para nao duplicar o endereco em varios lugares. }
  URL_REPOSITORIO = 'https://github.com/DuanLeeDom/Synapse';
  VERSAO_APP     = '1.0.0';

  { Textos com acentos. Os arquivos .lfm do projeto estao em UTF-8, mas as
    strings lidas do LFM recebem a codepage do sistema (CP1252 no Windows) e
    os acentos viram caracteres invalidos em tempo de execucao. Um literal
    declarado nesta unit, que usa a diretiva CODEPAGE UTF8, recebe codepage
    65001, e e o que faz o LCL decodificar os bytes UTF-8 corretamente. Por
    isso os textos sao atribuidos por codigo no construtor; o .lfm mantem o
    texto correto para o designer. Nao usar UTF8Encode aqui: ele reaplicaria a
    conversao e geraria sequencias invalidas. }
  TEXTO_SUBTITULO = 'Conversão de mídia para o DaVinci Resolve';
  TEXTO_VERSAO    = 'Versão ' + VERSAO_APP;
  TEXTO_RODAPE    = 'Projeto de código aberto.';
  TEXTO_BOTAO     = 'Documentação online';
  TEXTO_APRESENTACAO =
    'Editar no Linux com a versão gratuita do DaVinci Resolve não deveria ser' +
    ' uma dor de cabeça. Percebendo que muitos editores perdiam horas tentando' +
    ' contornar problemas de compatibilidade ou recorrendo a sites de conversão' +
    ' pouco seguros, Duan Lee iniciou o Synapse.' + #13#10 + #13#10 +
    'Mais do que um simples conversor, o Synapse é um elo entre a web e a sua' +
    ' timeline. O objetivo é garantir que o editor foque no que importa: a' +
    ' criatividade. O projeto transforma arquivos complexos em formatos' +
    ' amigáveis para o software da Blackmagic, garantindo eficiência técnica e' +
    ' segurança de dados. Como um projeto de código aberto, o Synapse está em' +
    ' constante evolução, buscando se tornar o canivete suíço definitivo para' +
    ' qualquer editor de vídeo que escolheu o Linux como sua estação de trabalho.';

type

  { TfrAboutView }

  TfrAboutView = class(TFrame)
    Image1: TImage;
    btn_Documentacao: TButton;
    lbl_Autor: TLabel;
    lbl_Rodape: TLabel;
    lbl_Subtitulo: TLabel;
    lbl_Titulo: TLabel;
    lbl_Url: TLabel;
    lbl_Versao: TLabel;
    lbl_info: TLabel;
    pnl_Acoes: TPanel;
    pnl_AboutView: TPanel;
    pnl_AboutView_Group: TPanel;
    pnl_Cabecalho: TPanel;
    pnl_Corpo: TPanel;
    pnl_Detalhes: TPanel;
    pnl_Identidade: TPanel;
    pnl_Marca: TPanel;
    pnl_Titulos: TPanel;
    procedure btn_DocumentacaoClick(Sender: TObject);
    procedure lbl_TituloClick(Sender: TObject);
    procedure lbl_UrlClick(Sender: TObject);
  private
    procedure AbrirDocumentacao;
  public
    constructor Create(AOwner: TComponent); override;

  end;

implementation

{$R *.lfm}

constructor TfrAboutView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  lbl_Subtitulo.Caption    := TEXTO_SUBTITULO;
  lbl_Versao.Caption       := TEXTO_VERSAO;
  lbl_Rodape.Caption       := TEXTO_RODAPE;
  lbl_info.Caption         := TEXTO_APRESENTACAO;
  btn_Documentacao.Caption := TEXTO_BOTAO;

  { Cursor e um inteiro no LCL, entao o valor vem do codigo e nao do LFM. }
  lbl_Url.Cursor := crHandPoint;
end;

{ O LCL trata AnsiString como UTF-8 no Windows. O OpenURL recebe PWideChar,
  entao a string e passada como UnicodeString explicita em vez de relyar na
  conversao implicita de AnsiString. }
procedure TfrAboutView.AbrirDocumentacao;
var
  Abriu: Boolean;
  Link: UnicodeString;
begin
  Link := UnicodeString(URL_REPOSITORIO);
  {$IFDEF WINDOWS}
  Abriu := OpenURL(PWideChar(Link));
  {$ELSE}
  Abriu := OpenURL(Link);
  {$ENDIF}

  if not Abriu then
    ShowMessage('Não foi possível abrir a documentação online no navegador.' +
      LineEnding + URL_REPOSITORIO);
end;

procedure TfrAboutView.btn_DocumentacaoClick(Sender: TObject);
begin
  AbrirDocumentacao;
end;

procedure TfrAboutView.lbl_TituloClick(Sender: TObject);
begin

end;

procedure TfrAboutView.lbl_UrlClick(Sender: TObject);
begin
  AbrirDocumentacao;
end;

end.