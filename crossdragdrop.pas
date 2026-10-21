{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit CrossDragDrop;

{$warn 5023 off : no warning about unused units}
interface

uses
  CrossDragDropData, CrossDragDropHelpers, CrossDragDropGtk, CrossDragDropQt,
  CrossDragDropWin, CrossDragDropReg, LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('CrossDragDropReg', @CrossDragDropReg.Register);
end;

initialization
  RegisterPackage('CrossDragDrop', @Register);
end.
