unit DemoB;

{$mode objfpc}{$H+}
// Copyright (c) 2026 Tony Stone. 0BSD; see LICENSE.

// Demo B: a picture that is dragged as a PNG file, a speed button that
// drags a line of text, a panel that takes either, and a picture box that
// takes an image file.

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, StdCtrls, ExtCtrls, Buttons,
  CrossDragDropHelpers;

type
  TDemoBForm = class(TForm)
    imgPicture: TImage;
    imgTarget: TImage;
    lblPicture: TLabel;
    lblTarget: TLabel;
    lblStatus: TLabel;
    pnlDrop: TPanel;
    sbtnQuote: TSpeedButton;
    SourcePicture: TCrossDragDropSource;
    SourceQuote: TCrossDragDropSource;
    TargetAny: TCrossDragDropTarget;
    TargetPicture: TCrossDragDropTarget;
    procedure FormCreate(Sender: TObject);
    procedure SourcePictureGetFiles(Sender: TObject; Files: TStrings);
    procedure SourceQuoteGetText(Sender: TObject; out AText: string);
    procedure SourceDragEnd(Sender: TObject; Outcome: TCrossDragDropOutcome);
    procedure TargetAnyDropText(Sender: TObject; const AText: string; X, Y: integer);
    procedure TargetAnyDropFiles(Sender: TObject; Files: TStrings; X, Y: integer);
    procedure TargetPictureDropFiles(Sender: TObject; Files: TStrings; X, Y: integer);
    procedure HelperError(Sender: TObject; const Message: string);
  end;

var
  DemoBForm: TDemoBForm;

implementation

{$R *.lfm}

procedure TDemoBForm.FormCreate(Sender: TObject);
begin
  // Something to look at: a disc on a light square.
  with imgPicture.Picture.Bitmap do
  begin
    SetSize(120, 90);
    Canvas.Brush.Color := $F0E8D8;
    Canvas.FillRect(0, 0, 120, 90);
    Canvas.Brush.Color := $3070C0;
    Canvas.Ellipse(25, 10, 95, 80);
  end;
end;

procedure TDemoBForm.SourcePictureGetFiles(Sender: TObject; Files: TStrings);
var
  FileName: string;
begin
  // A drag carries files, so the picture is written out first.
  FileName := GetTempDir + 'crossdragdrop-demo-b.png';
  imgPicture.Picture.SaveToFile(FileName);
  Files.Add(FileName);
end;

procedure TDemoBForm.SourceQuoteGetText(Sender: TObject; out AText: string);
begin
  AText := 'A line of text from demo B.';
end;

procedure TDemoBForm.SourceDragEnd(Sender: TObject; Outcome: TCrossDragDropOutcome);
const
  Words: array[TCrossDragDropOutcome] of string = ('Dropped.', 'Canceled.', 'Nothing took it.', 'The drag failed.');
begin
  lblStatus.Caption := Words[Outcome];
end;

procedure TDemoBForm.TargetAnyDropText(Sender: TObject; const AText: string; X, Y: integer);
begin
  pnlDrop.Caption := AText;
  lblStatus.Caption := 'Text received.';
end;

procedure TDemoBForm.TargetAnyDropFiles(Sender: TObject; Files: TStrings; X, Y: integer);
begin
  pnlDrop.Caption := ExtractFileName(Files[0]);
  if Files.Count > 1 then
    pnlDrop.Caption := pnlDrop.Caption + ' and ' + IntToStr(Files.Count - 1) + ' more';
  lblStatus.Caption := IntToStr(Files.Count) + ' file(s) received.';
end;

procedure TDemoBForm.TargetPictureDropFiles(Sender: TObject; Files: TStrings; X, Y: integer);
begin
  try
    imgTarget.Picture.LoadFromFile(Files[0]);
    lblStatus.Caption := 'Picture loaded: ' + ExtractFileName(Files[0]);
  except
    // Tells the other program that the drop was not taken.
    TCrossDragDropTarget(Sender).RejectDrop('Not a picture: ' + ExtractFileName(Files[0]));
  end;
end;

procedure TDemoBForm.HelperError(Sender: TObject; const Message: string);
begin
  lblStatus.Caption := Message;
end;

end.
