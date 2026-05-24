object MainForm: TMainForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Connect'
  ClientHeight = 410
  ClientWidth = 468
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  TextHeight = 13
  object cAuthenticate: TButton
    Left = 8
    Top = 102
    Width = 100
    Height = 25
    Caption = 'Authenticate'
    TabOrder = 0
    OnClick = cAuthenticateClick
  end
  object eResult: TMemo
    Left = 8
    Top = 133
    Width = 452
    Height = 242
    Lines.Strings = (
      '')
    TabOrder = 1
  end
  object cClearLog: TButton
    Left = 385
    Top = 381
    Width = 75
    Height = 25
    Caption = 'Clear Logs'
    TabOrder = 2
    OnClick = cClearLogClick
  end
  object cRefreshToken: TButton
    Left = 360
    Top = 102
    Width = 100
    Height = 25
    Caption = 'Refresh Token'
    TabOrder = 3
    OnClick = cRefreshTokenClick
  end
  object cCheckToken: TButton
    Left = 254
    Top = 102
    Width = 100
    Height = 25
    Caption = 'Check Token'
    TabOrder = 4
    OnClick = cCheckTokenClick
  end
  object gbConfig: TGroupBox
    Left = 8
    Top = 8
    Width = 453
    Height = 81
    Caption = 'Configuration'
    TabOrder = 5
    object lServer: TLabel
      Left = 8
      Top = 24
      Width = 39
      Height = 13
      Caption = 'Server: '
    end
    object lUsername: TLabel
      Left = 8
      Top = 51
      Width = 55
      Height = 13
      Caption = 'Username: '
    end
    object lPassword: TLabel
      Left = 216
      Top = 51
      Width = 53
      Height = 13
      Caption = 'Password: '
    end
    object Label2: TLabel
      Left = 216
      Top = 24
      Width = 43
      Height = 13
      Caption = 'Port No: '
    end
    object Label4: TLabel
      Left = 341
      Top = 24
      Width = 30
      Height = 13
      Caption = 'Root: '
    end
    object eServer: TEdit
      Left = 69
      Top = 21
      Width = 141
      Height = 21
      TabOrder = 0
      Text = '127.0.0.1'
    end
    object ePortNo: TEdit
      Left = 275
      Top = 21
      Width = 60
      Height = 21
      TabOrder = 1
      Text = '888'
    end
    object eRoot: TEdit
      Left = 377
      Top = 21
      Width = 60
      Height = 21
      TabOrder = 2
      Text = 'root'
    end
    object eUsername: TEdit
      Left = 69
      Top = 48
      Width = 141
      Height = 21
      TabOrder = 3
      Text = 'User'
    end
    object ePassword: TEdit
      Left = 275
      Top = 48
      Width = 60
      Height = 21
      TabOrder = 4
      Text = 'synopse'
    end
  end
end
