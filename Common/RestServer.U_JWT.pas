unit RestServer.U_JWT;

interface
uses
  Windows,
  SysUtils,
  Classes,
  mormot.core.base,
  mormot.core.os,
  mormot.core.text,
  mormot.core.unicode,
  mormot.core.zip,
  mormot.core.json,
  mormot.core.rtti,
  mormot.core.variants,
  mormot.rest.core,
  mormot.rest.client,
  mormot.rest.server,
  mormot.orm.rest,
  mormot.orm.core,
  mormot.net.sock,
  mormot.net.http,
  mormot.net.client,
  {$ifndef NOHTTPCLIENTWEBSOCKETS}
  mormot.net.ws.core, // for WebSockets
  {$endif}
  mormot.crypt.core,    // for hcSynShaAes
  mormot.crypt.jwt,
  mormot.crypt.secure,
  mormot.core.log,
  mormot.rest.http.client;

const
  JWTDefaultTimeout: integer = 10;
  JWTDefaultRefreshTimeOut : Cardinal = (SecsPerDay div 3 + UnixDateDelta);

type
  TRestRoutingREST_JWT = class(TRestServerRoutingRest)
  protected
    procedure AuthenticationFailed(Reason: TOnAuthenticationFailedReason); override;
  end;

  TRestServerAuthenticationJWT = class(TRestServerAuthenticationHttpBasic)
  protected
    procedure SessionCreate(Ctxt: TRestServerUriContext; var User: TAuthUser); override;
    procedure AuthenticationFailed(Ctxt: TRestServerURIContext; Reason: TOnAuthenticationFailedReason);
  public
    function RetrieveSession(Ctxt: TRestServerUriContext): TAuthSession; override;

    function Auth(Ctxt: TRestServerUriContext; const aUserName: RawUtf8): boolean; override;
  end;

  TRestServerAuthenticationJWTClass = class of TRestServerAuthenticationJWT;

  TRestClientAuthenticationJWT = class(TRestClientAuthenticationHttpBasic)
  protected
    class function ClientGetSessionKey(Sender: TRestClientUri; User: TAuthUser; const aNameValueParameters: array of const): RawUtf8; override;
  public
    class function ClientSetUser(Sender: TRestClientUri; const aUserName, aPassword: RawUTF8): Boolean; reintroduce;
  end;

  TRestHttpClientJWT = class(TRestHttpClientRequest)
  private
    fJWT: RawUTF8;
  protected
    procedure InternalSetClass; override;
    function InternalRequest(const url, method: RawUTF8; var Header, Data, DataType: RawUTF8): Int64Rec; override;
  public
    function IsTokenValid: RawUTF8;
    function RefreshToken(const aUsername, aPassword: RawUTF8): RawUTF8;

    function SetUser(const aUserName, aPassword: RawUTF8; aHashedPassword: Boolean=false): boolean; reintroduce;

    property jwt : RawUTF8 read fJWT write fJWT;
  end;

function getAlgo(const Value : RawUTF8): TSignAlgo;

implementation

function HeaderOnce(const Head : RawUTF8; upper: PAnsiChar): RawUTF8;
  {$ifdef HASINLINE}inline;{$endif}
begin
  if (Head <> '') then
    result := FindNameValue(pointer(Head), upper)
  else
    result := '';
end;

function getAlgo(const Value: RawUTF8): TSignAlgo;
var
  i: TSignAlgo;
begin
  Result := saSha256;
  for i := low(JWT_TEXT) to High(JWT_TEXT) do
    if SameTextU(Value, JWT_TEXT[i]) then
    begin
      result := i;
      break;
    end;
end;

{ TRestRoutingREST_JWT }

procedure TRestRoutingREST_JWT.AuthenticationFailed(Reason: TOnAuthenticationFailedReason);
begin
  inherited AuthenticationFailed(Reason);
end;

{ TSQLRestServerAuthenticationJWT }

function TRestServerAuthenticationJWT.Auth(Ctxt: TRestServerURIContext; const aUserName: RawUTF8): boolean;
var
  aPassWord: RawUTF8;
  User: TAuthUser;
