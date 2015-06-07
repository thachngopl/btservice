{
 this file is part of Ares
 Aresgalaxy ( http://aresgalaxy.sourceforge.net )

  This program is free software; you can redistribute it and/or
  modify it under the terms of the GNU General Public License
  as published by the Free Software Foundation; either
  version 2 of the License, or (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 }

{
Description:
disk I/O helper functions, ansi/unicode
}

unit helper_diskio;

interface

uses
 ares_types,windows,{tntwindows,}sysutils,classes2,helper_unicode,
 classes,shellapi,dialogs,uFunctions{,TntStdCtrls}{,ufrm_settings};

const
 ARES_READONLY_ACCESS                   =0;
 ARES_WRITE_EXISTING                    =1;
 ARES_OVERWRITE_EXISTING                =2;
 ARES_TRUNCATE_EXISTING                 =3;
 ARES_CREATE_ALWAYSAND_WRITETHROUGH     =10;
 ARES_READONLY_BUT_SEQUENTIAL           =11;
 ARES_WRITEEXISTING_WRITETHROUGH        =12;
 ARES_WRITE_EXISTING_BUT_SEQUENTIAL     =13;
 ARES_OVERWRITE_EXISTING_BUT_SEQUENTIAL =14;

faanyfile=$0000003f;

  DRIVE_UNKNOWN = 0;
  DRIVE_NO_ROOT_DIR = 1;
  DRIVE_REMOVABLE = 2;
  DRIVE_FIXED = 3;
  DRIVE_REMOTE = 4;
  DRIVE_CDROM = 5;    
  DRIVE_RAMDISK = 6;

TooDangerousExtensions='.lnk .reg .com .pif .vb .vbe .vbs .bas .cmd .cpl .hta .js .jse .inf .ins .isp .crt .shs .shb .sct .wsc .wsf .wsh .asp .pcd .mst .msc';
DangerousExtensions='.exe .dll .bat .hlp .chm .scr .url .doc .xls .ppt .msi .msp .mdb .mde .ade .adp';

procedure FreeHandleStream(var stream:thandlestream);
function MyFileOpen(Filename: widestring; mode:integer):ThandleStream; overload;
function isWriteableFile(Filename: widestring):boolean;
function direxistsW(dirname:widestring):boolean;
function FindFirstW(const Path: widestring; Attr: Integer; var F: ares_types.TSearchRecW): Integer;
function FileExists(const FileName: widestring): Boolean;
function getFileDateW(const FileName: widestring):cardinal;
function erase_directory(dir:widestring):boolean;
function num_dat_indir(dir:widestring):integer;
procedure erase_random_dat(dir:widestring);
procedure erase_emptydir(path:widestring);
function isfolder(name:widestring):boolean;
procedure FindCloseW(var F: ares_types.TSearchRecW);
function FindNextW(var F: ares_types.TSearchRecW): Integer;
function FindMatchingFileW(var F: ares_types.TSearchRecW): Integer;
function GetHugeFileSize(const FileName: widestring): int64;
procedure erase_dir_recursive(path:widestring);
procedure get_subdirs(var list:tmystringlist; dir:widestring);
procedure write_padding(stream:thandlestream; size:int64);
//procedure getfreedrivespace;
//procedure locate_containing_folder(fname:string);
//procedure open_file_external(fname:string);
procedure parse_file_lines(fname:widestring; var list:tmystringlist);
function deletefileW(filename:widestring):boolean;
function MoveToRecycle(sFileName: widestring): Boolean;
function MyFileSeek(stream:THandleStream; const Offset: Int64; Origin: Integer): Int64;
function getLastModifiedW(TheFile:widestring):cardinal;


  type
 pSetFilePointerEx = function (hFile: THandle; lDistanceToMove: int64; lpNewFilePointer: Pointer; dwMoveMethod: DWORD): BOOL; stdcall;

  var
 kern32handle:hwnd;
 SetFilePointerEx:pSetFilePointerEx;

implementation

uses
 vars_global,{ufrmmain,}
 {utility_ares,}helper_datetime;

//function SetFilePointerEx; external kernel32 name 'SetFilePointerEx';
function getLastModifiedW(TheFile:widestring):cardinal;
var
 DosFT:DWORD;
 LastAccessedTime:TDateTime;
 FindData:TWin32FindDataW;
 fileH:thandle;
 localft:TFileTime;
begin
  result:=0;
  fileH:=FindFirstFileW(PWideChar(TheFile), FindData);
  if fileH<>INVALID_HANDLE_VALUE then begin
   Windows.FindClose(fileH);
   if (FindData.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY)=0 then begin
     FileTimeToLocalFileTime(FindData.ftLastWriteTime,LocalFT);
     FileTimeToDosDateTime(LocalFT,LongRec(DosFT).Hi,LongRec(DosFT).Lo);
     LastAccessedTime:=FileDateToDateTime(DosFT);
     result:=DelphiDateTimeToUnix(LastAccessedTime);
    end;
  end;
end;

function MyFileSeek(stream:THandleStream; const Offset: Int64; Origin: Integer): Int64;
begin
if @SetfilePointerEx<>nil then begin
    if not SetfilePointerEx(THandle(stream.Handle),
                            Offset,
                            @result,
                            origin) then result:=-1;
    exit;
end;

 result:=stream.seek(offset,origin);
end;

function _PWideCharWithNil(const S: WideString): PWideChar;
begin
  if S = '' then
    Result := nil {Win9x needs nil for some parameters instead of empty strings}
  else
    Result := PWideChar(S);
end;

function _PAnsiCharWithNil(const S: AnsiString): PAnsiChar;
begin
  if S = '' then
    Result := nil {Win9x needs nil for some parameters instead of empty strings}
  else
    Result := PAnsiChar(S);
end;

function Tnt_ShellExecuteW(hWnd: HWND; Operation, FileName, Parameters,
  Directory: PWideChar; ShowCmd: Integer): HINST;
var Win32PlatformIsUnicode : boolean;
begin
  Win32PlatformIsUnicode := (Win32Platform = VER_PLATFORM_WIN32_NT);
  if Win32PlatformIsUnicode then
    Result := ShellExecuteW{TNT-ALLOW ShellExecuteW}(hWnd, _PWideCharWithNil(WideString(Operation)),
      FileName, Parameters,
        Directory, ShowCmd)
  else begin
    Result := ShellExecuteA{TNT-ALLOW ShellExecuteA}(hWnd, _PAnsiCharWithNil(AnsiString(Operation)),
      _PAnsiCharWithNil(AnsiString(FileName)), _PAnsiCharWithNil(AnsiString(Parameters)),
        _PAnsiCharWithNil(AnsiString(Directory)), ShowCmd)
  end;
end;
{
procedure open_file_external(fname:string);
var
ext:string;
begin

ext:=lowercase(extractfileext(fname));
if pos(ext,TooDangerousExtensions)<>0 then exit;

if pos(ext,DangerousExtensions)<>0 then begin  //warn user
 if messageboxW(ares_frmmain.handle,pwidechar(GetLangStringW(STR_WARN_DANGEROUS_FILEEXT)),pwidechar(appname+': '+GetLangStringW(STR_WARNING)),MB_ICONWARNING or mb_YESNO)=IDNO then exit;
end;

Tnt_ShellExecuteW(0,'open',pwidechar(utf8strtowidestr(fname)),'','',SW_SHOWNORMAL);
end;
}

{
procedure locate_containing_folder(fname:string);
   procedure old_locate(fname:string);
   begin
    Tnt_ShellExecuteW(0,'explore',pwidechar(extract_fpathW(utf8strtowidestr(fname))),'','',SW_SHOWNORMAL);
   end;

type
SHOpenFolderAndSelectItems=function(pidlFolder:PItemIdList; cidl:cardinal; apidl:PItemIdList; dwflags:dword): HRESULT; stdcall;
var
ShOp:SHOpenFolderAndSelectItems;
idlist:PItemIdList;
hr:hresult;
dllHandle:Thandle;
begin

  dllHandle:=SafeLoadLibrary('shell32.dll');
  if dllHandle=0 then begin
   old_locate(fname);
   exit;
  end;

  ShOp:=GetProcAddress(dllHandle,'SHOpenFolderAndSelectItems');
  if @ShOp=nil then begin
   FreeLibrary(dllHandle);
   old_locate(fname);
   exit;
  end;

 CoInitialize(nil);

 GetItemIdListFromPath(utf8strtowidestr(fname),idlist);

 try
  hr:=shop(idlist,0,nil,0);
 except
  old_locate(fname);
  FreeLibrary(dllHandle);
  CoUnInitialize;
  exit;
 end;

 if FAILED(hr) then old_locate(fname);

  FreeLibrary(dllHandle);
  CoUnInitialize;
end;}
{
procedure getfreedrivespace;
   function Tnt_GetDiskFreeSpaceExW(lpRootPathName: PWideChar; var FreeAvailable, TotalSpace: TLargeInteger; TotalFree: PLargeInteger): Bool;
   begin
    if (Win32Platform=VER_PLATFORM_WIN32_NT) then Result := GetDiskFreeSpaceExW(lpRootPathName,FreeAvailable, TotalSpace,TotalFree)
     else Result := GetDiskFreeSpaceExA(PAnsiChar(AnsiString(lpRootPathName)),FreeAvailable, TotalSpace,TotalFree);
   end;

var
             freeavailable,
             totalspace:int64;
begin
              try
                   
                if Tnt_GetDiskFreeSpaceExW(pwidechar(vars_global.myshared_folder),
                                         freeavailable,
                                         totalspace,
                                         nil) then begin
                  frm_settings.lbl_opt_tran_disksp.caption:=GetLangStringW(STR_AVAILABLE_SPACE)+': '+ inttostr(freeavailable div MEGABYTE)+
                                                    'Mb ('+ inttostr(freeavailable div GIGABYTE)+ 'Gb)';
                          if Tnt_GetDiskFreeSpaceExW(pwidechar(vars_global.my_torrentfolder),
                                                     freeavailable,
                                                     totalspace,
                                                     nil) then frm_settings.lbl_opt_torrent_disksp.caption:=GetLangStringW(STR_AVAILABLE_SPACE)+': '+
                                                                                                            inttostr(freeavailable div MEGABYTE)+
                                                                                                            'Mb ('+ inttostr(freeavailable div GIGABYTE)+ 'Gb)';
                  exit;
                end;
              except
              end;
              frm_settings.lbl_opt_tran_disksp.caption:='';
end;
}
procedure write_padding(stream:thandlestream; size:int64);
var
padding:array[0..4095] of char;
written,to_write:int64;
begin
written:=0;
fillchar(padding,sizeof(padding),0);

repeat
to_write:=size-written;
 if to_write<=0 then break;
 if to_write>sizeof(padding) then to_write:=sizeof(padding);
  stream.write(padding,to_write);
  inc(written,to_write); //creiamo nuovo hole su disco
until (not true);

 FlushFileBuffers(stream.handle);  //proviamo...
end;

procedure get_subdirs(var list:tmystringlist; dir:widestring);
var doserror:integer;
searchrec:ares_types.tsearchrecW;
utf8name:string;
dira:widestring;
begin
try


      try
      DosError := helper_diskio.FindFirstW(dir+'\*.*', faAnyFile, SearchRec);
      while DosError = 0 do begin

       if (((SearchRec.attr and faDirectory)>0) and
            (SearchRec.name <> '.') and
            (SearchRec.name <> '..') and
            (lowercase(SearchRec.name)<> 'winnt') and
            (lowercase(SearchRec.name)<> 'windows') and
            (lowercase(SearchRec.name)<> 'system') and
            (lowercase(SearchRec.name)<> 'system32')) then begin


              utf8name:=widestrtoutf8str(dir+'\'+searchrec.name);
              if list.indexof(utf8name)=-1 then list.add(utf8name);

             dira:=dir+'\'+searchrec.name;
             get_subdirs(list,dira);
      end;
      DosError := helper_diskio.FindNextW(SearchRec); {Look for another subdirectory}
     end;
     finally
     helper_diskio.FindCloseW(SearchRec);
     end;

except
end;
end;

procedure erase_dir_recursive(path:widestring);
var
returncode:integer;
searchrec:ares_types.tsearchrecW;
path1:widestring;
dirU:string;
begin
dirU:=lowercase(widestrtoutf8str(path));

//safecheck...what we are allowed to erase
//BitTorrent folder in shared_folder, preview directory and tempUL phash directory
if pos(lowercase(widestrtoutf8str(vars_global.my_torrentFolder))+'\',dirU)<>1 then
if pos(lowercase(widestrtoutf8str(vars_global.myshared_folder))+'\',dirU)<>1 then
if pos(lowercase(widestrtoutf8str(vars_global.data_path))+'\data\tempul',dirU)<>1 then
if pos(lowercase(widestrtoutf8str(vars_global.data_path))+'\temp',dirU)<>1 then exit;

 
 
 path1:=path+'\*.*';
  try
  ReturnCode:=helper_diskio.FindFirstW(path1,faAnyFile, SearchRec);

    while (ReturnCode = 0) do begin
      IF ((SearchRec.Name <> '.') AND
          (SearchRec.Name <> '..') AND
          ((SearchRec.Attr and faDirectory)>0)) then erase_directory(path+'\'+searchrec.name);
          returncode:=helper_diskio.findnextW(searchrec);
          end;
  finally
  helper_diskio.findcloseW(searchrec);
  end;

  erase_directory(path);
end;

function FindMatchingFileW(var F: ares_types.TSearchRecW): Integer;
var
  LocalFileTime: TFileTime;
begin
  with F do begin
    while FindData.dwFileAttributes and ExcludeAttr <> 0 do
      if not Windows.FindNextFileW(FindHandle, FindData) then begin
        Result := GetLastError;
        Exit;
      end;
    FileTimeToLocalFileTime(FindData.ftLastWriteTime, LocalFileTime);
    FileTimeToDosDateTime(LocalFileTime, LongRec(Time).Hi, LongRec(Time).Lo);
    Size := FindData.nFileSizeLow;
    Attr := FindData.dwFileAttributes;
    Name := FindData.cFileName;
  end;
  Result := 0;
end;

function WStrLCopy(Dest, Source: PWideChar; MaxLen: Cardinal): PWideChar;
var
  Count: Cardinal;
begin
  // copies a specified maximum number of characters from Source to Dest
  Result := Dest;
  Count := 0;
  While (Count < MaxLen) and (Source^ <> #0) do begin
    Dest^ := Source^;
    Inc(Source);
    Inc(Dest);
    Inc(Count);
  end;
  Dest^ := #0;
end;

function WStrPCopy(Dest: PWideChar; const Source: WideString): PWideChar;
begin
  Result := WStrLCopy(Dest, PWideChar(Source), Length(Source));
end;

procedure _MakeWideWin32FindData(var WideFindData: TWIN32FindDataW; AnsiFindData: TWIN32FindDataA);
begin
  CopyMemory(@WideFindData, @AnsiFindData,
    Integer(@WideFindData.cFileName) - Integer(@WideFindData));
  WStrPCopy(WideFindData.cFileName, AnsiFindData.cFileName);
  WStrPCopy(WideFindData.cAlternateFileName, AnsiFindData.cAlternateFileName);
end;

function Tnt_FindNextFileW(hFindFile: THandle; var lpFindFileData: TWIN32FindDataW): BOOL;
var
  Ansi_lpFindFileData: TWIN32FindDataA;
  Win32PlatformIsUnicode : boolean;
begin
  Win32PlatformIsUnicode := (Win32Platform = VER_PLATFORM_WIN32_NT);
  if Win32PlatformIsUnicode then
    Result := FindNextFileW{TNT-ALLOW FindNextFileW}(hFindFile, lpFindFileData)
  else begin
    Result := FindNextFileA{TNT-ALLOW FindNextFileA}(hFindFile, Ansi_lpFindFileData);
    if Result then
      _MakeWideWin32FindData(lpFindFileData, Ansi_lpFindFileData);
  end;
end;

function FindNextW(var F: ares_types.TSearchRecW): Integer;
begin
  if Tnt_FindNextFileW(F.FindHandle, F.FindData) then
    Result := helper_diskio.FindMatchingFileW(F) else
    Result := GetLastError;
end;

procedure FindCloseW(var F: ares_types.TSearchRecW);
begin
  if F.FindHandle <> INVALID_HANDLE_VALUE then
    Windows.FindClose(F.FindHandle);
end;

function isfolder(name:widestring):boolean;
var
    ReturnCode: INTEGER;
    SearchRec : ares_types.TSearchRecW;
begin
  RESULT := false;
  try
  ReturnCode := helper_diskio.FindFirstW(name,faanyfile, SearchRec);
  if ReturnCode = 0 then begin
    if (SearchRec.Attr and faDirectory)>0 then result:=true else result:=false;
  end;
  finally
  helper_diskio.findcloseW(searchrec);
  end;
end;

function Tnt_RemoveDirectoryW(lpPathName: PWideChar): BOOL;
var Win32PlatformIsUnicode : boolean;
begin
  Win32PlatformIsUnicode := (Win32Platform = VER_PLATFORM_WIN32_NT);
  if Win32PlatformIsUnicode then
    Result := RemoveDirectoryW{TNT-ALLOW RemoveDirectoryW}(PWideChar(lpPathName))
  else
    Result := RemoveDirectoryA{TNT-ALLOW RemoveDirectoryA}(PAnsiChar(AnsiString(lpPathName)));
end;

procedure erase_emptydir(path:widestring);
var
returncode:integer;
searchrec:ares_types.tsearchrecW;
path1:widestring;
begin
 path1:=path+'\*.*';


  try
  ReturnCode := helper_diskio.FindFirstW(path1,faDirectory, SearchRec);

    while (ReturnCode = 0) do begin
      IF ((SearchRec.Name <> '.') AND
          (SearchRec.Name <> '..') AND
          ((SearchRec.Attr and faDirectory)>0)) then erase_emptydir(path+'\'+searchrec.name); //directory child , recursivo
          returncode:=helper_diskio.findnextW(searchrec);
          end;
  finally
  helper_diskio.findcloseW(searchrec);
  end;

  Tnt_RemoveDirectoryW(pwidechar(path));

end;

function num_dat_indir(dir:widestring):integer;
var
ReturnCode: INTEGER;
SearchRec : ares_types.TSearchRecW;
begin
result:=0;
  try
ReturnCode := helper_diskio.FindFirstW(dir + '\*.dat',faAnyFile, SearchRec);
    WHILE (ReturnCode = 0) DO BEGIN
      IF ((SearchRec.Name <> '.') AND
          (SearchRec.Name <> '..') AND
          ((SearchRec.Attr and faDirectory)=0)) THEN inc(result);
         ReturnCode := helper_diskio.FindNextW(SearchRec);
      end;
  FINALLY
    helper_diskio.FindCloseW(SearchRec);
  END;
end;

procedure erase_random_dat(dir:widestring);
var
ReturnCode: INTEGER;
SearchRec : ares_types.TSearchRecW;
begin
  try
ReturnCode := helper_diskio.FindFirstW(dir + '\*.dat',faAnyFile, SearchRec);
    WHILE (ReturnCode = 0) DO BEGIN
      IF ((SearchRec.Name <> '.') AND
          (SearchRec.Name <> '..') AND
          ((SearchRec.Attr and faDirectory)=0)) THEN begin
            helper_diskio.deletefileW(dir + '\' + SearchRec.Name);
            break;
          end;
         ReturnCode:=helper_diskio.FindNextW(SearchRec);
      end;
  FINALLY
    helper_diskio.FindCloseW(SearchRec);
  END;
end;

function Tnt_DeleteFileW(lpFileName: PWideChar): BOOL;
var Win32PlatformIsUnicode : boolean;
begin
Win32PlatformIsUnicode := (Win32Platform = VER_PLATFORM_WIN32_NT);
  if Win32PlatformIsUnicode then
//    Result := DeleteFileW{TNT-ALLOW DeleteFileW}(lpFileName)
    Result := DeleteFile{TNT-ALLOW DeleteFileW}(lpFileName)
  else
    Result := DeleteFileA{TNT-ALLOW DeleteFileA}(PAnsiChar(AnsiString(lpFileName)));
end;

function deletefileW(filename:widestring):boolean;
begin
 if Win32Platform=VER_PLATFORM_WIN32_NT then
  if length(filename)>MAX_PATH then filename:='\\?\'+filename;

//  showmessage(filename);
  result:=TNT_DeleteFileW(pwidechar(filename));
end;

function MoveToRecycle(sFileName: widestring): Boolean;
var
  fosW: TSHFileOpStructW;
  fosA: TSHFileOpStructA;
begin


 if Win32Platform=VER_PLATFORM_WIN32_NT then begin

  if length(sfilename)>MAX_PATH then sfilename:='\\?\'+sfilename;
  FillChar(fosW, SizeOf(fosW), 0);
  with fosW do begin
    wFunc  := FO_DELETE;
    pFrom  := PWideChar(sFileName+chr(0));
    fFlags := FOF_ALLOWUNDO or FOF_NOCONFIRMATION or FOF_SILENT or FOF_NOERRORUI;
  end;
  Result := (0 = ShFileOperationW(fosW));

 end else begin

   FillChar(fosA, SizeOf(fosA), 0);
   with fosA do begin
    wFunc  := FO_DELETE;
    pFrom  := PAnsiChar(AnsiString(sFileName));
    fFlags := FOF_ALLOWUNDO or FOF_NOCONFIRMATION or FOF_SILENT or FOF_NOERRORUI;
   end;
   Result := (0 = ShFileOperationA(fosA));

 end;


end;

function erase_directory(dir:widestring):boolean;
var
 ReturnCode:INTEGER;
 SearchRec:ares_types.TSearchRecW;
 dirU:string;
begin
result:=true;
dirU:=lowercase(widestrtoutf8str(dir));


//safecheck...what we are allowed to erase
//BitTorrent folder in shared_folder, preview directory and tempUL phash directory
if pos(lowercase(widestrtoutf8str(vars_global.my_torrentFolder))+'\',dirU)<>1 then
 if pos(lowercase(widestrtoutf8str(vars_global.myshared_folder))+'\',dirU)<>1 then
  if pos(lowercase(widestrtoutf8str(vars_global.data_path))+'\data\tempul',dirU)<>1 then
   if pos(lowercase(widestrtoutf8str(vars_global.data_path))+'\temp',dirU)<>1 then exit;

  try
  ReturnCode := helper_diskio.FindFirstW(dir + '\*.*',faAnyFile, SearchRec);
    while (ReturnCode=0) do begin

      IF ((SearchRec.Name='.') or (SearchRec.Name='..')) then begin
        ReturnCode:=helper_diskio.FindNextW(SearchRec);
        continue;
      end;

      if (SearchRec.Attr and faDirectory)>0 then erase_directory(dir+'\'+SearchRec.name)
       else begin
         if not isWriteAbleFile(dir+'\'+SearchRec.Name) then result:=false
          else
         if not helper_diskio.deletefileW(dir+'\'+SearchRec.Name) then RESULT:=FALSE;
       end;

      ReturnCode:=helper_diskio.FindNextW(SearchRec);
    END;

  finally
    helper_diskio.FindCloseW(SearchRec);
  end;


  result:=Tnt_RemoveDirectoryW(pwidechar(dir)) and result;
END;

function Tnt_CreateFileW(lpFileName: PWideChar; dwDesiredAccess, dwShareMode: DWORD;
  lpSecurityAttributes: PSecurityAttributes; dwCreationDisposition, dwFlagsAndAttributes: DWORD;
    hTemplateFile: THandle): THandle;
var Win32PlatformIsUnicode : boolean;
sl:TStringList;
s:string;
fn:string;
wchfn: PWideChar;
begin
  Win32PlatformIsUnicode := (Win32Platform = VER_PLATFORM_WIN32_NT);
  if Win32PlatformIsUnicode then
  begin
    //ShowMessage(String(lpFileName));

    {if Pos('c:\Downloads\torrents\',widestrtoutf8str(lpFileName))>0 then
    begin
    sl:=TStringList.Create;
    try
    sl.Text:=PWideToString(lpFileName);//widestrtoutf8str(lpFileName);
    sl.SaveToFile('c:\Argent_Test2\Argent_Alloy_Portable2\1.txt');
    finally
      sl.Free;
    end;
     fn:=widestrtoutf8str(lpFileName);
     wchfn:=StringToPWide(fn);
     Result := CreateFileW(wchfn, dwDesiredAccess, dwShareMode,
       lpSecurityAttributes, dwCreationDisposition, dwFlagsAndAttributes, hTemplateFile)
    end;}
    //else
    Result := CreateFileW{TNT-ALLOW CreateFileW}(lpFileName, dwDesiredAccess, dwShareMode,
       lpSecurityAttributes, dwCreationDisposition, dwFlagsAndAttributes, hTemplateFile);
       
    {if Pos('c:\Downloads\torrents\',widestrtoutf8str(lpFileName))>0 then
    begin
    sl:=TStringList.Create;
    try
    sl.Text:=PWideToString(lpFileName);//widestrtoutf8str(lpFileName);
    //syserrormessage(getlasterror)
    sl.Add('GetLastError: '+syserrormessage(GetLastError));
    sl.SaveToFile('c:\Argent_Test2\Argent_Alloy_Portable2\1.txt');
    finally
      sl.Free;
    end;}

    { fn:=widestrtoutf8str(lpFileName);
     wchfn:=StringToPWide(fn);
     Result := CreateFileW(wchfn, dwDesiredAccess, dwShareMode,
       lpSecurityAttributes, dwCreationDisposition, dwFlagsAndAttributes, hTemplateFile)
    end;}
  end
  else
  begin
    //ShowMessage(AnsiString(lpFileName));
    Result := CreateFileA{TNT-ALLOW CreateFileA}(PAnsiChar(AnsiString(lpFileName)), dwDesiredAccess, dwShareMode,
      lpSecurityAttributes, dwCreationDisposition, dwFlagsAndAttributes, hTemplateFile)
  end;
end;

function getFileDateW(const FileName: widestring):cardinal;
var
 FH:Integer;
 Fname:widestring;
 FDate:longint;
 FDateTime: TDateTime;
begin
result:=0;

  fname:=FileName;
  if Win32Platform=VER_PLATFORM_WIN32_NT then begin
   if length(Fname)>MAX_PATH then Fname:='\\?\'+FName;
  end;
  fh:=Tnt_CreateFileW(PwideChar(Fname),
                                   GENERIC_READ ,
                                   FILE_SHARE_READ or FILE_SHARE_WRITE ,
                                   nil,
                                   OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,
                                   0);
  if fh=INVALID_HANDLE_VALUE then exit;


  FDate:=FileGetDate(FH);
  CloseHandle(fh);

  FDateTime:=FileDateToDateTime(Fdate);

  result:=helper_datetime.DelphiDateTimeToUnix(FDateTime);

end;


function FileExists(const FileName: widestring): Boolean;
var
hand:cardinal;
Fname:widestring;
  //  ReturnCode:INTEGER;
  //  SearchRec:ares_types.TSearchRecW;
begin
  fname:=FileName;
  if Win32Platform=VER_PLATFORM_WIN32_NT then begin
   if length(Fname)>MAX_PATH then Fname:='\\?\'+FName;
  end;
  
  hand:=Tnt_CreateFileW(PwideChar(Fname),
                                   GENERIC_READ ,
                                   FILE_SHARE_READ or FILE_SHARE_WRITE ,
                                   nil,
                                   OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,
                                   0);


  result:=(hand<>INVALID_HANDLE_VALUE);
  if result then CloseHandle(hand);

  {
  try
  ReturnCode:=helper_diskio.FindFirstW(FileName,faAnyFile, SearchRec);
  if ReturnCode=0 then result:=true;

  finally
  helper_diskio.findcloseW(searchrec);
  end;}
end;

function Tnt_FindFirstFileW(lpFileName: PWideChar; var lpFindFileData: TWIN32FindDataW): THandle;
var
  Ansi_lpFindFileData: TWIN32FindDataA;
  Win32PlatformIsUnicode : boolean;
begin
  if Win32PlatformIsUnicode then
    Result := FindFirstFileW{TNT-ALLOW FindFirstFileW}(lpFileName, lpFindFileData)
  else begin
    Result := FindFirstFileA{TNT-ALLOW FindFirstFileA}(PAnsiChar(AnsiString(lpFileName)),
      Ansi_lpFindFileData);
    if Result <> INVALID_HANDLE_VALUE then
      _MakeWideWin32FindData(lpFindFileData, Ansi_lpFindFileData);
  end;
end;

function FindFirstW(const Path: widestring; Attr: Integer; var F: ares_types.TSearchRecW): Integer;
const
  faSpecial = faHidden or faSysFile or faVolumeID or faDirectory;
begin
  F.ExcludeAttr := not Attr and faSpecial;
  F.FindHandle := Tnt_FindFirstFileW(PwideChar(Path), F.FindData);
  if F.FindHandle <> INVALID_HANDLE_VALUE then begin
    Result := helper_diskio.FindMatchingFileW(F);
    if Result <> 0 then helper_diskio.FindCloseW(F);
  end else
    Result := GetLastError;
end;

function direxistsW(dirname:widestring):boolean;
var
dirinfo:ares_types.tsearchrecW;
doserror:integer;
str:widestring;
begin
str:=dirname;
if length(str)>0 then if str[length(str)]='\' then str:=copy(str,1,length(str)-1);
try
dosError := helper_diskio.FindFirstW(str, faAnyFile, dirInfo);
       result:=((doserror=0) and ((dirinfo.attr and fadirectory)>0));
       helper_diskio.findcloseW(dirinfo);
except
       result:=false;
end;
end;

function isWriteableFile(Filename: widestring):boolean;
var
hand:cardinal;
begin
result:=false;

if Win32Platform=VER_PLATFORM_WIN32_NT then
 if length(filename)>MAX_PATH then filename:='\\?\'+filename;

hand:=Tnt_CreateFileW(PwideChar(FileName),
                                 GENERIC_WRITE or GENERIC_READ ,
                                 FILE_SHARE_READ ,
                                 nil,
                                 OPEN_EXISTING,
                                 FILE_ATTRIBUTE_NORMAL,
                                 0);
if hand=INVALID_HANDLE_VALUE then exit;
closehandle(hand);

result:=true;
end;

function MyFileOpen(Filename: widestring; mode:integer):ThandleStream;
var
hand:cardinal;
sl:TStringList;
begin
result:=nil;

try

  if Win32Platform=VER_PLATFORM_WIN32_NT then
   if length(filename)>MAX_PATH then filename:='\\?\'+filename;


  case mode of

   ARES_READONLY_ACCESS:hand:=Tnt_CreateFileW(PWideChar(FileName),
                                                         GENERIC_READ ,
                                                         FILE_SHARE_READ or FILE_SHARE_WRITE ,
                                                         nil,
                                                         OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,
                                                         0);

   ARES_WRITE_EXISTING:hand:=Tnt_CreateFileW(PWideChar(FileName),
                                                        GENERIC_WRITE or GENERIC_READ ,
                                                        FILE_SHARE_READ ,
                                                        nil,
                                                        OPEN_EXISTING,
                                                        FILE_ATTRIBUTE_NORMAL,
                                                        0);

   ARES_OVERWRITE_EXISTING:hand:=Tnt_CreateFileW(PWideChar(FileName),
                                                            GENERIC_WRITE or GENERIC_READ ,
                                                            FILE_SHARE_READ ,
                                                            nil,
                                                            CREATE_ALWAYS,
                                                            FILE_ATTRIBUTE_NORMAL,
                                                            0);

   ARES_TRUNCATE_EXISTING:hand:=Tnt_CreateFileW(PWideChar(FileName),
                                                           GENERIC_WRITE or GENERIC_READ ,
                                                           FILE_SHARE_READ ,
                                                           nil,
                                                           TRUNCATE_EXISTING,
                                                           FILE_ATTRIBUTE_NORMAL,
                                                           0);

   ARES_CREATE_ALWAYSAND_WRITETHROUGH:hand:=Tnt_CreateFileW(PWideChar(FileName),
                                                                       GENERIC_WRITE or GENERIC_READ ,
                                                                       FILE_SHARE_READ ,
                                                                       nil,
                                                                       CREATE_ALWAYS,
                                                                       FILE_ATTRIBUTE_NORMAL or FILE_FLAG_WRITE_THROUGH,
                                                                       0);

   ARES_READONLY_BUT_SEQUENTIAL:hand:=Tnt_CreateFileW(PWideChar(FileName),
                                                                 GENERIC_READ ,
                                                                 FILE_SHARE_READ or FILE_SHARE_WRITE ,
                                                                 nil,
                                                                 OPEN_EXISTING,
                                                                 FILE_ATTRIBUTE_NORMAL or FILE_FLAG_SEQUENTIAL_SCAN,
                                                                 0);

   ARES_WRITEEXISTING_WRITETHROUGH:hand:=Tnt_CreateFileW(PWideChar(FileName),
                                                                    GENERIC_WRITE or GENERIC_READ ,
                                                                    FILE_SHARE_READ ,
                                                                    nil,
                                                                    OPEN_EXISTING,
                                                                    FILE_ATTRIBUTE_NORMAL or FILE_FLAG_WRITE_THROUGH,
                                                                    0);

   ARES_WRITE_EXISTING_BUT_SEQUENTIAL:hand:=Tnt_CreateFileW(PWideChar(FileName),
                                                                       GENERIC_WRITE or GENERIC_READ ,
                                                                       FILE_SHARE_READ ,
                                                                       nil,
                                                                       OPEN_EXISTING,
                                                                       FILE_ATTRIBUTE_NORMAL or FILE_FLAG_SEQUENTIAL_SCAN,
                                                                       0);

   ARES_OVERWRITE_EXISTING_BUT_SEQUENTIAL:hand:=Tnt_CreateFileW(PWideChar(FileName),
                                                                           GENERIC_WRITE or GENERIC_READ ,
                                                                           FILE_SHARE_READ ,
                                                                           nil,
                                                                           CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL or FILE_FLAG_SEQUENTIAL_SCAN,
                                                                           0)
    else exit;

  end;
 if hand=INVALID_HANDLE_VALUE then begin
 
   {sl:=TStringList.Create;
   try
     //sl.LoadFromFile('c:\Argent_Test2\Argent_Alloy_Portable2\1.txt');

     sl.Text:='INVALID_HANDLE_VALUE: '+inttostr(hand);
     sl.add('Filename: '+widestrtoutf8str(Filename));
     sl.add('mode: '+inttostr(mode));
     sl.add('GetLastError: '+ansitoutf8(syserrormessage(GetLastError)));
     sl.SaveToFile('c:\Argent_Test2\Argent_Alloy_Portable2\1.txt');
   finally
     sl.Free;
   end;}
   
   //ShowMessage('INVALID_HANDLE_VALUE: '+inttostr(hand));
   exit;
 end;

except
exit;
end;

try
 result:=THandleStream.create(hand);
except     
 closehandle(hand);
 result:=nil;
end;

end;

procedure FreeHandleStream(var stream:thandlestream);
begin
try
if stream=nil then exit;
 closehandle(stream.handle);
 FreeAndNil(stream);
except
end;
stream:=nil;
end;



procedure parse_file_lines(fname:widestring; var list:tmystringlist);
var
 stream:thandlestream;
 str:string;
 buffer:array[0..511] of char;
 lenread,lenstr,posit:integer;
begin



stream:=MyFileOpen(fname,ARES_READONLY_BUT_SEQUENTIAL);
if stream=nil then exit;

try

while stream.position<stream.size do begin

  lenread:=stream.read(buffer,sizeof(buffer));
  if lenread<1 then break;

   lenstr:=length(str);
   setlength(str,lenstr+lenread);
   move(buffer,str[lenstr+1],lenread*SizeOf(Char));

    while (length(str)>0) do begin
      posit:=pos(chr(13)+chr(10),str);
      if posit=0 then break;
       list.Add(copy(str,1,posit-1));
       delete(str,1,posit+1);
    end;

  if lenread<sizeof(buffer)then break;
end;

except
end;
 FreeHandleStream(stream);

end;

function GetHugeFileSize(const FileName: widestring): int64;
var
hand:cardinal;
fname:widestring;
begin
result:=0;

 fname:=FileName;
 if Win32Platform=VER_PLATFORM_WIN32_NT then begin
  if length(Fname)>MAX_PATH then Fname:='\\?\'+FName;
 end;

  hand:=Tnt_CreateFileW(PwideChar(FName),
                                   GENERIC_READ ,
                                   FILE_SHARE_READ or
                                   FILE_SHARE_WRITE ,
                                   nil,
                                   OPEN_EXISTING,
                                   FILE_ATTRIBUTE_NORMAL,
                                   0);

  if hand=INVALID_HANDLE_VALUE then exit;

  try
    LARGE_INTEGER(Result).LowPart:=GetFileSize(hand, @LARGE_INTEGER(Result).HighPart);
    if LARGE_INTEGER(Result).LowPart=$FFFFFFFF then Win32Check(GetLastError = NO_ERROR);
  except
  end;

  closehandle(hand);
end;

function Tnt_GetDiskFreeSpaceExW(lpRootPathName: PWideChar; var FreeAvailable, TotalSpace: TLargeInteger; TotalFree: PLargeInteger): Bool;
begin
  if Win32Platform=VER_PLATFORM_WIN32_NT then Result:=GetDiskFreeSpaceExW(lpRootPathName, FreeAvailable, TotalSpace,TotalFree)
   else Result:=GetDiskFreeSpaceExA(PAnsiChar(AnsiString(lpRootPathName)), FreeAvailable, TotalSpace,TotalFree);
end;

end.

