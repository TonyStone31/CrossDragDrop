program CrossDragDropDemoB;

{$mode objfpc}{$H+}
// Copyright (c) 2026 Tony Stone. 0BSD; see LICENSE.

uses
  Interfaces,
  Forms,
  DemoB;

  {$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Title := 'CrossDragDrop demo B';
  Application.Initialize;
  Application.CreateForm(TDemoBForm, DemoBForm);
  Application.Run;
end.
