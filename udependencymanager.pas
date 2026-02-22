unit uDependencyManager;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Process, StrUtils; // StrUtils ajuda a achar textos

type
  { TDependencyManager }
  TDependencyManager = class
  private
    // Função interna para descobrir qual é o Linux (Arch, Debian, Fedora?)
    class function DetectarGerenciadorPacotes(out CmdInstall: String; out Params: TStringArray): Boolean;
  public
    class function VerificarTudo: Boolean;
    class function InstalarDependencias: Boolean;
  end;

implementation

{ TDependencyManager }

// 1. O Cérebro: Lê o arquivo /etc/os-release para saber quem é o sistema
class function TDependencyManager.DetectarGerenciadorPacotes(out CmdInstall: String; out Params: TStringArray): Boolean;
var
  List: TStringList;
  Content, DistroID: string;
  i: Integer;
begin
  Result := False;
  DistroID := '';

  if FileExists('/etc/os-release') then
  begin
    List := TStringList.Create;
    try
      List.LoadFromFile('/etc/os-release');
      // Procura pelas chaves ID ou ID_LIKE
      for i := 0 to List.Count - 1 do
      begin
        Content := LowerCase(List[i]);
        if Pos('id_like=', Content) > 0 then
           DistroID := DistroID + Copy(Content, 9, Length(Content));
        if (Pos('id=', Content) = 1) then
           DistroID := DistroID + Copy(Content, 4, Length(Content));
      end;
    finally
      List.Free;
    end;
  end;

  // 2. Define o comando com base no que encontrou
  // Nota: 'pkexec' será chamado antes, aqui definimos O QUE o pkexec vai rodar

  // Família ARCH (CachyOS, Manjaro, Endeavour)
  if (Pos('arch', DistroID) > 0) then
  begin
    CmdInstall := 'pacman';
    Params := ['-S', '--noconfirm', 'yt-dlp', 'ffmpeg'];
    Result := True;
  end
  // Família DEBIAN (Ubuntu, Mint, Pop!_OS, Kali)
  else if (Pos('debian', DistroID) > 0) or (Pos('ubuntu', DistroID) > 0) then
  begin
    CmdInstall := 'apt-get';
    Params := ['install', '-y', 'yt-dlp', 'ffmpeg'];
    Result := True;
  end
  // Família REDHAT (Fedora, RHEL, CentOS)
  else if (Pos('fedora', DistroID) > 0) or (Pos('rhel', DistroID) > 0) then
  begin
    CmdInstall := 'dnf';
    Params := ['install', '-y', 'yt-dlp', 'ffmpeg'];
    Result := True;
  end
  // Família OPENSUSE
  else if (Pos('suse', DistroID) > 0) then
  begin
    CmdInstall := 'zypper';
    Params := ['install', '-n', 'yt-dlp', 'ffmpeg']; // -n é non-interactive
    Result := True;
  end;
end;

class function TDependencyManager.VerificarTudo: Boolean;
begin
  // Usa RunCommand para ser mais silencioso e compatível
  // Retorna True se o comando 'which' encontrar o executável
  Result := (ExecuteProcess('/usr/bin/which', ['yt-dlp']) = 0) and
            (ExecuteProcess('/usr/bin/which', ['ffmpeg']) = 0);
end;

class function TDependencyManager.InstalarDependencias: Boolean;
var
  Cmd: String;
  Params: TStringArray;
  FullParams: array of string;
  i: Integer;
begin
  Result := False;

  // Descobre qual comando usar (pacman, apt, dnf...)
  if DetectarGerenciadorPacotes(Cmd, Params) then
  begin
    // Monta a lista de argumentos para o pkexec
    // O pkexec precisa receber: [Comando, Param1, Param2, ...]
    SetLength(FullParams, Length(Params) + 1);
    FullParams[0] := Cmd;
    for i := 0 to High(Params) do
      FullParams[i + 1] := Params[i];

    // Executa: pkexec <gerenciador> <instalar> <pacotes>
    Result := ExecuteProcess('/usr/bin/pkexec', FullParams) = 0;
  end
  else
  begin
    // Se não reconheceu a distro, avisa ou retorna falso
    // Aqui você poderia abrir um ShowMessage se estivesse numa unit visual,
    // mas como é uma unit lógica, retornamos False.
  end;
end;

end.
