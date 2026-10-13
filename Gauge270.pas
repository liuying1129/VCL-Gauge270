unit Gauge270;

interface

uses
  System.SysUtils, System.Classes, System.Math, System.Types, System.UITypes,
  Winapi.Windows,
  Winapi.GDIPAPI, Winapi.GDIPOBJ, Winapi.GDIPUTIL,
  Vcl.Controls, Vcl.Graphics;

type
  TNeedleStyle = (nsLine, nsTriangle);

  TGauge270 = class(TGraphicControl)
  private
    FMinValue, FMaxValue, FValue: Double;
    FMajorTickCount, FMinorTickCount: Integer;
    FShowLabels, FShowValueText: Boolean;
    FNeedleColor: TColor;
    FNeedleStyle: TNeedleStyle;
    FTickColor, FFaceColor, FArcColor: TColor;
    FArcWidth: Integer;
    FCaption, FValueFormat: string;
    FTitle: string;
    FTickLabelFont, FCaptionFont: TFont;
    FStartAngle, FSweepAngle: Double;

    procedure SetMinValue(const V: Double);
    procedure SetMaxValue(const V: Double);
    procedure SetValue(const V: Double);
    procedure SetMajorTickCount(const V: Integer);
    procedure SetMinorTickCount(const V: Integer);
    procedure SetShowLabels(const V: Boolean);
    procedure SetShowValueText(const V: Boolean);
    procedure SetNeedleColor(const V: TColor);
    procedure SetNeedleStyle(const V: TNeedleStyle);
    procedure SetTickColor(const V: TColor);
    procedure SetFaceColor(const V: TColor);
    procedure SetArcColor(const V: TColor);
    procedure SetArcWidth(const V: Integer);
    procedure SetCaption(const V: string);
    procedure SetTitle(const V: string);
    procedure SetValueFormat(const V: string);
    procedure SetTickLabelFont(const V: TFont);
    procedure SetCaptionFont(const V: TFont);
    procedure SetStartAngle(const V: Double);
    procedure SetSweepAngle(const V: Double);
    procedure DoFontChanged(Sender: TObject);
  protected
    procedure Paint; override;
    function  ValueToAngle(AValue: Double): Double;
    function  PolarPoint(cx, cy, R: Integer; AngleDeg: Double): TPoint;
  public
    constructor Create(AOwner: TComponent); override;
    destructor  Destroy; override;
  published
    property Align;
    property Anchors;
    property Color;
    property Constraints;
    property Enabled;
    property Visible;
    property ParentShowHint;
    property ShowHint;
    property PopupMenu;
    property OnClick;
    property OnDblClick;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnResize;

    property MinValue: Double read FMinValue write SetMinValue;
    property MaxValue: Double read FMaxValue write SetMaxValue;
    property Value: Double read FValue write SetValue;
    property MajorTickCount: Integer read FMajorTickCount write SetMajorTickCount default 12;
    property MinorTickCount: Integer read FMinorTickCount write SetMinorTickCount default 4;
    property ShowLabels: Boolean read FShowLabels write SetShowLabels default True;
    property ShowValueText: Boolean read FShowValueText write SetShowValueText default True;
    property NeedleColor: TColor read FNeedleColor write SetNeedleColor default clRed;
    property NeedleStyle: TNeedleStyle read FNeedleStyle write SetNeedleStyle default nsTriangle;
    property TickColor: TColor read FTickColor write SetTickColor default clWhite;
    property FaceColor: TColor read FFaceColor write SetFaceColor default clBlack;
    property ArcColor: TColor read FArcColor write SetArcColor default clLime;
    property ArcWidth: Integer read FArcWidth write SetArcWidth default 8;
    property Caption: string read FCaption write SetCaption;
    property Title: string read FTitle write SetTitle;
    property ValueFormat: string read FValueFormat write SetValueFormat;
    property TickLabelFont: TFont read FTickLabelFont write SetTickLabelFont;
    property CaptionFont: TFont read FCaptionFont write SetCaptionFont;
    property StartAngle: Double read FStartAngle write SetStartAngle;
    property SweepAngle: Double read FSweepAngle write SetSweepAngle;
  end;

