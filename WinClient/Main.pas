unit Main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, mormot.core.base, RestServer.U_JWT;

type
  TMainForm = class(TForm)
    cAuthenticate: TButton;
    eResult: TMemo;
    cClearLog: TButton;
    cRefreshToken: TButton;
    cCheckToken: TButton;
    gbConfig: TGroupBox;
    lServer: TLabel;
    lUsername: TLabel;
    lPassword: TLabel;
    Label2: TLabel;
    Label4: TLabel;
    eServer: TEdit;
    ePortNo: TEdit;
    eRoot: TEdit;
    eUsername: TEdit;
    ePassword: TEdit;
    procedure cAuthenticateClick(Sender: TObject);
    procedure cClearLogClick(Sender: TObject);
    procedure cCheckTokenClick(Sender: TObject);
    procedure cRefreshTokenClick(Sender: TObject);
  private
    { Private declarations }
    fClient: TRestHttpClientJWT;
  public
    { Public declarations }
    procedure AddLog(const AText: RawUTF8);
    procedure ClearLog;
  end;

var
  MainForm: TMainForm;

implementation

uses mormot.core.text, RestServer.U_DTB;

{$R *.dfm}

procedure TMainForm.AddLog(const AText: RawUTF8);
begin
  eResult.Lines.Add(AText);
end;

procedure TMainForm.cClearLogClick(Sender: TObject);
begin
  ClearLog;
end;

procedure TMainForm.ClearLog;
begin
  eResult.Clear;
end;

procedure TMainForm.cAuthenticateClick(Sender: TObject);
begin
  if Assigned(fClient) then
    FreeAndNil(fClient);

  fClient := TRestHttpClientJWT.Create(eServer.Text, ePortNo.Text, DTBModel(eRoot.Text));

  if fClient.SetUser(eUsername.Text, ePassword.Text) then begin
    AddLog(FormatUTF8('token: %', [fClient.jwt]));
    AddLog('');
  end else begin
    AddLog('Authentication failed!');
    Exit;
  end;
end;

procedure TMainForm.cCheckTokenClick(Sender: TObject);
begin
  AddLog(FormatUTF8('IsTokenValid: %', [fClient.IsTokenValid]));
  AddLog('');
end;

procedure TMainForm.cRefreshTokenClick(Sender: TObject);
begin
  AddLog(FormatUTF8('RefreshToken: %', [fClient.RefreshToken(eUsername.Text, ePassword.Text)]));
  AddLog(FormatUTF8('token: %', [fClient.jwt]));
  AddLog('');
end;

end.
