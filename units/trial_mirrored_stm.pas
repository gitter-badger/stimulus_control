{
  Stimulus Control
  Copyright (C) 2014-2016 Carlos Rafael Fernandes Picanço, Universidade Federal do Pará.

  The present file is distributed under the terms of the GNU General Public License (GPL v3.0).

  You should have received a copy of the GNU General Public License
  along with this program. If not, see <http://www.gnu.org/licenses/>.
}
unit trial_mirrored_stm;

{$mode objfpc}{$H+}

interface

uses LCLIntf, LCLType, Controls, Classes, SysUtils

    , config_session
    , trial_abstract
    , constants
    , draw_methods
    , schedules_main
    , response_key
    ;

type

  { TMRD }
  TDataSupport = record
    Responses : integer;
    Latency,
    StmBegin,
    StmEnd : Extended;
  end;

  TMRD = Class(TTrial)
  private
    FDataSupport : TDataSupport;
    FCircles: TCurrentTrial;
    FSchedule : TSchMan;
    FKey1 : TKey;
    FKey2 : TKey;
    FFirstResp : Boolean;
    FUseMedia : Boolean;
    FShowStarter : Boolean;
    FCanResponse : Boolean;
    procedure BeginCorrection (Sender : TObject);
    procedure BeginStarter;
    procedure Consequence(Sender: TObject);
    procedure EndCorrection (Sender : TObject);
    procedure Hit(Sender: TObject);
    procedure Miss(Sender: TObject);
    procedure None(Sender: TObject);
    procedure Response(Sender: TObject);
    procedure TrialResult(Sender : TObject);
  protected
    procedure BeforeEndTrial(Sender: TObject); override;
    procedure StartTrial(Sender: TObject); override;
    procedure WriteData(Sender: TObject); override;
    procedure TrialKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure TrialKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Play(TestMode: Boolean; Correction : Boolean); override;
    //procedure DispenserPlusCall; override;

  end;

implementation

uses
  timestamp
{$ifdef DEBUG}
  , debug_logger
  , dialogs
{$endif}
  ;

constructor TMRD.Create(AOwner: TComponent);
begin
  OnBeforeEndTrial := @BeforeEndTrial;
  OnKeyDown := @TrialKeyDown;
  OnKeyUp := @TrialKeyUp;

  inherited Create(AOwner);
  Header :=  'StmBegin' + #9 +
             '_Latency' + #9 +
             '__StmEnd' + #9 +
             '___Angle' + #9 +
             '______X1' + #9 +
             '______Y1' + #9 +
             '______X2' + #9 +
             '______Y2' + #9 +
             'ExpcResp' + #9 +
             'RespFreq'
             ;
  FDataSupport.Responses:= 0;
end;

procedure TMRD.Consequence(Sender: TObject);
begin
  LogEvent('C');
  if Assigned(CounterManager.OnConsequence) then CounterManager.OnConsequence(Self);

  TrialResult(Sender);
end;

procedure TMRD.TrialResult(Sender: TObject);
begin
  Result := 'HIT';
  IETConsequence := T_NONE;

  if FCircles.NextTrial = T_CRT then NextTrial := T_CRT
  else NextTrial := FCircles.NextTrial;

  if FLimitedHold = 0 then EndTrial(Sender);
end;


procedure TMRD.TrialKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = 27 {ESC}) and (FCanResponse = True) then
    begin
      FCanResponse:= False;
      Invalidate;
    end;

  if ssCtrl in Shift then
     begin
       if Key = 81 {q} then
         begin
           Data := Data + #13#10 + '(Sessão cancelada)' + #9#9#9#9#9#9#9#9#9 + #13#10;
           Result := 'NONE';
           IETConsequence := 'NONE';
           NextTrial := 'END';
           None(Self);
           EndTrial(Self);
         end;
     end;
end;

procedure TMRD.TrialKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
var TickCount : Extended;
begin
  TickCount := GetCustomTick;

  if Key = 27 {ESC} then
    begin
      FCanResponse:= True;
      Invalidate;
    end;

  if FCanResponse then
    begin
      if FShowStarter then
        begin
          if key = 32 then
            begin
              //FSchedule.DoResponse; need to fix that, this line does not apply when no TResponseKey is used
              FDataSupport.Latency := TickCount;
              LogEvent('*R');
              FShowStarter := False;
              Invalidate;
              StartTrial(Self);
            end;
        end
      else LogEvent('R');
    end;
end;