begin
  result := False;

  if AuthSessionRelease(Ctxt, aUserName) then
    exit;

  if not Assigned(fServer.JWTForUnauthenticatedRequest) then
  begin
    AuthenticationFailed(Ctxt, afJWTRequired);
    Exit;
  end;

  aPassWord := Ctxt.InputUTF8OrVoid['Password'];

  if (aUserName<>'') and (length(aPassWord)>0) then
  begin
    User := GetUser(Ctxt,aUserName);
    try
      result := User<>nil;
      if result then
      begin
        if CheckPassword(Ctxt, User, aPassWord) then
          SessionCreate(Ctxt, User)
        else AuthenticationFailed(Ctxt, afInvalidPassword);
      end
      else AuthenticationFailed(Ctxt, afUnknownUser);
    finally
      if result then
        User.Free;
    end;
  end
  else AuthenticationFailed(Ctxt, afUnknownUser);
end;

procedure TRestServerAuthenticationJWT.AuthenticationFailed(Ctxt: TRestServerURIContext; Reason: TOnAuthenticationFailedReason);
begin
  if Ctxt is TRestRoutingREST_JWT then
    TRestRoutingREST_JWT(Ctxt).AuthenticationFailed(Reason);
end;

function TRestServerAuthenticationJWT.RetrieveSession(Ctxt: TRestServerURIContext): TAuthSession;
var
  aUserName : RawUTF8;
  User: TAuthUser;
  i : Integer;
  tmpIdsession : Cardinal;
  pSession : PDocVariantData;
  vSessionPrivateSalt : RawUTF8;
begin
  result := inherited RetrieveSession(Ctxt);

  if result <> nil then
    Exit;

  if not Assigned(fServer.JWTForUnauthenticatedRequest) then
    Exit;

  vSessionPrivateSalt := '';

  if Ctxt.AuthenticationBearerToken <> '' then
    if Ctxt.AuthenticationCheck(fServer.JWTForUnauthenticatedRequest) then begin
      aUserName := Ctxt.JWTContent.reg[jrcIssuer];

      User := GetUser(Ctxt,aUserName);
      try
        if User <> nil then begin
          if Ctxt.Server.Sessions <> nil then begin
            if Ctxt.JWTContent.data.GetValueIndex('sessionkey') >= 0 then
              vSessionPrivateSalt := Ctxt.JWTContent.data.U['sessionkey'];

            Ctxt.Server.Sessions.Safe.ReadWriteLock;
            try
              // Search session for User
              if (reOneSessionPerUser in Ctxt.Call^.RestAccessRights^.AllowRemoteExecute) and (Ctxt.Server.Sessions<>nil) then
                for i := 0 to Pred(Ctxt.Server.Sessions.Count) do
                  if TAuthSession(Ctxt.Server.Sessions[i]).User.ID = User.ID then begin
                    Result := TAuthSession(Ctxt.Server.Sessions[i]);

                    Ctxt.Session := Result.ID;

                    Break;
                  end;

              // Search session by privatesalt
              if result = nil then
                for i := 0 to Pred(Ctxt.Server.Sessions.Count) do
                  if SameTextU(vSessionPrivateSalt,
                    ToUtf8(TAuthSession(Ctxt.Server.Sessions[i]).ID) + '+' +
                      TAuthSession(Ctxt.Server.Sessions[i]).PrivateKey) then
                  begin
                    Result := TAuthSession(Ctxt.Server.Sessions[i]);
                    Ctxt.Session := Result.ID;
                    break;
                  end;
            finally
              Ctxt.Server.Sessions.Safe.ReadWriteUnLock;
            end;
          end;
        end;
      finally
        User.free;
      end;
    end;
end;

procedure TRestServerAuthenticationJWT.SessionCreate(Ctxt: TRestServerUriContext; var User: TAuthUser);
var
  i : Integer;
  Token : RawUTF8;
  jWtClass : TJWTSynSignerAbstractClass;
  vPass, vUser, Signat, vSessionKey : RawUTF8;
  vTmp : TDocVariantData;
begin
  vUser := User.LogonName;
  vPass := User.PasswordHashHexa;

  inherited SessionCreate(Ctxt, User);

  if Ctxt.Call^.OutStatus = HTTP_SUCCESS then
  begin
    vTmp.InitJSON(Ctxt.Call^.OutBody);
    if vTmp.Kind <> dvUndefined then
      if fServer.JWTForUnauthenticatedRequest <> nil then
      begin
        jwtClass := JWT_CLASS[getAlgo(fServer.JWTForUnauthenticatedRequest.Algorithm)];
        vSessionKey := vTmp.U['result'];
        Token := (fServer.JWTForUnauthenticatedRequest as jwtClass).
          Compute([ 'sessionkey', vSessionKey], vUser,
          'jwt.access', '', 0, JWTDefaultTimeout, @Signat);
        Ctxt.Call^.OutBody := _Obj(['result', vTmp.U['result'], 'jwt', Token]);
      end;
  end;
