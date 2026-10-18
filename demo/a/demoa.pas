unit DemoA;

{$mode objfpc}{$H+}
// Copyright (c) 2026 Tony Stone. 0BSD; see LICENSE.

// Demo A: a button that drags the text of an edit box, a label that drags
// a file, a memo that takes text and a list that takes files.  Run demo B
// beside it, or use any other program, and drag both ways.

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, CrossDragDropHelpers;

type
  TDemoAForm = class(TForm)
    btnText: TButton;
    edtText: TEdit;
    lblFile: TLabel;
    lblHint: TLabel;
    lblMemo: TLabel;
    lblList: TLabel;
    lblStatus: TLabel;
    lstFiles: TListBox;
    memText: TMemo;
    SourceText: TCrossDragDropSource;
    SourceFile: TCrossDragDropSource;
    TargetText: TCrossDragDropTarget;
    TargetFiles: TCrossDragDropTarget;
    procedure FormCreate(Sender: TObject);
    procedure SourceTextGetText(Sender: TObject; out AText: string);
    procedure SourceFileGetFiles(Sender: TObject; Files: TStrings);
    procedure SourceDragEnd(Sender: TObject; Outcome: TCrossDragDropOutcome);
    procedure TargetTextDropText(Sender: TObject; const AText: string; X, Y: integer);
    procedure TargetFilesDropFiles(Sender: TObject; Files: TStrings; X, Y: integer);
    procedure HelperError(Sender: TObject; const Message: string);
  private
    FFile: string;
  end;

var
  DemoAForm: TDemoAForm;

implementation

{$R *.lfm}

procedure TDemoAForm.FormCreate(Sender: TObject);
var
  Lines: TStringList;
begin
  // The file the label offers; a drag can only carry files that exist.
  FFile := GetTempDir + 'crossdragdrop-demo-a.txt';
  Lines := TStringList.Create;
  try
    Lines.Add('This file was dragged out of CrossDragDrop demo A.');
    Lines.SaveToFile(FFile);
  finally
    Lines.Free;
  end;
  lblFile.Caption := 'Drag this file: ' + ExtractFileName(FFile);
end;

procedure TDemoAForm.SourceTextGetText(Sender: TObject; out AText: string);
begin
  AText := edtText.Text;
end;

procedure TDemoAForm.SourceFileGetFiles(Sender: TObject; Files: TStrings);
begin
  Files.Add(FFile);
end;

procedure TDemoAForm.SourceDragEnd(Sender: TObject; Outcome: TCrossDragDropOutcome);
const
  Words: array[TCrossDragDropOutcome] of string = ('Dropped.', 'Canceled.', 'Nothing took it.', 'The drag failed.');
begin
  lblStatus.Caption := Words[Outcome];
end;

procedure TDemoAForm.TargetTextDropText(Sender: TObject; const AText: string; X, Y: integer);
begin
  memText.Lines.Add(AText);
  lblStatus.Caption := 'Text received.';
end;

procedure TDemoAForm.TargetFilesDropFiles(Sender: TObject; Files: TStrings; X, Y: integer);
begin
  lstFiles.Items.AddStrings(Files);
  lblStatus.Caption := IntToStr(Files.Count) + ' file(s) received.';
end;

procedure TDemoAForm.HelperError(Sender: TObject; const Message: string);
begin
  lblStatus.Caption := Message;
end;

end.
