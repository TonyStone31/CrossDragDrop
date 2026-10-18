unit CrossDragDropReg;

{$mode objfpc}{$H+}
// Copyright (c) 2026 Tony Stone. 0BSD; see LICENSE.

interface

procedure Register;

implementation

uses Classes, LResources, CrossDragDropHelpers;

procedure Register;
begin
  RegisterComponents('System', [TCrossDragDropSource, TCrossDragDropTarget]);
end;

initialization
  {$I crossdragdroppalette.lrs}
end.
