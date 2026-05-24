program WinClient;

uses
  Vcl.Forms,
  Main in 'Main.pas' {MainForm},
  RestServer.U_JWT in '..\Common\RestServer.U_JWT.pas',
  RestServer.U_DTB in '..\Common\RestServer.U_DTB.pas',
  RestServer.U_Data in '..\Common\RestServer.U_Data.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