procedure Register;

implementation

{ ---------- GDI+ 辅助函数 ---------- }

function ColorToARGB(C: TColor): ARGB;
var
  RGB: LongInt;
begin
  RGB := ColorToRGB(C);
  Result := (DWORD($FF) shl 24) or
            (DWORD(GetRValue(RGB)) shl 16) or
            (DWORD(GetGValue(RGB)) shl 8) or
            DWORD(GetBValue(RGB));
end;

function FontToGPFont(F: TFont): TGPFont;
var
  Style: Integer;
begin
  Style := FontStyleRegular;
  if fsBold      in F.Style then Style := Style or FontStyleBold;
  if fsItalic    in F.Style then Style := Style or FontStyleItalic;
  if fsUnderline in F.Style then Style := Style or FontStyleUnderline;
  if fsStrikeOut in F.Style then Style := Style or FontStyleStrikeOut;
  Result := TGPFont.Create(F.Name, F.Size, Style, UnitPoint);
end;

procedure DrawTextCentered(G: TGPGraphics; const Text: string;
  F: TGPFont; B: TGPBrush; CX, CY: Single);
var
  BoundingBox: TGPRectF;
  Origin: TGPPointF;
  Pt: TGPPointF;
begin
  if Text = '' then Exit;

  // 用一个远点作为测量原点
  Origin.X := 0;
  Origin.Y := 0;

  // 使用第一个重载测量文本边界框
  G.MeasureString(Text, Length(Text), F, Origin, BoundingBox);

  // 根据返回的宽高计算居中位置
  Pt.X := CX - BoundingBox.Width  / 2;
  Pt.Y := CY - BoundingBox.Height / 2;

  G.DrawString(Text, Length(Text), F, Pt, B);
end;

{ TGauge270 }

constructor TGauge270.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width  := 240;
  Height := 240;

  FMinValue := 0;
  FMaxValue := 220;
  FValue    := 0;
  FMajorTickCount := 12;
  FMinorTickCount := 4;
  FShowLabels := True;
  FShowValueText := True;
  FNeedleColor := clRed;
  FNeedleStyle := nsTriangle;
  FTickColor := clWhite;
  FFaceColor := clBlack;
  FArcColor  := clLime;
  FArcWidth  := 8;
  FCaption   := 'km/h';
  FTitle := '';
  FValueFormat := '0';
  FStartAngle  := 135;
  FSweepAngle  := 270;

  FTickLabelFont := TFont.Create;
  FTickLabelFont.Name := 'Segoe UI';
  FTickLabelFont.Size := 8;
  FTickLabelFont.Color := clWhite;
  FTickLabelFont.OnChange := DoFontChanged;

  FCaptionFont := TFont.Create;
  FCaptionFont.Name := 'Segoe UI';
  FCaptionFont.Size := 10;
  FCaptionFont.Style := [fsBold];
  FCaptionFont.Color := clSilver;
  FCaptionFont.OnChange := DoFontChanged;

  ControlStyle := ControlStyle + [csOpaque];
end;

destructor TGauge270.Destroy;
begin
  FTickLabelFont.Free;
  FCaptionFont.Free;
  inherited;
end;

procedure TGauge270.DoFontChanged(Sender: TObject);
begin
  Invalidate;
end;

{ ---------- Setters ---------- }

procedure TGauge270.SetMinValue(const V: Double);
begin
  if FMinValue <> V then begin FMinValue := V; Invalidate; end;
end;

procedure TGauge270.SetMaxValue(const V: Double);
begin
  if FMaxValue <> V then begin FMaxValue := V; Invalidate; end;
end;

procedure TGauge270.SetValue(const V: Double);
var X: Double;
begin
  X := V;
  if X < FMinValue then X := FMinValue;
  if X > FMaxValue then X := FMaxValue;
  if FValue <> X then begin FValue := X; Invalidate; end;
end;

procedure TGauge270.SetMajorTickCount(const V: Integer);
begin
  if (V >= 2) and (FMajorTickCount <> V) then begin FMajorTickCount := V; Invalidate; end;
end;

