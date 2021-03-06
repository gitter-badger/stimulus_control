{
  Stimulus Control
  Copyright (C) 2014-2016 Carlos Rafael Fernandes Picanço, Universidade Federal do Pará.

  The present file is distributed under the terms of the GNU General Public License (GPL v3.0).

  You should have received a copy of the GNU General Public License
  along with this program. If not, see <http://www.gnu.org/licenses/>.
}
unit trial_mirrored_config;

{$mode objfpc}{$H+}

interface

uses Classes, SysUtils, Forms, Math
    //, Dialogs
    ;

type


  TCircle = record
    o : TPoint;  //Left/Top
    size : integer;
    gap : Boolean;
    gap_degree : integer;
    gap_length : integer;
  end;

  TCurrentTrial = record
    C : array of TCircle; //circles
    i : integer; //trial index
    NextTrial : string;
    angle : float; // angle from "userconfigs_trial_mirrored" form,
    response : string;

  end;

  TAxis = record
    Rect : TRect;
    Trial : array of TPoint;
    axis : array of String;
  end;

  //horizontal and vertical distances
  TDistances = array of array of integer;

  { TConfig }

  TConfig = class (TComponent)
    private
      FCT : TCurrentTrial;         //Current Trial
      Fx : TAxis;
      function MirroredDistanceOf(Distance : integer; primary_axis : string): integer;
      function SetAxis(step, Circles_Size: integer): TDistances;
      procedure SetCircles(aSize : integer;
        aGap_degree : integer = 360; aGap_length: integer = 1; aGap: Boolean = False);
      procedure SetCurrentTrialTo(index : integer);
      procedure TrialOrdering(D : TDistances);
      procedure CenterRect(var Rect : TRect);
    public
      constructor Create(AOwner: TComponent; Step, Circles_Size : integer; VisibleRect : TRect); reintroduce;
      function NextTrial: Boolean;
      property CT : TCurrentTrial read FCT;
      property X : TAxis read Fx;
  end;

const
  horizontal = 0;
  vertical = 1;
resourcestring
  rLeft = 'Esquerda';
  rRight = 'Direita';
  rTop = 'Cima';
  rBottom = 'Baixo';

implementation

{ TConfig }

function TConfig.MirroredDistanceOf(Distance: integer; primary_axis: string
  ): integer;
var HalfScreenWidth, HalfScreenHeight: integer;
begin
  HalfScreenWidth := Round(Screen.Width/2);
  if primary_axis = 'h' then
    begin
      if Distance = HalfScreenWidth then
        begin
          Result := Distance;
          Exit;
        end;

      if Distance < HalfScreenWidth then
        Result := ABS(Distance - HalfScreenWidth) + HalfScreenWidth
      else Result := ABS(ABS(Distance - HalfScreenWidth) - HalfScreenWidth)
    end;

  HalfScreenHeight := Round(Screen.Height/2);
  if primary_axis = 'v' then
    begin
      if Distance = HalfScreenHeight then
        begin
          Result := Distance;
          Exit;
        end;

      if Distance < HalfScreenHeight then
        Result := ABS(Distance - HalfScreenHeight) + HalfScreenHeight
      else Result := ABS(ABS(Distance - HalfScreenHeight) - HalfScreenHeight)
    end;
end;

function TConfig.SetAxis(step, Circles_Size: integer): TDistances;
var
  i, VisibleHeight, VisibleWidth : integer;
begin
  //VisibleHeight := Screen.Height - Circles_Size;
  //VisibleWidth := Screen.Width - Circles_Size;
  VisibleHeight := X.Rect.Bottom - X.Rect.Top - Circles_Size;
  VisibleWidth := X.Rect.Right - X.Rect.Left - Circles_Size;

  //set the number of axis on the first level of D array
  //0 - horizontal, 1 - vertical
  SetLength(Result, 2);

  //set the number of distances on each axis based on step number
  //lets divide for 2 since mirrored circles will be used
  SetLength(Result[horizontal], Round((VisibleWidth / 2) / step));
  SetLength(Result[vertical], Round((VisibleHeight / 2) / step));

  //set the horizontal initial distance
  Result[horizontal, 0] := X.Rect.Left;

  //set the horizontal incremented/steped distances
  for i := 1 to High(Result[horizontal]) do
    Result[horizontal, i] := Result[horizontal, i -1] + step;

  //set the vertical distances.
  Result[vertical, 0] := X.Rect.Top;
  for i := 1 to High(Result[vertical]) do
    Result[vertical, i] := Result[vertical, i -1] + step;
  //horizontal and vertical are primary distances
  //for now, diagonal 1 and 2 are derived from primary ones
end;

procedure TConfig.SetCircles(aSize : integer;
  aGap_degree : integer = 360; aGap_length: integer = 1; aGap: Boolean = False);
var
  k : integer;
begin
  with FCT do
     for k := 0 to 1 do
        with C[k] do
          begin
            size := aSize;
            gap := aGap;
            gap_degree := aGap_degree;
            gap_length := aGap_length;
          end;
end;