procedure TMRD.Paint;
var i : integer;
begin
  inherited Paint;

  if FCanResponse then
    begin
      if FShowStarter then DrawCenteredCircle(Canvas, Width, Height, 6)
      else
        if FUseMedia then
          //do nothing, TKey draws itself

        else
          for i := 0 to 1 do
            with FCircles.C[i] do DrawCircle(Canvas, o.X, o.Y, size, gap, gap_degree, gap_length);
    end;
end;

procedure TMRD.Play(TestMode: Boolean; Correction : Boolean);
var
  s1, sName, sLoop, sColor{, sGap, sGapDegree, sGapLength} : string;
  R : TRect;
  a1 : Integer;

  procedure NextSpaceDelimitedParameter;
  begin
    Delete(s1, 1, pos(#32, s1));
    if Length(s1) > 0 then while s1[1] = #32 do Delete(s1, 1, 1);
  end;

  procedure KeyConfig(var aKey : TKey);
  begin
    with aKey do
      begin
        BoundsRect := R;
        Color := StrToIntDef(sColor, $0000FF); // clRed
        HowManyLoops := StrToIntDef(sLoop, 0);
        FullPath := sName;
        Schedule.Kind := CfgTrial.SList.Values[_Schedule];
        // Visible := False;
      end;
  end;

begin
  FCanResponse := False;
  NextTrial := '-1';
  Randomize;

  FUseMedia := StrToBoolDef(CfgTrial.SList.Values[_UseMedia], False);
  FShowStarter := StrToBoolDef(CfgTrial.SList.Values[_ShowStarter], False);
  FLimitedHold := StrToIntDef(CfgTrial.SList.Values[_LimitedHold], 0);

  if FUseMedia then
    RootMedia := CfgTrial.SList.Values[_RootMedia]
  else
    begin
      SetLength(FCircles.C, 2);
    end;

  if Correction then FIsCorrection := True
  else FIsCorrection := False;

  //self descends from TCustomControl
  Color := StrToIntDef(CfgTrial.SList.Values[_BkGnd], 0);
  if TestMode then Cursor:= 0
  else Cursor := StrToIntDef(CfgTrial.SList.Values[_Cursor], 0);

  FSchedule := TSchMan.Create(self);
  with FSchedule do
    begin
      OnConsequence := @Consequence;
      OnResponse:= @Response;
      Kind := CfgTrial.SList.Values[_Schedule];
      if Loaded then
        begin
          SetLength(FClockList, Length(FClockList) +1);
          FClockList[Length(FClockList) -1] := StartMethod;
        end
      else raise Exception.Create(ExceptionNoScheduleFound);
    end;

  FCircles.angle := StrToFloatDef(CfgTrial.SList.Values[_Angle], 0.0);
  FCircles.response := CfgTrial.SList.Values[_Comp + '1' + _cGap];
  FCircles.NextTrial := CfgTrial.SList.Values[_NextTrial];

  for a1 := 0 to 1 do
    begin
        s1:= CfgTrial.SList.Values[_Comp + IntToStr(a1+1) + _cBnd];

        R.Left:= StrToIntDef(Copy(s1, 0, pos(#32, s1)-1), 0);
        NextSpaceDelimitedParameter;

        R.Top:= StrToIntDef(Copy(s1, 0, pos(#32, s1)-1), 0);
        NextSpaceDelimitedParameter;

        R.Right := StrToIntDef(s1, 100);
        R.Bottom := R.Right;

       if FUseMedia then
         begin
           s1:= CfgTrial.SList.Values[_Comp + IntToStr(a1+1)+_cStm] + #32;

           sName := RootMedia + Copy(s1, 0, pos(#32, s1)-1);
           NextSpaceDelimitedParameter;

           sLoop := Copy(s1, 0, pos(#32, s1)-1);
           NextSpaceDelimitedParameter;

           sColor := s1;

           if a1 = 0 then KeyConfig(FKey1) else KeyConfig(FKey2)

         end
       else
          with FCircles.C[a1] do
            begin
              o := Point(R.Left, R.Top);
              size := R.Right;
              gap := StrToBoolDef( CfgTrial.SList.Values[_Comp + IntToStr(a1+1) + _cGap], False );
              if gap then
                  begin
                    gap_degree := StrToIntDef( CfgTrial.SList.Values[_Comp + IntToStr(a1+1) + _cGap_Degree], Round(Random(360)));
                    gap_length := StrToIntDef( CfgTrial.SList.Values[_Comp + IntToStr(a1+1) + _cGap_Length], 5 );
                  end;
            end;
      end;

  {$ifdef DEBUG}
  DebugLn(mt_Information + 'Starter:' + BoolToStr(FShowStarter, 'True', 'False'));
  {$endif}

  if FShowStarter then BeginStarter else StartTrial(Self);
end;

//procedure TMRD.DispenserPlusCall;
//begin
//  // dispensers were not implemented yet
//end;

procedure TMRD.StartTrial(Sender: TObject);

  procedure KeyStart(var aKey : TKey);
  begin
    aKey.Play;
    aKey.Visible:= True;
  end;

begin
  if FIsCorrection then
    begin
      BeginCorrection (Self);
    end;
  {
  if FUseMedia then
    begin
      KeyStart(FKey1);
      KeyStart(FKey2);
    end;
  }
  FFirstResp := True;

  FCanResponse := True;
  Invalidate;
  FDataSupport.StmBegin := GetCustomTick;

  inherited StartTrial(Sender);
end;

procedure TMRD.BeginStarter;
begin
  LogEvent('S');
  FCanResponse:= True;
  Invalidate;
end;

procedure TMRD.WriteData(Sender: TObject);  //
begin

  {
  Header :=  'StmBegin' + #9 +
             '_Latency' + #9 +
             '__StmEnd' + #9 +
             '___Angle' + #9 +
             '______X1' + #9 +
             '______Y1' + #9 +
             '______X2' + #9 +
             '______Y2' + #9 +
             'ExpcResp' + #9 +
             'RespFreq'
             ;
  }
  Data := //Format('%-*.*d', [4,8,CfgTrial.Id + 1]) + #9 +
           FloatToStrF(FDataSupport.StmBegin - TimeStart,ffFixed,0,9) + #9 +
           FloatToStrF(FDataSupport.Latency - TimeStart,ffFixed,0,9) + #9 +
           FloatToStrF(FDataSupport.StmEnd - TimeStart,ffFixed,0,9) + #9 +
           #32#32#32#32#32 + FormatFloat('000;;00', FCircles.angle) + #9 +
           Format('%-*.*d', [4,8,FCircles.C[0].o.X]) + #9 +
           Format('%-*.*d', [4,8,FCircles.C[0].o.Y]) + #9 +
           Format('%-*.*d', [4,8,FCircles.C[1].o.X]) + #9 +
           Format('%-*.*d', [4,8,FCircles.C[1].o.Y]) + #9 +
           #32#32#32#32#32#32#32 + FCircles.response + #9 +
           Format('%-*.*d', [4,8,FDataSupport.Responses])
           //FormatFloat('00000000;;00000000',FData.LatencyStmResponse) + #9 +
           //FormatFloat('00000000;;00000000',FData.ITIBEGIN) + #9 +
           //FormatFloat('00000000;;00000000',FData.ITIEND) + #9 +
           //'' + #9 +
           + Data;
end;

procedure TMRD.BeforeEndTrial(Sender: TObject);
begin
  FCanResponse := False;
  FDataSupport.StmEnd := GetTickCount64;
  FCircles.Result := Result;

  if Result = T_HIT then Hit(Sender);
  //if Result = 'MISS' then  Miss(Sender);
  //if Result = 'NONE' then  None(Sender);

  WriteData(Sender);

  if Assigned(OnWriteTrialData) then OnWriteTrialData(Self);
end;


procedure TMRD.Response(Sender: TObject);
var TickCount : Extended;
begin
  TickCount := GetCustomTick;
  Inc(FDataSupport.Responses);

  if FFirstResp then
    begin
      FFirstResp := False;
      FDataSupport.Latency := TickCount;
    end;

  if FUseMedia then
    if Sender is TKey then TKey(Sender).IncResponseCount;

  //Invalidate;
  if Assigned(CounterManager.OnStmResponse) then CounterManager.OnStmResponse (Sender);
  if Assigned(OnStmResponse) then OnStmResponse (Self);
end;

procedure TMRD.Hit(Sender: TObject);
begin
  if Assigned(OnHit) then OnHit(Sender);
end;

procedure TMRD.Miss(Sender: TObject);
begin
  if Assigned(OnMiss) then OnMiss (Sender);
end;

procedure TMRD.None(Sender: TObject);
begin
  if Assigned(OnNone) then OnNone (Sender);
end;

procedure TMRD.BeginCorrection(Sender: TObject);
begin
  if Assigned(OnBeginCorrection) then OnBeginCorrection (Sender);
end;

procedure TMRD.EndCorrection(Sender: TObject);
begin
  if Assigned(OnEndCorrection) then OnEndCorrection (Sender);
end;

end.