procedure TGauge270.SetMinorTickCount(const V: Integer);
begin
  if (V >= 0) and (FMinorTickCount <> V) then begin FMinorTickCount := V; Invalidate; end;
end;

procedure TGauge270.SetShowLabels(const V: Boolean);
begin
  if FShowLabels <> V then begin FShowLabels := V; Invalidate; end;
end;

procedure TGauge270.SetShowValueText(const V: Boolean);
begin
  if FShowValueText <> V then begin FShowValueText := V; Invalidate; end;
end;

procedure TGauge270.SetNeedleColor(const V: TColor);
begin
  if FNeedleColor <> V then begin FNeedleColor := V; Invalidate; end;
end;

procedure TGauge270.SetNeedleStyle(const V: TNeedleStyle);
begin
  if FNeedleStyle <> V then begin FNeedleStyle := V; Invalidate; end;
end;

procedure TGauge270.SetTickColor(const V: TColor);
begin
  if FTickColor <> V then begin FTickColor := V; Invalidate; end;
end;

procedure TGauge270.SetFaceColor(const V: TColor);
begin
  if FFaceColor <> V then begin FFaceColor := V; Invalidate; end;
end;

procedure TGauge270.SetArcColor(const V: TColor);
begin
  if FArcColor <> V then begin FArcColor := V; Invalidate; end;
end;

procedure TGauge270.SetArcWidth(const V: Integer);
begin
  if (V >= 1) and (FArcWidth <> V) then begin FArcWidth := V; Invalidate; end;
end;

procedure TGauge270.SetCaption(const V: string);
begin
  if FCaption <> V then begin FCaption := V; Invalidate; end;
end;

procedure TGauge270.SetValueFormat(const V: string);
begin
  if FValueFormat <> V then begin FValueFormat := V; Invalidate; end;
end;

procedure TGauge270.SetTickLabelFont(const V: TFont);
begin
  FTickLabelFont.Assign(V);
  Invalidate;
end;

procedure TGauge270.SetTitle(const V: string);
begin
  if FTitle <> V then begin FTitle := V; Invalidate; end;
end;

procedure TGauge270.SetCaptionFont(const V: TFont);
begin
  FCaptionFont.Assign(V);
  Invalidate;
end;

procedure TGauge270.SetStartAngle(const V: Double);
begin
  if FStartAngle <> V then begin FStartAngle := V; Invalidate; end;
end;

procedure TGauge270.SetSweepAngle(const V: Double);
begin
  if FSweepAngle <> V then begin FSweepAngle := V; Invalidate; end;
end;

{ ---------- 几何辅助 ---------- }

function TGauge270.PolarPoint(cx, cy, R: Integer; AngleDeg: Double): TPoint;
var Rad: Double;
begin
  Rad := DegToRad(AngleDeg);
  Result.X := cx + Round(R * Cos(Rad));
  Result.Y := cy + Round(R * Sin(Rad));
end;

function TGauge270.ValueToAngle(AValue: Double): Double;
var Rng: Double;
begin
  Rng := FMaxValue - FMinValue;
  if Rng = 0 then
    Result := FStartAngle
  else
    Result := FStartAngle + (AValue - FMinValue) / Rng * FSweepAngle;
end;

{ ---------- 核心绘制（GDI+） ---------- }

procedure TGauge270.Paint;
var
  Bmp: Vcl.Graphics.TBitmap;
  G: TGPGraphics;
  Brush: TGPSolidBrush;
  Pen: TGPPen;
  Font: TGPFont;
  cx, cy, R: Integer;
  RArc, RTickOuter, RTickInner, RLabel, RNeedle: Integer;
  MajorLen, MinorLen, TickW, CapR: Integer;
  N, SubN, i: Integer;
  V, MajorStep, A: Double;
  P1, P2, Tip: TPoint;
  txt: string;
  AngleRad, PerpRad, HalfW: Double;
  BX1, BY1, BX2, BY2: Integer;
  TriPts: array[0..2] of TGPPoint;
