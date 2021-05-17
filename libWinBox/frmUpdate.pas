(*

    WinBox Reloaded R2 - An universal GUI for many emulators

    Copyright (C) 2020, Laci b�'

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.

*)

unit frmUpdate;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, IOUtils,
  Dialogs, StdCtrls, ComCtrls, ExtCtrls, Registry, DateUtils, Zip,
  uBaseProfile;

type
  IAutoUpdate = interface
    ['{768238E2-A485-4DE5-AEA8-51E506DD81BC}']
    function Execute(const ByCommand: boolean = false): boolean; stdcall;
    function HasUpdate: boolean; stdcall;
    function AutoUpdate: boolean; stdcall;
  end;

  TUpdateForm = class(TForm, IAutoUpdate)
    Label1: TLabel;
    LogBox: TListBox;
    Button1: TButton;
    lbState: TLabel;
    Progress: TProgressBar;
    Shape1: TShape;
    State: TLabel;
    lbFileName: TLabel;
    procedure FormShow(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure LogBoxDblClick(Sender: TObject);
  private
    procedure WMStartup(var Msg: TMessage); message WM_USER;
  protected
    procedure Log(const S: string);
    procedure LogFmt(const S: string; const Args: array of const);
    function MessageBox(const Text: string; const Flags: longword): longword;
    function MessageBoxFmt(const Text: string; const Args: array of const; const Flags: longword): longword;
  public
    FMode, FAutoUpdate, FGetSource: integer;
    FRepositories: array [0..1] of string;
    FPaths: array [0..0] of string;
    FCancelled: boolean;
    FBuild: integer;
    FEmulator, FRoms, FSource: string;

    function CheckCancel: boolean;
    function VersionCheck: boolean;
    function Download: boolean;
    function Extract: boolean;
    function Execute(const ByCommand: boolean = false): boolean; stdcall;
    function HasUpdate: boolean; stdcall;
    function AutoUpdate: boolean; stdcall;

    procedure OnZipProgress(Sender: TObject; FileName: string;
      Header: TZipHeader; Position: Int64);
  end;

var
  UpdateForm: TUpdateForm;

implementation

uses uCommUtil, uWebUtils;

resourcestring
  SRegRootKey    = 'Software\Laci b�''\WinBox\';
  SRegConfigKey  = 'Configuration';
  StrExecutablePath = 'ExecutablePath';
  StrRepository = 'Repository';
  Def86BoxRepo = 'https://ci.86box.net/job/86Box';
  Def86RomsRepo = 'https://github.com/86Box/roms';
  Def86SrcRepo = 'https://github.com/86Box/86Box';
  StrWinBox = 'WinBox';
  StrAutoUpdate = 'AutoUpdate';
  StrDownloadSource = 'DownloadSource';
  StrAJelenlegiVerzi�N = 'A jelenlegi verzi� nem lek�rhet�. K�v�nja folytatn' +
  'i?';
  StrJelenlegiVerzi�S = 'Jelenlegi 86Box verzi�: %s';
  StrLegfrisebbVerzi�Ke = 'Friss�t�sek keres�se itt: %s';
  StrEl�rhet�Verzi�S = 'El�rhet� 86Box verzi�: %s';
  StrATelep�tettVerzi� = 'A telep�tett verzi� azonos vagy frissebb mint a le' +
  't�lthet�.'#13#10'K�v�nja m�gis let�lteni?';
  StrFriss�t�sEl�rhet� = 'Friss�t�s el�rhet� (build: %d, d�tum: %s).'#13#10'K�v�nja le' +
  't�lteni?';
  EAT�voliKiszolg�l� = 'A t�voli kiszolg�l� nem el�rhet�, ellen�rizze az int' +
  'ernetkapcsolatot!';
  StrJelenlegNincsEgyet = 'Jelenleg nincs egyetlen telep�tett verzi� sem.';
  StrAFolyamatotAFelha = 'A folyamatot a felhaszn�l� megszak�totta.';
  StrKil�p�s = '&Kil�p�s';
  StrLegfrisebbV�ltoz�so = 'Legfrisebb v�ltoz�sok: ';
  StrVerzi�kEllen�rz�se = 'Verzi�k ellen�rz�se...';
  Str�resj�rat = '�resj�rat';
  StrMegszak�t�s = '&Megszak�t�s';
  StrF�jlokLet�lt�se = 'F�jlok let�lt�se...';
  StrF�jlokKibont�sa = 'F�jlok kibont�sa...';
  StrIdeiglenesF�jlokEl = 'Ideiglenes f�jlok elt�vol�t�sa...';
  StrHibaT�rt�ntAF�jlo = 'Hiba t�rt�nt a f�jlok kibont�sa sor�n.';
  Str�tnevez�sK�zbenHib = '�tnevez�s k�zben hiba t�rt�nt.';
  StrK�nyvt�r�tnevez�se = 'K�nyvt�r �tnevez�se: 86Box-master';
  StrK�nyvt�r�tnevez�s2 = 'K�nyvt�r �tnevez�se: roms-master';
  StrForr�sk�dKibont�sa = 'Forr�sk�d kibont�sa...';
  StrDF�jlKibontva = '%d f�jl kibontva.';
  StrROMk�pekKibont�sa = 'ROM-k�pek kibont�sa...';
  StrBin�risokKibont�sa = 'Bin�risok kibont�sa...';
  StrHibaT�rt�ntAKor�b = 'Hiba t�rt�nt a kor�bbi verzi� elt�vol�t�sa sor�n.';
  StrAKor�bbiVerzi�Elt = 'A kor�bbi verzi� elt�vol�t�sa...';
  StrHibaT�rt�ntAF�jl2 = 'Hiba t�rt�nt a f�jlok let�lt�se sor�n.';
  StrForr�sk�dLet�lt�se = 'Forr�sk�d let�lt�se ide: "%s"';
  StrForr�sk�dLet�lt�s2 =  'Forr�sk�d let�lt�se innen: "%s"';
  StrROMk�pekF�jlainak = 'ROM-k�pek f�jlainak let�lt�se ide: "%s"';
  StrROMk�pekLet�lt�se = 'ROM-k�pek let�lt�se innen: "%s"';
  StrAzEmul�torF�jlaina = 'Az emul�tor f�jlainak let�lt�se ide: "%s"';

{$R *.dfm}

function TUpdateForm.AutoUpdate: boolean;
begin
  Result := FAutoUpdate <> 0;
end;

procedure TUpdateForm.Button1Click(Sender: TObject);
begin
  if Button1.Caption = StrKil�p�s then
    Close
  else
    FCancelled := true;
end;

function TUpdateForm.CheckCancel: boolean;
begin
  Result := FCancelled;
  if Result then begin
    Log(StrAFolyamatotAFelha);
    State.Caption := Str�resj�rat;
  end;
end;

function TUpdateForm.Download: boolean;
var
  Temp: string;
begin
  Result := true;

  try
    FEmulator := TPath.GetTempFileName;
    LogFmt(StrAzEmul�torF�jlaina, [ExtractFileName(FEmulator)]);
    Temp := jenkinsGetBuild(FRepositories[0], FBuild);
    if Temp = '' then begin
      Log(EAT�voliKiszolg�l�);
      exit(false);
    end;
    httpsGet(Temp, FEmulator);
    Progress.Position := Progress.Position + 1;
    lbFileName.Caption := ExtractFileName(FEmulator);

    LogFmt(StrROMk�pekLet�lt�se, [Def86RomsRepo]);
    FRoms := TPath.GetTempFileName;
    LogFmt(StrROMk�pekF�jlainak, [ExtractFileName(FRoms)]);
    gitClone(Def86RomsRepo, FRoms);
    Progress.Position := Progress.Position + 1;
    lbFileName.Caption := ExtractFileName(FRoms);

    if FGetSource <> 0 then begin
      LogFmt(StrForr�sk�dLet�lt�s2, [Def86SrcRepo]);
      FSource := TPath.GetTempFileName;
      LogFmt(StrForr�sk�dLet�lt�se, [ExtractFileName(FSource)]);
      gitClone(Def86SrcRepo, FSource);
      Progress.Position := Progress.Position + 1;
      lbFileName.Caption := ExtractFileName(FSource);
    end;
  except
    on E: Exception do begin
      Log(StrHibaT�rt�ntAF�jl2);
      Log(#9 + E.Message);
      Result := false;
      lbFileName.Caption := '-';
    end;
  end;
end;

function TUpdateForm.Execute(const ByCommand: boolean): boolean;
begin
  FMode := ord(ByCommand);
  Result := ShowModal = mrOK;
end;

function TUpdateForm.Extract: boolean;
var
  Root: string;
begin
  Result := true;
  Root := ExtractFilePath(FPaths[0]);
  Log(StrAKor�bbiVerzi�Elt);
  if DirectoryExists(Root) and not DeleteToBin(ExcludeTrailingPathDelimiter(Root)) then begin
    Log(StrHibaT�rt�ntAKor�b);
    exit(false);
  end;
  ForceDirectories(Root);

  try
    with TZipFile.Create do begin
      try
        OnProgress := OnZipProgress;
        Log(StrBin�risokKibont�sa);
        Open(FEmulator, zmRead);
        ExtractAll(Root);
        Log(format(StrDF�jlKibontva, [length(FileInfos)]));
        Close;
        Progress.Position := Progress.Position + 1;

        Log(StrROMk�pekKibont�sa);
        Open(FRoms, zmRead);
        ExtractAll(Root);
        Log(format(StrDF�jlKibontva, [length(FileInfos)]));
        Close;
        Progress.Position := Progress.Position + 1;

        if FGetSource <> 0 then begin
          Log(StrForr�sk�dKibont�sa);
          Open(FSource, zmRead);
          ExtractAll(Root);
          Log(format(StrDF�jlKibontva, [length(FileInfos)]));
          Close;
          Progress.Position := Progress.Position + 1;
        end;
      finally
        Free;
      end;
    end;

    Log(StrK�nyvt�r�tnevez�s2);
    if not RenameFile(Root + 'roms-master', Root + 'roms') then begin
      Log(Str�tnevez�sK�zbenHib);
      Result := false;
    end;

    if FGetSource <> 0 then begin
      Log(StrK�nyvt�r�tnevez�se);
      if not RenameFile(Root + '86box-master', Root + 'source') then begin
        Log(Str�tnevez�sK�zbenHib);
        Result := false;
      end;
    end;
  except
    on E: Exception do begin
      Log(StrHibaT�rt�ntAF�jlo);
      Log(#9 + E.Message);
      lbFileName.Caption := '-';
      Result := false;
    end;
  end;
end;

procedure TUpdateForm.FormCreate(Sender: TObject);
begin
  with TRegIniFile.Create(SRegRootKey, KEY_READ) do begin
    FRepositories[0] := ReadString(SRegConfigKey + '.86Box', StrRepository, Def86BoxRepo);
    FAutoUpdate := ReadInteger(SRegConfigKey + '.86Box', StrAutoUpdate, 1);
    FGetSource := ReadInteger(SRegConfigKey + '.86Box', StrDownloadSource, 0);
    FPaths[0] := ReadString(SRegConfigKey + '.86Box', StrExecutablePath,
      TProfile.DefExecutablePath + '86Box\86Box.exe');
    Free;

    if FGetSource <> 0 then
      Progress.Max := 6;
  end;
end;

procedure TUpdateForm.FormShow(Sender: TObject);
begin
  LogBox.Clear;
  FCancelled := false;
  Button1.Caption := StrMegszak�t�s;

  PostMessage(Handle, WM_USER, 0, 0);
  OnShow := nil;
end;

function TUpdateForm.HasUpdate: boolean;
begin
  Result := (not FileExists(FPaths[0])) or
     (jenkinsCheckUpdate(FRepositories[0], GetFileTime(FPaths[0])));
end;

procedure TUpdateForm.Log(const S: string);
begin
  LogBox.ItemIndex := LogBox.Items.Add(S);
end;

procedure TUpdateForm.LogBoxDblClick(Sender: TObject);
begin
  if LogBox.ItemIndex <> -1 then
    ShowMessage(LogBox.Items[LogBox.ItemIndex]);
end;

procedure TUpdateForm.LogFmt(const S: string; const Args: array of const);
begin
  LogBox.ItemIndex := LogBox.Items.Add(format(S, Args));
end;

function TUpdateForm.MessageBox(const Text: string; const Flags: longword): longword;
begin
  Result := Windows.MessageBox(Handle, PChar(Text), PChar(StrWinBox), Flags);
end;

function TUpdateForm.MessageBoxFmt(const Text: string;
  const Args: array of const; const Flags: longword): longword;
begin
  Result := Windows.MessageBox(Handle, PChar(format(
    Text, Args)), PChar(StrWinBox), Flags);
end;

procedure TUpdateForm.OnZipProgress(Sender: TObject; FileName: string;
  Header: TZipHeader; Position: Int64);
begin
  lbFileName.Caption := ExtractFileName(FileName);

  Application.ProcessMessages;
end;

function TUpdateForm.VersionCheck: boolean;
var
  DateLocal, DateOnline: TDateTime;
  I: integer;
begin
  lbFileName.Caption := '-';
  if FileExists(FPaths[0]) then begin
    DateLocal := GetFileTime(FPaths[0]);
    if DateLocal = 0 then
      Result := MessageBox(StrAJelenlegiVerzi�N, MB_ICONQUESTION or MB_YESNO) = mrYes
    else begin
      LogFmt(StrJelenlegiVerzi�S, [DateTimeToStr(DateLocal)]);
      LogFmt(StrLegfrisebbVerzi�Ke, [FRepositories[0]]);
      try
         FBuild := jenkinsLastBuild(FRepositories[0]);
         if FBuild <> -1 then begin
           DateOnline := jenkinsGetDate(FRepositories[0], FBuild);
           LogFmt(StrEl�rhet�Verzi�S, [DateTimeToStr(DateOnline)]);
           Result := CompareDate(DateLocal, DateOnline) < 0;
           if not Result then begin
             Result := (FMode = 1) and (MessageBox(
               StrATelep�tettVerzi�,
               MB_ICONWARNING or MB_YESNO) = mrYes);
             if not Result then begin
               FCancelled := true;
               CheckCancel;
             end;
           end
           else with jenkinsGetChangelog(FRepositories[0], FBuild) do begin
             Log(StrLegfrisebbV�ltoz�so);
             for I := 0 to Count - 1 do
               Log(#9 + Strings[I]);
             Result := MessageBoxFmt(StrFriss�t�sEl�rhet�,
                 [FBuild, DateTimeToStr(DateOnline)],
                 MB_ICONQUESTION or MB_YESNO) = mrYes;
             if not Result then begin
               FCancelled := true;
               CheckCancel;
             end;
             Free;
           end;
         end
         else begin
           Log(EAT�voliKiszolg�l�);
           Result := false;
         end;
      except
         Log(EAT�voliKiszolg�l�);
         Result := false;
      end;
    end;
  end
  else begin
    Result := true;
    Log(StrJelenlegNincsEgyet);
    FBuild := jenkinsLastBuild(FRepositories[0]);
  end;
end;

procedure TUpdateForm.WMStartup(var Msg: TMessage);
begin
  repeat
    State.Caption := StrVerzi�kEllen�rz�se;
    if not VersionCheck then break;
    if CheckCancel then break;

    State.Caption := StrF�jlokLet�lt�se;
    Application.ProcessMessages;
    if not Download then break;
    if CheckCancel then break;

    State.Caption := StrF�jlokKibont�sa;
    if not Extract then break;
    break;
  until false;

  State.Caption := Str�resj�rat;
  Log(StrIdeiglenesF�jlokEl);
  if FileExists(FEmulator) then
    DeleteFile(FEmulator);
  if FileExists(FRoms) then
    DeleteFile(FRoms);
  if FileExists(FSource) then
    DeleteFile(FSource);
  Progress.Position := 0;
  lbFileName.Caption := '-';

  if FMode = 0 then
    Close
  else
    Button1.Caption := StrKil�p�s;
end;

end.
