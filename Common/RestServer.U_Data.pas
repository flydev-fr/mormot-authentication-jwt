unit RestServer.U_Data;

interface

uses
  mormot.core.base,
  mormot.core.data,
  mormot.orm.base,
  mormot.orm.core,
  mormot.rest.core;

Type
  TJwtAuthUser = class(TAuthUser)
  private
    FExternalID2: integer;
    FExternalID1: integer;
    FComplement: RawByteString;
  published
    property ExternalID1  : integer read FExternalID1  write FExternalID1;
    property ExternalID2  : integer read FExternalID2  write FExternalID2;
    property Complement   : RawByteString read FComplement write FComplement;
  end;

  TAuthUserClass = class of TJwtAuthUser;

function CreateOrmModel(const aRoot : RawUTF8; const Tables: TOrmClassDynArray; const AuthUserRedefine : TAuthUserClass = nil) : TOrmModel;
function DTBModelBase(const aRoot : RawUTF8) : TOrmModel;

implementation

function CreateOrmModel(const aRoot : RawUTF8; const Tables: TOrmClassDynArray;
  const AuthUserRedefine : TAuthUserClass) : TOrmModel;
const _SysTable : integer = 2;
var Tb : TOrmClassDynArray;
    i : integer;
begin
  SetLength(Tb, length(Tables) + _SysTable);
  if AuthUserRedefine <> nil then
    Tb[0] := AuthUserRedefine
  else
    Tb[0] := TJwtAuthUser;

  Tb[1] := TAuthGroup;

  for i := low(Tables) to High(Tables) do
    Tb[i + _SysTable] := Tables[i];

  result := TOrmModel.Create(Tb, aRoot);
end;

function DTBModelBase(const aRoot : RawUTF8) : TOrmModel;
begin
  Result := CreateOrmModel(aRoot, [TJwtAuthUser,
                                   TAuthGroup]);
end;

end.