begin
  Bmp := Vcl.Graphics.TBitmap.Create;
  try
    Bmp.SetSize(Max(1, Width), Max(1, Height));
    Bmp.PixelFormat := pf32bit;

    G := TGPGraphics.Create(Bmp.Canvas.Handle);
    try
      // 关键：开启抗锯齿
      G.SetSmoothingMode(SmoothingModeAntiAlias);
      G.SetTextRenderingHint(TextRenderingHintAntiAlias);
      G.SetPixelOffsetMode(PixelOffsetModeHalf);

      // 背景
      Brush := TGPSolidBrush.Create(ColorToARGB(Color));
      try
        G.FillRectangle(Brush, 0, 0, Width, Height);
      finally
        Brush.Free;
      end;

      cx := Width  div 2;
      cy := Height div 2;
      R  := Min(cx, cy) - 4;

      if R >= 20 then
      begin
        // 布局半径
        RArc       := R - FArcWidth div 2;
        RTickOuter := RArc - FArcWidth div 2 - 3;
        MajorLen   := Max(8, Round(R * 0.10));
        MinorLen   := Max(4, Round(R * 0.05));
        RTickInner := RTickOuter - MajorLen;
        RLabel     := RTickInner - Round(R * 0.08);
        RNeedle    := RTickInner + 2;

        // 表盘圆面
        Brush := TGPSolidBrush.Create(ColorToARGB(FFaceColor));
        try
          G.FillEllipse(Brush, cx - R, cy - R, 2 * R, 2 * R);
        finally
          Brush.Free;
        end;

        Pen := TGPPen.Create(ColorToARGB(clGray), 1);
        try
          G.DrawEllipse(Pen, cx - R, cy - R, 2 * R, 2 * R);
        finally
          Pen.Free;
        end;

        // 彩色圆弧（GDI+ 原生画弧，自动抗锯齿 + 圆角线帽）
        Pen := TGPPen.Create(ColorToARGB(FArcColor), FArcWidth);
        try
          Pen.SetStartCap(LineCapRound);
          Pen.SetEndCap(LineCapRound);
          G.DrawArc(Pen,
            cx - RArc, cy - RArc, 2 * RArc, 2 * RArc,
            FStartAngle, FSweepAngle);
        finally
          Pen.Free;
        end;

        // 主刻度步长
        N := FMajorTickCount;
        if N < 2 then N := 2;
        MajorStep := (FMaxValue - FMinValue) / (N - 1);
        TickW := Max(1, Round(R * 0.015));

        // 次刻度
        SubN := FMinorTickCount;
        if (SubN > 1) and (N > 1) then
        begin
          Pen := TGPPen.Create(ColorToARGB(FTickColor), Max(1, TickW - 1));
          try
            Pen.SetStartCap(LineCapRound);
            Pen.SetEndCap(LineCapRound);
            for i := 1 to (N - 1) * SubN - 1 do
            begin
              if (i mod SubN) = 0 then Continue;
              V := FMinValue + (i / SubN) * MajorStep;
              if V > FMaxValue then Break;
              A  := ValueToAngle(V);
              P1 := PolarPoint(cx, cy, RTickOuter, A);
              P2 := PolarPoint(cx, cy, RTickOuter - MinorLen, A);
              G.DrawLine(Pen, P1.X, P1.Y, P2.X, P2.Y);
            end;
          finally
            Pen.Free;
          end;
        end;

        // 主刻度
        Pen := TGPPen.Create(ColorToARGB(FTickColor), TickW);
        try
          Pen.SetStartCap(LineCapRound);
          Pen.SetEndCap(LineCapRound);
          for i := 0 to N - 1 do
          begin
            V := FMinValue + i * MajorStep;
            A := ValueToAngle(V);
            P1 := PolarPoint(cx, cy, RTickOuter, A);
            P2 := PolarPoint(cx, cy, RTickInner, A);
            G.DrawLine(Pen, P1.X, P1.Y, P2.X, P2.Y);
          end;
        finally
          Pen.Free;
        end;

        // 数字刻度标签
        if FShowLabels then
        begin
          Font := FontToGPFont(FTickLabelFont);
          try
            Brush := TGPSolidBrush.Create(ColorToARGB(FTickLabelFont.Color));
            try
              for i := 0 to N - 1 do
              begin
                V := FMinValue + i * MajorStep;
                A := ValueToAngle(V);
                txt := FormatFloat(FValueFormat, V);
                P1 := PolarPoint(cx, cy, RLabel, A);
                DrawTextCentered(G, txt, Font, Brush, P1.X, P1.Y);
              end;
            finally
              Brush.Free;
            end;
          finally
            Font.Free;
          end;
        end;

        // 指标名称（圆心上方，画在指针之下）
        if FTitle <> '' then
        begin
          Font := FontToGPFont(FCaptionFont);
          try
            Brush := TGPSolidBrush.Create(ColorToARGB(FCaptionFont.Color));
            try
              DrawTextCentered(G, FTitle, Font, Brush, cx, cy - Round(R * 0.30));
            finally
              Brush.Free;
            end;
          finally
            Font.Free;
          end;
        end;

        // 指针
        A        := ValueToAngle(FValue);
        AngleRad := DegToRad(A);
        Tip.X    := cx + Round(RNeedle * Cos(AngleRad));
        Tip.Y    := cy + Round(RNeedle * Sin(AngleRad));

        if FNeedleStyle = nsTriangle then
        begin
          PerpRad := AngleRad + Pi / 2;
          HalfW   := Max(3.0, R * 0.035);
          BX1 := cx + Round(HalfW * Cos(PerpRad));
          BY1 := cy + Round(HalfW * Sin(PerpRad));
          BX2 := cx - Round(HalfW * Cos(PerpRad));
          BY2 := cy - Round(HalfW * Sin(PerpRad));

          TriPts[0] := MakePoint(BX1, BY1);
          TriPts[1] := MakePoint(Tip.X, Tip.Y);
          TriPts[2] := MakePoint(BX2, BY2);

          Brush := TGPSolidBrush.Create(ColorToARGB(FNeedleColor));
          try
            G.FillPolygon(Brush, PGPPoint(@TriPts[0]), 3);
          finally
            Brush.Free;
          end;
        end
        else
        begin
          Pen := TGPPen.Create(ColorToARGB(FNeedleColor),
            Max(2, Round(R * 0.025)));
          try
            Pen.SetStartCap(LineCapRound);
            Pen.SetEndCap(LineCapRound);
            G.DrawLine(Pen, cx, cy, Tip.X, Tip.Y);
          finally
            Pen.Free;
          end;
        end;

        // 中心圆盖
        CapR := Max(4, Round(R * 0.06));
        Brush := TGPSolidBrush.Create(ColorToARGB(FNeedleColor));
        try
          G.FillEllipse(Brush, cx - CapR, cy - CapR, 2 * CapR, 2 * CapR);
        finally
          Brush.Free;
        end;

        Pen := TGPPen.Create(ColorToARGB(clGray), 1);
        try
          G.DrawEllipse(Pen, cx - CapR, cy - CapR, 2 * CapR, 2 * CapR);
        finally
          Pen.Free;
        end;

        // 中央数值
        if FShowValueText then
        begin
          Font := FontToGPFont(FCaptionFont);
          try
            Brush := TGPSolidBrush.Create(ColorToARGB(FCaptionFont.Color));
            try
              txt := FormatFloat(FValueFormat, FValue);
              DrawTextCentered(G, txt, Font, Brush, cx, cy + Round(R * 0.30));
            finally
              Brush.Free;
            end;
          finally
            Font.Free;
          end;
        end;

        // 单位 / 标题
        if FCaption <> '' then
        begin
          Font := FontToGPFont(FCaptionFont);
          try
            Brush := TGPSolidBrush.Create(ColorToARGB(FCaptionFont.Color));
            try
              DrawTextCentered(G, FCaption, Font, Brush, cx, cy + Round(R * 0.52));
            finally
              Brush.Free;
            end;
          finally
            Font.Free;
          end;
        end;
      end;
    finally
      G.Free;
    end;

    Canvas.Draw(0, 0, Bmp);
  finally
    Bmp.Free;
  end;
end;

procedure Register;
begin
  RegisterComponents('Samples', [TGauge270]);
end;

end.
