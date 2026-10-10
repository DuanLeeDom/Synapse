unit uVersao;

{ uVersao

  Fonte unica da versao do aplicativo e dos enderecos do repositorio. Tanto a
  tela "Sobre" quanto o verificador de atualizacoes leem daqui, para nao haver
  duas versoes divergentes circulando.

  IMPORTANTE (ao publicar uma versao nova):
   1. Atualize VERSAO_APP abaixo (ex.: '1.1.0').
   2. Crie a tag no GitHub com o mesmo numero, com "v" na frente (ex.: v1.1.0).
   3. Anexe o executavel como asset chamado "synapse.exe" na release.
  O aplicativo compara VERSAO_APP com o tag_name da ultima release. }

{$mode ObjFPC}{$H+}
{$CODEPAGE UTF8}

interface

const
  VERSAO_APP      = '1.0.0';

  REPO_USUARIO    = 'DuanLeeDom';
  REPO_NOME       = 'Synapse';

  URL_REPOSITORIO = 'https://github.com/' + REPO_USUARIO + '/' + REPO_NOME;
  URL_RELEASES    = URL_REPOSITORIO + '/releases';

  { Endpoint da API do GitHub: a release mais recente (nao rascunho, nao
    pre-release). Devolve JSON com tag_name, html_url, body e assets. }
  URL_API_ULTIMA_RELEASE =
    'https://api.github.com/repos/' + REPO_USUARIO + '/' + REPO_NOME + '/releases/latest';

  { Download direto do executavel da ultima release, sem precisar saber o
    numero da versao. É o mesmo endereco usado pelo instalador online. }
  URL_EXE_LATEST  = URL_REPOSITORIO + '/releases/latest/download/synapse.exe';

{ Remove um "v"/"V" inicial e sufixos de pre-lancamento (-beta, +meta). }
function NormalizarVersao(const A: string): string;

{ Compara duas versoes numericas "a.b.c". Devolve -1 se A<B, 0 se iguais,
  1 se A>B. Partes ausentes contam como 0 e o "v" inicial e ignorado. }
function CompararVersoes(const A, B: string): Integer;

implementation

uses
  Classes, SysUtils;

function NormalizarVersao(const A: string): string;
var
  s: string;
  p: Integer;
begin
  s := Trim(A);
  if (s <> '') and ((s[1] = 'v') or (s[1] = 'V')) then
    Delete(s, 1, 1);
  { tag pode ser 1.2.3-beta.1 ou 1.2.3+build; considera so os numeros. }
  p := Pos('-', s);
  if p > 0 then
    s := Copy(s, 1, p - 1);
  p := Pos('+', s);
  if p > 0 then
    s := Copy(s, 1, p - 1);
  Result := Trim(s);
end;

function CompararVersoes(const A, B: string): Integer;
var
  La, Lb: TStringList;
  i, n, va, vb: Integer;
begin
  Result := 0;
  La := TStringList.Create;
  Lb := TStringList.Create;
  try
    La.Delimiter := '.';
    La.StrictDelimiter := True;
    La.DelimitedText := NormalizarVersao(A);
    Lb.Delimiter := '.';
    Lb.StrictDelimiter := True;
    Lb.DelimitedText := NormalizarVersao(B);

    n := La.Count;
    if Lb.Count > n then
      n := Lb.Count;

    for i := 0 to n - 1 do
    begin
      if i < La.Count then
        va := StrToIntDef(La[i], 0)
      else
        va := 0;
      if i < Lb.Count then
        vb := StrToIntDef(Lb[i], 0)
      else
        vb := 0;

      if va < vb then
        Exit(-1);
      if va > vb then
        Exit(1);
    end;
  finally
    Lb.Free;
    La.Free;
  end;
end;

end.
