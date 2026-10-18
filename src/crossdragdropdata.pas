unit CrossDragDropData;

{$mode objfpc}{$H+}
// Copyright (c) 2026 Tony Stone. 0BSD; see LICENSE.

interface

uses
  Classes, SysUtils;

type
  TCrossDragDropFormat = (cdfText, cdfFiles);
  TCrossDragDropFormats = set of TCrossDragDropFormat;

// Both formats require a handler. Files take precedence over text.
function CrossDragDropChooseFormat(Offered, Accepted, Handled: TCrossDragDropFormats; CopyAllowed: boolean; out Chosen: TCrossDragDropFormat): boolean;
// Reject the whole list when a path is not an existing file with a full path.
function CrossDragDropValidateFiles(Files: TStrings; out Error: string): boolean;
// URI lists use the RTL encoder. Failed encoding returns an empty payload.
function CrossDragDropFilesToURIs(Files: TStrings; out URIs, Error: string): boolean;
// Failed decoding leaves the destination list unchanged.
function CrossDragDropURIsToFiles(const URIs: string; Files: TStrings; out Error: string): boolean;

implementation

uses
  URIParser, LazFileUtils;

function CrossDragDropChooseFormat(Offered, Accepted, Handled: TCrossDragDropFormats; CopyAllowed: boolean; out Chosen: TCrossDragDropFormat): boolean;
var
  Usable: TCrossDragDropFormats;
begin
  Chosen := cdfText;
  Usable := Offered * Accepted * Handled;
  Result := CopyAllowed and (Usable <> []);
  if Result and (cdfFiles in Usable) then
    Chosen := cdfFiles;
end;

function CrossDragDropValidateFiles(Files: TStrings; out Error: string): boolean;
var
  Path: string;
begin
  Error := '';
  if Files = nil then
    Error := 'No file list was supplied.'
  else
    for Path in Files do
      if not FilenameIsAbsolute(Path) or not FileExistsUTF8(Path) or DirectoryExistsUTF8(Path) then
      begin
        Error := 'Not an existing file with a full path: ' + Path;
        Break;
      end;
  Result := Error = '';
end;

function CrossDragDropFilesToURIs(Files: TStrings; out URIs, Error: string): boolean;
var
  Path: string;
begin
  URIs := '';
  Result := CrossDragDropValidateFiles(Files, Error);
  if Result then
    for Path in Files do
      URIs := URIs + FilenameToURI(Path) + #13#10;
end;

// Local file URIs only; the existence check afterwards rejects the rest.
function DecodeLocalFileURI(const Value: string; out Path: string): boolean;
var
  URI: TURI;
begin
  try
    URI := ParseURI(Value, False);
    Result := SameText(URI.Protocol, 'file') and ((URI.Host = '') or SameText(URI.Host, 'localhost')) and URIToFilename(Value, Path);
  except
    on EConvertError do Result := False;
  end;
end;

function CrossDragDropURIsToFiles(const URIs: string; Files: TStrings; out Error: string): boolean;
var
  Lines, Decoded: TStringList;
  Line, Path: string;
begin
  Error := '';
  Result := False;
  Lines := TStringList.Create;
  Decoded := TStringList.Create;
  try
    Lines.Text := URIs;
    for Line in Lines do
    begin
      // text/uri-list allows comment lines.
      if (Line = '') or (Line[1] = '#') then
        Continue;
      if not DecodeLocalFileURI(Line, Path) then
      begin
        Error := 'The offer contains an invalid or nonlocal file URI.';
        Exit;
      end;
      Decoded.Add(Path);
    end;
    if Decoded.Count = 0 then
      Error := 'The offer contains no files.'
    else if CrossDragDropValidateFiles(Decoded, Error) then
    begin
      Files.Assign(Decoded);
      Result := True;
    end;
  finally
    Decoded.Free;
    Lines.Free;
  end;
end;

end.