end;



{ TRestClientAuthenticationJWT }

class function TRestClientAuthenticationJWT.ClientGetSessionKey(Sender: TRestClientUri; User: TAuthUser; const aNameValueParameters: array of const): RawUtf8;
var resp: RawUTF8;
begin
  Result := '';
  if (Sender.CallBackGet('Auth',aNameValueParameters,resp) = HTTP_SUCCESS) then
    result := resp;
end;

class function TRestClientAuthenticationJWT.ClientSetUser(Sender: TRestClientUri; const aUserName, aPassword: RawUTF8): Boolean;
var res: RawUTF8;
  U: TAuthUser;
  vTmp : Variant;
begin
  Result := False;

  if (aUserName = '') or (Sender = nil) then
    Exit;

  if not Sender.InheritsFrom(TRestHttpClientJWT) then
    Exit;

  Sender.SessionClose; // to make Sender.SessionUser = nil

  try
    ClientSetUserHttpOnly(Sender, aUserName, aPassword, '', 20000, daUndefined);

    TRestHttpClientJWT(Sender).jwt := '';

    U := TAuthUser(Sender.Model.GetTableInherited(TAuthUser).Create);
    try
      U.LogonName := trim(aUserName);

      res := ClientGetSessionKey(Sender, U, ['Username', aUserName, 'password', aPassword]);

      if res<>'' then begin
        vTmp := _JsonFast(res);
        if DocVariantType.IsOfType(vTmp) then begin
          U.IDValue := UTF8ToInt64(TDocvariantData(vTmp).U['userid']);
          Result := TRestHttpClientJWT(Sender).SessionCreate(TRestClientAuthenticationClass(self), mormot.rest.core.TAuthUser(U), TDocvariantData(vTmp).U['result']);
          if Result then TRestHttpClientJWT(Sender).jwt := TDocvariantData(vTmp).U['jwt'];
        end;
      end;
    finally
      U.Free;
    end;
  finally
    if not Result then begin
      TRestHttpClientJWT(Sender).jwt := '';
    end;

    if Assigned(Sender.OnSetUser) then
      Sender.OnSetUser(Sender); // always notify of user change, even if failed
  end;
end;






{ TSQLHttpClientJWT }

function TRestHttpClientJWT.InternalRequest(const url, method: RawUTF8;
  var Header, Data, DataType: RawUTF8): Int64Rec;
var
  vBasic : RawUTF8;
  h : Integer;
begin
  if fjwt <> '' then
  begin
    // Change Header if jwt exist
    vBasic := HeaderOnce(Header, 'AUTHORIZATION: BASIC ');
    if vBasic <> '' then
    begin
      h := PosEx(vBasic, Header);
      if h = 22 then
        header := copy(Header, h + Length(vBasic), Length(header))
      else
        header := copy(Header, 1, h - 22) +
          copy(Header, h + Length(vBasic), Length(header));
      header := Trim(header);
    end;
    Header := trim(HEADER_BEARER_UPPER + fJWT + #13#10 + Header);
  end;
  result := inherited InternalRequest(url, method, Header, Data, DataType);
end;

procedure TRestHttpClientJWT.InternalSetClass;
begin
  fRequestClass := TWinHTTP;
end;

function TRestHttpClientJWT.IsTokenValid: RawUTF8;
begin
  CallBackGet('IsValidToken', [], Result);
end;

function TRestHttpClientJWT.RefreshToken(const aUsername, aPassword: RawUTF8): RawUTF8;
begin
  CallBackGet('RefreshToken', ['username', aUsername, 'password', aPassword], Result);
end;

function TRestHttpClientJWT.SetUser(const aUserName, aPassword: RawUTF8;
  aHashedPassword: Boolean): boolean;
const
  HASH: array[boolean] of TRestClientSetUserPassword = (passClear, passHashed);
begin
  if self=nil then
  begin
    result := false;
    exit;
  end;

  result := TRestClientAuthenticationJWT.ClientSetUser(self,aUserName,aPassword);
end;

end.
