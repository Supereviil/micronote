// Entry: singleton mutex, default dark VCL style, creates main scratchpad form.
program micronote;



{$R *.dres}



uses

  Vcl.Forms,

  Windows,

  Unit1 in 'Unit1.pas' {Form1},

  Vcl.Themes,

  Vcl.Styles,

  About in 'About.pas' {frmAbout};



{$R *.res}



var

  MutexHandle: THandle;



begin

  // Second instance exits early so tray/hotkey state stays single-process.
  MutexHandle := CreateMutex(nil, True, 'MicronoteSingletonMutex');

  if (MutexHandle <> 0) and (GetLastError = ERROR_ALREADY_EXISTS) then

  begin

    MessageBox(0, 'Micronote is already running.', 'Micronote', MB_ICONINFORMATION or MB_OK);

    Halt;

  end;



  Application.Initialize;

  Application.MainFormOnTaskbar := True;

  TStyleManager.TrySetStyle('Windows11 Modern Dark');

  Application.CreateForm(TForm1, Form1);

  Application.Run;

end.


