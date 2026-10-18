program CrossDragDropDemoA;

{$mode objfpc}{$H+}
// Copyright (c) 2026 Tony Stone. 0BSD; see LICENSE.

uses
  Interfaces,
  Forms,
  DemoA;

  {$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Title := 'CrossDragDrop demo A';
  Application.Initialize;
  Application.CreateForm(TDemoAForm, DemoAForm);
  Application.Run;
end.
