// Main form: scratchpad memo, tray/hotkey lifecycle, settings INI, pin/opacity/theme UX.
unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.ActiveX, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  Vcl.ComCtrls, Vcl.ExtCtrls, System.IOUtils, System.IniFiles, Vcl.Menus, Vcl.Themes,
  Vcl.Styles;

type
  TForm1 = class;

  // OLE IDropTarget on the memo HWND; decoupled from VCL drag-over events.
  TMemoDropTarget = class(TInterfacedObject, IDropTarget)
  private
    FForm: TForm1;
    function GetTextFromDataObject(const DataObj: IDataObject): string;
  public
    constructor Create(AForm: TForm1);
    function DragEnter(const dataObj: IDataObject; grfKeyState: Longint;
      pt: TPoint; var dwEffect: Longint): HResult; stdcall;
    function DragOver(grfKeyState: Longint; pt: TPoint;
      var dwEffect: Longint): HResult; stdcall;
    function DragLeave: HResult; stdcall;
    function Drop(const dataObj: IDataObject; grfKeyState: Longint;
      pt: TPoint; var dwEffect: Longint): HResult; stdcall;
  end;

  TForm1 = class(TForm)
    Memo1: TMemo;
    StatusBar1: TStatusBar;
    Timer1: TTimer;
    Timer2: TTimer;
    TrayIcon1: TTrayIcon;
    PopupMenu1: TPopupMenu;
    Exit1: TMenuItem;
    MemoPopup: TPopupMenu;
    Copy1: TMenuItem;
    Cut1: TMenuItem;
    paste1: TMenuItem;
    N2: TMenuItem;
    selectall1: TMenuItem;
    N3: TMenuItem;
    miFont: TMenuItem;
    delete1: TMenuItem;
    N4: TMenuItem;
    FontDialog1: TFontDialog;
    PinMenu: TPopupMenu;
    miEmbed: TMenuItem;
    miFloat: TMenuItem;
    miFree: TMenuItem;
    SettingsPopup: TPopupMenu;
    miStyle: TMenuItem;
    miDark: TMenuItem;
    miLight: TMenuItem;
    N1: TMenuItem;
    miOpacity: TMenuItem;
    mi25: TMenuItem;
    mi50: TMenuItem;
    mi100: TMenuItem;
    N5: TMenuItem;
    miAbout: TMenuItem;
    N6: TMenuItem;
    miAutotrim: TMenuItem;
    miTrimOn: TMenuItem;
    miTrimOff: TMenuItem;
    miHotkey: TMenuItem;
    miHKScroll: TMenuItem;
    miHKPause: TMenuItem;
    miHKInsert: TMenuItem;
    N7: TMenuItem;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure Memo1Change(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure Timer2Timer(Sender: TObject);
    procedure TrayIcon1DblClick(Sender: TObject);
    procedure TrayIcon1MouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure Show1Click(Sender: TObject);
    procedure Exit1Click(Sender: TObject);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormResize(Sender: TObject);
    procedure miFontClick(Sender: TObject);
    procedure Cut1Click(Sender: TObject);
    procedure paste1Click(Sender: TObject);
    procedure Copy1Click(Sender: TObject);
    procedure delete1Click(Sender: TObject);
    procedure selectall1Click(Sender: TObject);
    procedure miEmbedClick(Sender: TObject);
    procedure miFloatClick(Sender: TObject);
    procedure miFreeClick(Sender: TObject);
    procedure FormMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure StatusBar1MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure miAboutClick(Sender: TObject);
    procedure miOpacityClick(Sender: TObject);
    procedure miDarkClick(Sender: TObject);
    procedure miLightClick(Sender: TObject);
    procedure miTrimOnClick(Sender: TObject);
    procedure miTrimOffClick(Sender: TObject);
    procedure miHotkeyPopup(Sender: TObject);
    procedure miHKClick(Sender: TObject);

  private
    Dirty: Boolean;              // Memo changed since last successful autosave
    FHotkey: Integer;            // Virtual key registered with RegisterHotKey
    DropTarget: IInterface;      // Keeps COM drop target alive while registered
    FDropTargetRegistered: Boolean;
    FPendingDropText: string;  // Batched drops from non-UI threads (see WM_USER+2)
    procedure RegisterMemoDropTarget;
    procedure MarkDirty;
    procedure WMUser1(var Msg: TMessage); message WM_USER + 1;           // Legacy hide hook (unused)
    procedure WMAppendDroppedText(var Msg: TMessage); message WM_USER + 2; // Apply FPendingDropText on UI thread
    procedure WMHotkey(var Msg: TWMHotKey); message WM_HOTKEY;
    procedure WMWindowPosChanging(var Message: TWMWindowPosChanging); message WM_WINDOWPOSCHANGING;
    function WordCount(const S: string): Integer;
    procedure UpdateCounts;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
  private
    procedure WMSystemCommand(var Msg: TWMSysCommand); message WM_SYSCOMMAND;
    procedure WMNCLButtonDown(var Msg: TWMNCLButtonDown); message WM_NCLBUTTONDOWN;

    procedure CleanWhitespace;
    procedure TrimTrailingSpaces;

    { INI Persistence }
    procedure LoadSettings;
    procedure SaveSettings;

    const
      MY_HOTKEY_ID = 1;

  public
    procedure AppendDroppedText(const AText: string);
  end;

var
  Form1: TForm1;

implementation

uses
  System.Win.ComObj, About;

{$R *.dfm}

constructor TMemoDropTarget.Create(AForm: TForm1);
begin
  inherited Create;
  FForm := AForm;
end;

function TMemoDropTarget.GetTextFromDataObject(const DataObj: IDataObject): string;
var
  fmt: TFormatEtc;
  med: TStgMedium;
  P: Pointer;
begin
  Result := '';
  if DataObj = nil then
    Exit;

  // Prefer Unicode clipboard format; matches modern drag sources and Delphi strings.
  fmt.cfFormat := CF_UNICODETEXT;
  fmt.ptd := nil;
  fmt.dwAspect := DVASPECT_CONTENT;
  fmt.lindex := -1;
  fmt.tymed := TYMED_HGLOBAL;
  if DataObj.GetData(fmt, med) = S_OK then
  try
    P := GlobalLock(med.hGlobal);
    if P <> nil then
      Result := PChar(P);
    GlobalUnlock(med.hGlobal);
  finally
    ReleaseStgMedium(med);
  end;

  if Result <> '' then
    Exit;

  // Legacy ANSI-only sources (older apps, some shell extensions).
  fmt.cfFormat := CF_TEXT;
  if DataObj.GetData(fmt, med) = S_OK then
  try
    P := GlobalLock(med.hGlobal);
    if P <> nil then
      Result := string(PAnsiChar(P));
    GlobalUnlock(med.hGlobal);
  finally
    ReleaseStgMedium(med);
  end;
end;

function TMemoDropTarget.DragEnter(const dataObj: IDataObject;
  grfKeyState: Longint; pt: TPoint; var dwEffect: Longint): HResult;
begin
  // Many sources expose payload only on Drop, not during DragEnter/DragOver probing.
  dwEffect := DROPEFFECT_COPY;
  Result := S_OK;
end;

function TMemoDropTarget.DragOver(grfKeyState: Longint; pt: TPoint;
  var dwEffect: Longint): HResult;
begin
  dwEffect := DROPEFFECT_COPY;
  Result := S_OK;
end;

function TMemoDropTarget.DragLeave: HResult;
begin
  Result := S_OK;
end;

function TMemoDropTarget.Drop(const dataObj: IDataObject; grfKeyState: Longint;
  pt: TPoint; var dwEffect: Longint): HResult;
var
  s: string;
begin
  s := GetTextFromDataObject(dataObj);
  if s <> '' then
  begin
    FForm.AppendDroppedText(s);
    dwEffect := DROPEFFECT_COPY;
  end
  else
    dwEffect := DROPEFFECT_NONE;
  Result := S_OK;
end;

procedure TForm1.MarkDirty;
begin
  Dirty := True;
  UpdateCounts;
  StatusBar1.Panels[1].Text := 'modified...';
end;

procedure TForm1.AppendDroppedText(const AText: string);
begin
  if AText = '' then
    Exit;
  if GetCurrentThreadId = MainThreadID then
  begin
    Memo1.Lines.Add(AText);
    MarkDirty;
  end
  else
  begin
    // Queue for main thread: COM may call Drop off the UI thread.
    if FPendingDropText = '' then
      FPendingDropText := AText
    else
      FPendingDropText := FPendingDropText + sLineBreak + AText;
    PostMessage(Handle, WM_USER + 2, 0, 0);
  end;
end;

procedure TForm1.WMAppendDroppedText(var Msg: TMessage);
begin
  if FPendingDropText <> '' then
  begin
    Memo1.Lines.Add(FPendingDropText);
    FPendingDropText := '';
    MarkDirty;
  end;
end;

procedure TForm1.RegisterMemoDropTarget;
begin
  if FDropTargetRegistered then
    Exit;

  Memo1.HandleNeeded;
  DropTarget := TMemoDropTarget.Create(Self);
  OleCheck(RegisterDragDrop(Memo1.Handle, DropTarget as IDropTarget));
  FDropTargetRegistered := True;
end;

procedure TForm1.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  // Tool window: hide from taskbar; stay in tray-centric workflow.
  Params.ExStyle := Params.ExStyle or WS_EX_TOOLWINDOW or WS_EX_ACCEPTFILES;
  Params.ExStyle := Params.ExStyle and not WS_EX_APPWINDOW;
end;


procedure TForm1.WMSystemCommand(var Msg: TWMSysCommand);
begin
  // Alt+Space system menu route shows pin popup instead of default close menu.
  if (Msg.CmdType and $FFF0) = SC_MOUSEMENU then
  begin
    PinMenu.Popup(Mouse.CursorPos.X, Mouse.CursorPos.Y);
    Exit;
  end;
  inherited;
end;


procedure TForm1.WMWindowPosChanging(var Message: TWMWindowPosChanging);
begin
  inherited;
  // Embed mode: keep window behind normal apps without stealing activation.
  if Assigned(miEmbed) and not (csDestroying in ComponentState) then
  begin
    if miEmbed.Checked then
    begin
      Message.WindowPos^.hwndInsertAfter := HWND_BOTTOM;
      Message.WindowPos^.flags := Message.WindowPos^.flags or SWP_NOACTIVATE;
    end;
  end;
end;


procedure TForm1.LoadSettings;
var
  Ini: TIniFile;
  IniPath: string;
  PinMode: string;
begin
  // Per-user INI: Window bounds, Settings prefs, Font memo typography.
  IniPath := TPath.Combine(TPath.GetDocumentsPath, 'micronote.ini');
  Ini := TIniFile.Create(IniPath);
  try
    { Window Position }
    Self.Left := Ini.ReadInteger('Window', 'Left', (Screen.Width div 2) - (Width div 2));
    Self.Top := Ini.ReadInteger('Window', 'Top', (Screen.Height div 2) - (Height div 2));
    Self.Width := Ini.ReadInteger('Window', 'Width', 295);
    Self.Height := Ini.ReadInteger('Window', 'Height', 361);

    { Sanity Check: Ensure window is on screen }
    if Self.Left < 0 then Self.Left := 0;
    if Self.Top < 0 then Self.Top := 0;

    { Settings: AutoTrim, PinMode (embed|float|free), DarkMode, Opacity, Hotkey VK }
    Memo1.Font.Name := Ini.ReadString('Font', 'Name', Memo1.Font.Name);
    Memo1.Font.Size := Ini.ReadInteger('Font', 'Size', Memo1.Font.Size);
    Memo1.Font.Color := Ini.ReadInteger('Font', 'Color', Memo1.Font.Color);
    miTrimOn.Checked := Ini.ReadBool('Settings', 'AutoTrim', False);
    miTrimOff.Checked := not miTrimOn.Checked;

    PinMode := LowerCase(Trim(Ini.ReadString('Settings', 'PinMode', 'free')));
    if PinMode = 'embed' then
      miEmbedClick(nil)
    else if PinMode = 'float' then
      miFloatClick(nil)
    else
      miFreeClick(nil);

    { Style: applies VCL theme + titlebar icon via miDark/miLight handlers }
    if Ini.ReadBool('Settings', 'DarkMode', True) then
      miDarkClick(nil)
    else
      miLightClick(nil);

    { Opacity }
    AlphaBlendValue := Ini.ReadInteger('Settings', 'Opacity', 255);
    mi25.Checked := (AlphaBlendValue = 84);
    mi50.Checked := (AlphaBlendValue = 168);
    mi100.Checked := (AlphaBlendValue = 255);

    { Hotkey }
    FHotkey := Ini.ReadInteger('Settings', 'Hotkey', VK_SCROLL);
  finally
    Ini.Free;
  end;
end;


procedure TForm1.SaveSettings;
var
  Ini: TIniFile;
  IniPath: string;
begin
  // Called on exit and after menu changes so kills do not lose recent settings.
  IniPath := TPath.Combine(TPath.GetDocumentsPath, 'micronote.ini');
  Ini := TIniFile.Create(IniPath);
  try
    { Window }
    Ini.WriteInteger('Window', 'Left', Self.Left);
    Ini.WriteInteger('Window', 'Top', Self.Top);
    Ini.WriteInteger('Window', 'Width', Self.Width);
    Ini.WriteInteger('Window', 'Height', Self.Height);

    { Settings + Font }
    Ini.WriteBool('Settings', 'AutoTrim', miTrimOn.Checked);
    if miEmbed.Checked then
      Ini.WriteString('Settings', 'PinMode', 'embed')
    else if miFloat.Checked then
      Ini.WriteString('Settings', 'PinMode', 'float')
    else
      Ini.WriteString('Settings', 'PinMode', 'free');
    Ini.WriteBool('Settings', 'DarkMode', miDark.Checked);
    Ini.WriteInteger('Settings', 'Opacity', AlphaBlendValue);
    Ini.WriteInteger('Settings', 'Hotkey', FHotkey);
    Ini.WriteString('Font', 'Name', Memo1.Font.Name);
    Ini.WriteInteger('Font', 'Size', Memo1.Font.Size);
    Ini.WriteInteger('Font', 'Color', Memo1.Font.Color);
  finally
    Ini.Free;
  end;
end;


procedure TForm1.FormCreate(Sender: TObject);
var
  LoadPath: string;
begin
  Constraints.MinWidth := 250;
  Constraints.MinHeight := 150;

  // Body autosave file (separate from micronote.ini settings).
  LoadPath := TPath.Combine(TPath.GetDocumentsPath, 'micronote.txt');
  if FileExists(LoadPath) then
  begin
    Memo1.Lines.LoadFromFile(LoadPath);
    CleanWhitespace;
  end;

  Memo1.ScrollBars := ssNone;
  ShowScrollBar(Memo1.Handle, SB_VERT, False); // wheel scrolling via FormMouseWheel

  Dirty := False;
  TrayIcon1.Visible := True;
  UpdateCounts;
  miTrimOn.Checked := False;
  miTrimOff.Checked := True;
  AlphaBlend := True;
  Timer1.Interval := 5000;

  FHotkey := VK_SCROLL;
  LoadSettings;
  RegisterHotKey(Handle, MY_HOTKEY_ID, 0, FHotkey);

  miHKScroll.Checked := (FHotkey = VK_SCROLL);
  miHKPause.Checked := (FHotkey = VK_PAUSE);
  miHKInsert.Checked := (FHotkey = VK_INSERT);

  StatusBar1.Panels[1].Text := 'ready...';
end;


procedure TForm1.FormDestroy(Sender: TObject);
begin
  if FDropTargetRegistered and Memo1.HandleAllocated then
    RevokeDragDrop(Memo1.Handle);
  DropTarget := nil;
  FDropTargetRegistered := False;
  SaveSettings;
  UnregisterHotKey(Handle, MY_HOTKEY_ID);
end;


procedure TForm1.WMHotkey(var Msg: TWMHotKey);
begin
  if Msg.HotKey = MY_HOTKEY_ID then
  begin
    // Global hotkey toggles visibility; app stays resident in tray when hidden.
    if Visible and (WindowState <> wsMinimized) then Hide
    else
    begin
      WindowState := wsNormal;
      Show;
      Winapi.Windows.SetForegroundWindow(Handle);
    end;
  end;
end;


procedure TForm1.FormMouseWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
begin
  if WheelDelta > 0 then
    SendMessage(Memo1.Handle, WM_VSCROLL, SB_LINEUP, 0)
  else
    SendMessage(Memo1.Handle, WM_VSCROLL, SB_LINEDOWN, 0);
  Handled := True;
end;


procedure TForm1.StatusBar1MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  GearStart, GearEnd: Integer;
begin
  // Panel 2 is the gear; hit-test uses live widths from FormResize.
  GearStart := StatusBar1.Panels[0].Width + StatusBar1.Panels[1].Width;
  GearEnd := GearStart + StatusBar1.Panels[2].Width;

  if (X >= GearStart) and (X <= GearEnd) then
    SettingsPopup.Popup(Mouse.CursorPos.X, Mouse.CursorPos.Y);
end;


procedure TForm1.miOpacityClick(Sender: TObject);
begin
  if (Sender = miOpacity) then Exit;

  mi25.Checked := False;
  mi50.Checked := False;
  mi100.Checked := False;

  if Sender is TMenuItem then
    TMenuItem(Sender).Checked := True;

  if mi25.Checked then AlphaBlendValue := 84;
  if mi50.Checked then AlphaBlendValue := 168;
  if mi100.Checked then AlphaBlendValue := 255;

  Self.Repaint;
  StatusBar1.Panels[1].Text := 'opacity updated...';
  SaveSettings; // persist immediately after user menu choice
end;


procedure TForm1.miTrimOnClick(Sender: TObject);
begin
  miTrimOn.Checked := True;
  miTrimOff.Checked := False;
  CleanWhitespace;
  StatusBar1.Panels[1].Text := 'autotrim on...';
  SaveSettings; // persist immediately after user menu choice
end;


procedure TForm1.miTrimOffClick(Sender: TObject);
begin
  miTrimOn.Checked := False;
  miTrimOff.Checked := True;
  StatusBar1.Panels[1].Text := 'autotrim off...';
  SaveSettings; // persist immediately after user menu choice
end;


// Re-sync radio dots when submenu opens (VCL may reset Checked from DFM defaults).
procedure TForm1.miHotkeyPopup(Sender: TObject);
begin
  miHKScroll.Checked := (FHotkey = VK_SCROLL);
  miHKPause.Checked := (FHotkey = VK_PAUSE);
  miHKInsert.Checked := (FHotkey = VK_INSERT);
end;


procedure TForm1.miHKClick(Sender: TObject);
begin
  if Sender = miHKScroll then
    FHotkey := VK_SCROLL
  else if Sender = miHKPause then
    FHotkey := VK_PAUSE
  else if Sender = miHKInsert then
    FHotkey := VK_INSERT;

  // Windows requires unregister before changing the registered VK for this HWND/id.
  UnregisterHotKey(Handle, MY_HOTKEY_ID);
  RegisterHotKey(Handle, MY_HOTKEY_ID, 0, FHotkey);

  miHotkeyPopup(nil);

  StatusBar1.Panels[1].Text := 'hotkey updated...';
  SaveSettings; // persist immediately after user menu choice
end;


procedure TForm1.miDarkClick(Sender: TObject);
var
  hNewIcon: HICON;
begin
  if TStyleManager.TrySetStyle('Windows11 Modern Dark') then
  begin
    miDark.Checked := True;
    miLight.Checked := False;

    // Light glyph on dark chrome (resource Icon_White).
    hNewIcon := LoadIcon(HInstance, 'Icon_White');
    if hNewIcon <> 0 then
    begin
      if Self.Icon.Handle <> 0 then
        DestroyIcon(Self.Icon.Handle);
      // Refresh both titlebar icon slots; TForm.Icon alone is not always enough.
      SendMessage(Handle, WM_SETICON, ICON_SMALL, hNewIcon);
      SendMessage(Handle, WM_SETICON, ICON_BIG, hNewIcon);
      Self.Icon.Handle := hNewIcon;
    end;

    // Force non-client area redraw after icon/style change.
    SetWindowPos(Handle, 0, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOZORDER or SWP_FRAMECHANGED);
    StatusBar1.Panels[1].Text := 'dark...';
    SaveSettings; // persist immediately after user menu choice
  end;
end;


procedure TForm1.miLightClick(Sender: TObject);
var
  hNewIcon: HICON;
begin
  if TStyleManager.TrySetStyle('Windows11 White Smoke') then
  begin
    miLight.Checked := True;
    miDark.Checked := False;

    // Dark glyph on light chrome (resource Icon_Dark).
    hNewIcon := LoadIcon(HInstance, 'Icon_Dark');
    if hNewIcon <> 0 then
    begin
      if Self.Icon.Handle <> 0 then
        DestroyIcon(Self.Icon.Handle);
      SendMessage(Handle, WM_SETICON, ICON_SMALL, hNewIcon);
      SendMessage(Handle, WM_SETICON, ICON_BIG, hNewIcon);
      Self.Icon.Handle := hNewIcon;
    end;

    SetWindowPos(Handle, 0, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOZORDER or SWP_FRAMECHANGED);
    StatusBar1.Panels[1].Text := 'light...';
    SaveSettings; // persist immediately after user menu choice
  end;
end;


procedure TForm1.miAboutClick(Sender: TObject);
var
  A: TfrmAbout;
begin
  // Modeless About; form frees itself on close (caFree) — no owner-held reference.
  A := TfrmAbout.Create(Self);
  A.Show;
end;


procedure TForm1.WMNCLButtonDown(var Msg: TWMNCLButtonDown);
begin
  // Replace system menu / left caption zone with pin-mode popup (embed/float/free).
  if (Msg.HitTest = HTSYSMENU) or
      ((Msg.HitTest = HTCAPTION) and (Msg.XCursor <= (Self.Left + 30))) then
  begin
    PinMenu.Popup(Mouse.CursorPos.X, Mouse.CursorPos.Y);
    Msg.Result := 0;
    Exit;
  end;
  inherited;
end;


procedure TForm1.miEmbedClick(Sender: TObject);
begin
  miEmbed.Checked := True;
  miFloat.Checked := False;
  miFree.Checked := False;
  FormStyle := fsNormal;
  // One-shot z-order; ongoing embed stacking handled in WM_WINDOWPOSCHANGING.
  SetWindowPos(Handle, HWND_BOTTOM, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);
  StatusBar1.Panels[1].Text := 'embedded...';
  SaveSettings; // persist immediately after user menu choice
end;


procedure TForm1.miFloatClick(Sender: TObject);
begin
  miEmbed.Checked := False;
  miFloat.Checked := True;
  miFree.Checked := False;
  // VCL stay-on-top keeps scratchpad above normal windows.
  FormStyle := fsStayOnTop;
  StatusBar1.Panels[1].Text := 'floating...';
  SaveSettings; // persist immediately after user menu choice
end;


procedure TForm1.miFreeClick(Sender: TObject);
begin
  miEmbed.Checked := False;
  miFloat.Checked := False;
  miFree.Checked := True;
  FormStyle := fsNormal;
  // Clear topmost/bottom pinning from other modes.
  SetWindowPos(Handle, HWND_NOTOPMOST, 0, 0, 0, 0,
    SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);
  StatusBar1.Panels[1].Text := 'free...';
  SaveSettings; // persist immediately after user menu choice
end;


procedure TForm1.FormActivate(Sender: TObject);
begin
  RegisterMemoDropTarget;
end;


procedure TForm1.WMUser1(var Msg: TMessage);
begin
  Hide;
end;


procedure TForm1.miFontClick(Sender: TObject);
begin
  FontDialog1.Font := Memo1.Font;
  if FontDialog1.Execute then
  begin
    Memo1.Font := FontDialog1.Font;
    SaveSettings;
  end;
end;


procedure TForm1.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  // Close box hides to tray; use Exit menu item to terminate.
  CanClose := False;
  Hide;
end;


procedure TForm1.TrayIcon1DblClick(Sender: TObject);
begin
  WindowState := wsNormal;
  Show;
  RegisterMemoDropTarget;
  Application.BringToFront;
end;


procedure TForm1.TrayIcon1MouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then
  begin
    WindowState := wsNormal;
    Show;
    RegisterMemoDropTarget;
    Application.BringToFront;
  end;
end;


procedure TForm1.Show1Click(Sender: TObject);
begin
  WindowState := wsNormal;
  Show;
  RegisterMemoDropTarget;
  Application.BringToFront;
end;


procedure TForm1.Copy1Click(Sender: TObject); begin Memo1.CopyToClipboard; end;
procedure TForm1.Cut1Click(Sender: TObject); begin Memo1.CutToClipboard; end;
procedure TForm1.delete1Click(Sender: TObject); begin Memo1.ClearSelection; end;
procedure TForm1.selectall1Click(Sender: TObject); begin Memo1.SelectAll; end;


procedure TForm1.paste1Click(Sender: TObject);
var
  CurrSel: Integer;
begin
  CurrSel := Memo1.SelStart;
  Memo1.PasteFromClipboard;
  CleanWhitespace;
  Memo1.SelStart := CurrSel;
  UpdateCounts;
  Dirty := True;
end;


procedure TForm1.Exit1Click(Sender: TObject);
begin
  TrayIcon1.Visible := False;
  Application.Terminate;
end;


procedure TForm1.UpdateCounts;
begin
  StatusBar1.Panels[0].Text :=
    Format('words: %d / lines: %d', [WordCount(Memo1.Text), Memo1.Lines.Count]);
end;


procedure TForm1.Memo1Change(Sender: TObject);
begin
  Dirty := True; // Timer1 writes micronote.txt only while Dirty is set
  UpdateCounts;
  StatusBar1.Panels[1].Text := 'modified...';
end;


// Hover-aware opacity: full alpha over form, dimmed per menu when pointer leaves.
procedure TForm1.Timer2Timer(Sender: TObject);
begin
  // BoundsRect is screen coords: restore full opacity while cursor over the form.
  if PtInRect(BoundsRect, Mouse.CursorPos) then
  begin
    if AlphaBlendValue <> 255 then
    begin
      AlphaBlendValue := 255;
      Memo1.Font.Color := StyleServices.GetStyleFontColor(sfEditBoxTextNormal);
    end;
  end
  else
  begin
    if not mi100.Checked then
    begin
      if mi25.Checked then
        AlphaBlendValue := 84
      else if mi50.Checked then
        AlphaBlendValue := 168
      else
        AlphaBlendValue := 180;

      // Muted gray when dimmed so text remains readable at low alpha.
      Memo1.Font.Color := $AAAAAA;
    end
    else
      AlphaBlendValue := 255;
  end;
end;


// Periodic autosave to Documents\micronote.txt (interval set in FormCreate).
procedure TForm1.Timer1Timer(Sender: TObject);
var
  SavePath: string;
  CurrSel: Integer;
begin
  if Dirty then
  begin
    if miTrimOn.Checked then
    begin
      // Autotrim mutates lines; save caret so typing position does not jump.
      CurrSel := Memo1.SelStart;
      CleanWhitespace;
      Memo1.SelStart := CurrSel;
    end;

    SavePath := TPath.Combine(TPath.GetDocumentsPath, 'micronote.txt');
    try
      Memo1.Lines.SaveToFile(SavePath);
      Dirty := False;
      StatusBar1.Panels[1].Text := 'saved...';
    except
      on E: Exception do
        StatusBar1.Panels[1].Text := 'save failed';
    end;
  end;
end;


procedure TForm1.FormMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  ScreenSnap := False;
end;


procedure TForm1.FormMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  ScreenSnap := True;
end;


procedure TForm1.FormResize(Sender: TObject);
var
  AvailableWidth: Integer;
  S: string;
  P: Integer;
begin
  if (StatusBar1 <> nil) and (StatusBar1.Panels.Count >= 4) then
  begin
    // Fixed gear + spacer; split remainder ~65% counts / ~35% status message.
    StatusBar1.Panels[2].Width := 50;
    StatusBar1.Panels[3].Width := 20;
    AvailableWidth := ClientWidth - (StatusBar1.Panels[2].Width + StatusBar1.Panels[3].Width);
    StatusBar1.Panels[0].Width := Round(AvailableWidth * 0.65);
    StatusBar1.Panels[1].Width := AvailableWidth - StatusBar1.Panels[0].Width;
    StatusBar1.Panels[2].Text := '⚙';
    StatusBar1.Panels[2].Alignment := taCenter;
  end;

  // Force memo relayout on resize while preserving caret (Fira Code metric quirk).
  P := Memo1.SelStart;
  S := Memo1.Text;
  Memo1.Text := S;
  Memo1.SelStart := P;
end;


function TForm1.WordCount(const S: string): Integer;
var
  Parts: TArray<string>;
begin
  Parts := S.Split([' ', #9, #13, #10], TStringSplitOptions.ExcludeEmpty);
  Result := Length(Parts);
end;


procedure TForm1.TrimTrailingSpaces;
var
  i: Integer;
  TempList: TStringList;
begin
  TempList := TStringList.Create;
  try
    TempList.Assign(Memo1.Lines);
    for i := 0 to TempList.Count - 1 do
      TempList[i] := TrimRight(TempList[i]); // strip trailing spaces per line only
    // Drop trailing empty lines so the file does not grow unbounded blank rows.
    while (TempList.Count > 1) and (TempList[TempList.Count - 1] = '') do
      TempList.Delete(TempList.Count - 1);
    Memo1.Lines.Assign(TempList);
  finally
    TempList.Free;
  end;
end;


procedure TForm1.CleanWhitespace;
begin
  // Normalize tabs to spaces for predictable plain-text saves.
  Memo1.Text := StringReplace(Memo1.Text, #9, ' ', [rfReplaceAll]);
  TrimTrailingSpaces;
end;


end.


