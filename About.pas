// Modeless About dialog: theme-aware branding glyph, self-freeing on close.
unit About;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Imaging.pngimage;

type
  TfrmAbout = class(TForm)
    imgBlack: TImage;
    lblAbout: TLabel;
    imgWhite: TImage;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

function IsDarkThemeEnabled: Boolean;

var
  frmAbout: TfrmAbout;

implementation

uses
  Unit1;

{$R *.dfm}

function IsDarkThemeEnabled: Boolean;
begin
  Result := Assigned(Form1) and Form1.miDark.Checked;
end;

procedure TfrmAbout.FormCreate(Sender: TObject);
begin
  // Match main form theme: dark chrome uses light glyph, light chrome uses dark glyph.
  imgBlack.Visible := not IsDarkThemeEnabled;
  imgWhite.Visible := IsDarkThemeEnabled;
  // Stay above scratchpad while open; caller does not modal-block the main form.
  FormStyle := fsStayOnTop;
end;

procedure TfrmAbout.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  // Caller only Show's the form; caFree avoids leaking instances and stale references.
  Action := caFree;
end;

end.