procedure TConfig.SetCurrentTrialTo(index: integer);
begin
  with FCT do
     begin
       //FX.o // ordering index
       i := index;

       //first circle parameters
       C[0].o := Fx.Trial[i];

       //mirrored circle parameter
       if Fx.axis[i] = 'h' then
         begin
           C[1].o.X := MirroredDistanceOf(C[0].o.X, Fx.axis[i]);
           C[1].o.Y := C[0].o.Y;
           if Round(Random) = 0 then response := rLeft else response := rRight;
         end;

       if Fx.axis[i] = 'v' then
         begin
           C[1].o.X := C[0].o.X;
           C[1].o.Y := MirroredDistanceOf(C[0].o.Y, Fx.axis[i]);
           if Round(Random) = 0 then response := rTop else response := rBottom;
         end;

       if (Fx.axis[i] = 'd1') or (Fx.axis[i] = 'd2') then
         begin
           C[1].o.X := MirroredDistanceOf(C[0].o.X, 'h');
           C[1].o.Y := MirroredDistanceOf(C[0].o.Y, 'v');
           if Round(Random) = 0 then response := rLeft else response := rRight;
         end;
       //ShowMessage('Trial ' + IntToStr(i) + 'o1=' + IntToStr(C[0].o.X) + ',' + IntToStr(C[0].o.Y));
       //ShowMessage('Trial ' + IntToStr(i) + 'o2=' + IntToStr(C[1].o.X) + ',' + IntToStr(C[1].o.Y));
     end;

end;

{TODO -oRafael -cTrialOrdering: Trial Order need to be presented to and if necessary modified by the user before running}

procedure TConfig.TrialOrdering(D: TDistances);
var k, i, j, Temp, Trials, HorizTrials, VertTrials, DiagTrials: integer; diagonal_step, inc_step : float;
begin
  HorizTrials := Length(D[horizontal]);
  VertTrials:= Length(D[vertical]);
  DiagTrials := Length(D[vertical]);   //if height < width
  Trials := HorizTrials + VertTrials + (DiagTrials * 2);

  //showmessage(inttostr(trials));
  SetLength(Fx.Trial, Trials);
  SetLength(Fx.axis, Trials);

  //horizontal trials
  for i := 0 to HorizTrials -1 do
    begin
     Fx.axis[i] := 'h';
     Fx.Trial[i].X := D[horizontal, i];
     Fx.Trial[i].Y := D[vertical, VertTrials -1];
     //showmessage(Fx.axis[i] + ' ' + inttostr(Fx.Trial[i].X) + ',' + inttostr(Fx.Trial[i].Y) + ' ' + inttostr(i));
    end;

  //vertical trials
  Trials := 0;
  for  i := 0 to VertTrials -1 do
    begin
     Trials := i + HorizTrials;
     Fx.axis[Trials] := 'v';
     Fx.Trial[Trials].X := D[horizontal, HorizTrials - 1];
     Fx.Trial[Trials].Y := D[vertical, i];
     //showmessage(Fx.axis[i + HorizTrials] + ' ' + inttostr(Fx.Trial[i + HorizTrials].X) + ',' + inttostr(Fx.Trial[i + HorizTrials].Y) + ' ' + inttostr(i + HorizTrials));
    end;

  //diagonal trials
  //if HorizTrials >= VertTrials then
  //  diagonal_step := HorizTrials div VertTrials
  //else if HorizTrials < VertTrials then
  diagonal_step :=  HorizTrials/VertTrials;
  //showmessage(inttr(diagonal_step) + ' ' + inttostr(VertTrials) + ' ' + inttostr(HorizTrials));
  //left/top
  i := 0;
  j := 0;
  inc_step := 0;
  Trials := 0;
  for  k := 0 to DiagTrials -1 do
    begin
     Trials := k + HorizTrials + VertTrials;

     Fx.axis[Trials] := 'd1';
     Fx.Trial[Trials].X := D[horizontal, i];
     Fx.Trial[Trials].Y := D[vertical, j];

     i := Round(inc_step + diagonal_step);
     inc_step := inc_step + diagonal_step;
     inc(j);
     //showmessage(Fx.axis[k + HorizTrials + VertTrials] + ' ' +
     //            inttostr(Fx.Trial[k + HorizTrials + VertTrials].X) + ',' +
     //            inttostr(Fx.Trial[k + HorizTrials + VertTrials].Y) + ' ' +
     //            inttostr(k + HorizTrials + VertTrials)  + ' ' +
     //            inttostr(i) + ' ' +inttostr(j));
    end;

  //right/top
  Trials := 0;
  for  k := 0 to DiagTrials -1 do
    begin
     Temp := k + HorizTrials + VertTrials;
     Trials := k + HorizTrials + VertTrials + DiagTrials;

     Fx.axis[Trials] := 'd2';
     Fx.Trial[Trials].X := MirroredDistanceOf(Fx.Trial[Temp].X, 'h');
     Fx.Trial[Trials].Y := Fx.Trial[Temp].Y;
    end;

  SetCurrentTrialTo(0);
end;

procedure TConfig.CenterRect(var Rect : TRect);
var HalfScreenWidth, HalfScreenHeight: float;
begin
  HalfScreenWidth := Screen.Width/2;
  HalfScreenHeight := Screen.Height/2;

  Rect.Left := Round(HalfScreenWidth - (Rect.Right/2));
  Rect.Right := Round(HalfScreenWidth + (Rect.Right/2));
  Rect.Top := Round(HalfScreenHeight - (Rect.Bottom/2));
  Rect.Bottom := Round(HalfScreenHeight + (Rect.Bottom/2));
end;

constructor TConfig.Create(AOwner: TComponent; Step, Circles_Size: integer;
  VisibleRect: TRect);
begin
  inherited Create(AOwner);

  //Visible Rect need to be on the center of screen
  FX.Rect := VisibleRect;
  CenterRect(FX.Rect);

  //number of mirrored circles is constant, 0 - Left/Top, 1- Right/Bottom
  with FCT do SetLength(C, 2);
  SetCircles(Circles_Size);

  //Initializes all the stuff
  //set distances in each axis, create trials ordered as such: horiz, vert, diag1, diag2
  TrialOrdering(SetAxis(Step, Circles_Size));
end;

function TConfig.NextTrial: Boolean;
begin
  with FCT do
     if i < High(Fx.Trial) then
        begin
          Inc(i);
          SetCurrentTrialTo(i);
          Result := True;
        end
     else Result := False;
end;

end.

