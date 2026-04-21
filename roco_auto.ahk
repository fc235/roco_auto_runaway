#Requires AutoHotkey v2.0
#SingleInstance Force
CoordMode "Pixel", "Screen"


CoordMode "Mouse", "Screen"


class Config {
  static defaultGameWindowTitle := "洛克王国：世界"
  static defaultGameProcess := "NRC-Win64-Shipping.exe"
  static targetMode := "窗口标题"
  static targetValue := "洛克王国：世界"
  static monitorIntervalMs := 250
  static combatConfirmHitsRequired := 2
  static handHoldingCheckIntervalMs := 30000
  static gatherActionCooldownMs := 2200
  static runawayActionCooldownMs := 1500
  static combatColorTolerance := 16
  static uiColorTolerance := 8
  static requiredActionNearbyMatches := 3
  static runawayFallbackXRatio := 0.78
  static runawayFallbackYRatio := 0.81
  static handHoldingTextTolerance := 18
  static requiredHandHoldingTextMatches := 2
}


; 当前运行状态
class RunningStatus {
  ; 是否启动自动聚气/逃跑 0: 关闭 1:自动聚气 2:自动逃跑
  static avoidWarState := 0
  static autoHandHoldingEnabled := false
  static uiEditMode := false
  static previousUiFocusHwnd := 0
  static isInCombat := false
  static combatConfirmHits := 0
  static lastGatherTick := 0
  static lastRunawayTick := 0
}

; ui实例类
class UIClass {
  static ui := ""
  static editModeBtn := ""
  static targetModeDDL := ""
  static targetValueEdit := ""
  static applyTargetBtn := ""
  static gatherEnergyBtn := ""
  static runAwayBtn := ""
  static handHoldingBtn := ""
  static handHoldingIntervalEdit := ""
  static applyHandHoldingIntervalBtn := ""
  static logBox := ""
}


; 聚能黄色五角星色值 #ffc65f
EnergyColor := 0xffc65f
; 聚能黄色五角星旁边的定位色值
; x的黑色
EnergyColorNearby_1 := 0x272727
; 聚能字的灰白色
EnergyColorNearby_2 := 0xc3c3b9
EnergyColorNearby_3 := 0xdbd4c5
; 聚能图标的白色
EnergyColorNearby_4 := 0xf4eee1
; 聚能黑灰底色
EnergyColorNearby_5 := 0x5c5648
; 换精灵时左下角的绿色心
GreenLove_1 := 0x82bf38
GreenLove_2 := 0x64a517
GreenLove_3 := 0x3d3d3d


; 左上角血条颜色 绿色 健康
HealthBarColor1 := 0x73c615
; 左上角血条颜色 黄色 受伤
HealthBarColor2 := 0xfcb641
; 左上角血条颜色 红色 濒死
HealthBarColor3 := 0xaf3d3e

; 逃跑确认按钮可能出现的浅色文字/高亮
RunawayButtonColor1 := 0xf4eee1
RunawayButtonColor2 := 0xdbd4c5
RunawayButtonColor3 := 0xc3c3b9

; 牵手提示文字颜色
HandHoldingTextColor1 := 0xdc9827
HandHoldingTextColor2 := 0xe29816
HandHoldingTextColor3 := 0xe39e24


; ================== GUI ==================
InitGui() {
  global ui

  ; TraySetIcon("app.ico", 1, true)

  ui := Gui("-Resize -MaximizeBox -MinimizeBox +AlwaysOnTop")
  ui.Title := "洛克王国  自动避战"
  ui.BackColor := "F6F0E5"


  ; 默认不抢焦点，进入“修改”模式时再临时允许激活
  hwnd := ui.Hwnd
  ApplyGuiNoActivate(hwnd, true)
  OnMessage(0x21, WM_MOUSEACTIVATE)
  WM_MOUSEACTIVATE(wParam, lParam, msg, currentHwnd) {
    if (currentHwnd != hwnd) {
      return
    }
    return RunningStatus.uiEditMode ? 1 : 3
  }

  ui.SetFont("s12 c5A4633", "Microsoft YaHei UI")
  ui.AddText("x20 y16", "洛克王国 自动避战")
  UIClass.editModeBtn := ui.AddButton("x402 y14 w48 h24", "修改")
  UIClass.editModeBtn.OnEvent("Click", onClickEditModeBtn)
  ui.SetFont("s8 c7B6B58", "Microsoft YaHei UI")
  ui.AddText("x20 y40 w200", "窗口化副屏使用更稳定")

  ui.SetFont("s9 c4A3F31", "Microsoft YaHei UI")
  ui.AddGroupBox("x16 y66 w208 h176", "窗口与功能")
  ui.AddText("x30 y92 w60", "目标窗口")

  UIClass.targetModeDDL := ui.AddDropDownList("x94 y88 w78", ["窗口标题", "进程名"])
  if (Config.targetMode = "进程名") {
    UIClass.targetModeDDL.Choose(2)
  } else {
    UIClass.targetModeDDL.Choose(1)
  }

  UIClass.targetValueEdit := ui.AddEdit("x30 y120 w138 h24", Config.targetValue)
  UIClass.applyTargetBtn := ui.AddButton("x174 y119 w34 h25", "应用")
  UIClass.applyTargetBtn.OnEvent("Click", onClickApplyTargetBtn)

  UIClass.gatherEnergyBtn := ui.AddButton("x30 y156 w178 h28", "自动聚气: 关")
  UIClass.gatherEnergyBtn.OnEvent("Click", onClickGatherEnergyBtn)

  UIClass.runAwayBtn := ui.AddButton("x30 y190 w178 h28", "自动逃跑: 关")
  UIClass.runAwayBtn.OnEvent("Click", onClickRunAwayBtn)

  UIClass.handHoldingBtn := ui.AddButton("x30 y224 w178 h28", "自动牵手: 关")
  UIClass.handHoldingBtn.OnEvent("Click", onClickHandHoldingBtn)

  ui.AddGroupBox("x16 y252 w208 h72", "牵手设置")
  ui.AddText("x30 y280 w84", "检测间隔(秒)")
  UIClass.handHoldingIntervalEdit := ui.AddEdit("x118 y276 w50 h24 Center", Round(Config.handHoldingCheckIntervalMs / 1000))
  UIClass.applyHandHoldingIntervalBtn := ui.AddButton("x174 y275 w34 h25", "应用")
  UIClass.applyHandHoldingIntervalBtn.OnEvent("Click", onClickApplyHandHoldingIntervalBtn)

  ui.AddGroupBox("x236 y16 w228 h308", "运行日志")
  ui.SetFont("s8 c7B6B58", "Microsoft YaHei UI")
  ui.AddText("x252 y40 w196", "显示最近状态，便于观察识别结果")
  UIClass.logBox := ui.AddEdit("x252 y64 w196 h242 ReadOnly -Border -VScroll -HScroll +Disabled")
  UIClass.logBox.SetFont("s9 c2F2A23", "Consolas")


  ; testBtn := ui.AddButton("xm y+20 w100 h30", "测试按钮")

  ; 设置关闭事件, 关闭gui的时候关闭脚本
  ui.OnEvent("Close", GuiClose)  ; 绑定关闭事件

  GuiClose(*) {
    ExitApp()  ; 点击 X 时退出脚本
  }


  UIClass.ui := ui
  ui.Show("w480 h340 NOACTIVATE")
}


; ================== 入口 ==================
Main() {
  ElevatePrivileges()
  InitGui()
  RefreshActionButtons()
  AddLog("开始运行...")
}
Main()

HasArg(expectedArg) {
  for arg in A_Args {
    if (StrLower(arg) = StrLower(expectedArg)) {
      return true
    }
  }
  return false
}

; ================== 管理员提权 ==================
ElevatePrivileges() {
  if HasArg("/skip-elevate") {
    return
  }

  if !A_IsAdmin {
    Run('*RunAs "' A_ScriptFullPath '"')
    ExitApp
  }
}

ApplyGuiNoActivate(hwnd, enabled) {
  exStyle := DllCall("GetWindowLongPtr", "Ptr", hwnd, "Int", -20, "Ptr")
  newStyle := enabled ? (exStyle | 0x08000000) : (exStyle & ~0x08000000)
  DllCall("SetWindowLongPtr", "Ptr", hwnd, "Int", -20, "Ptr", newStyle)
}

SetUiEditMode(enabled) {
  hwnd := UIClass.ui.Hwnd
  if !hwnd {
    return
  }

  RunningStatus.uiEditMode := enabled
  ApplyGuiNoActivate(hwnd, !enabled)

  if enabled {
    RunningStatus.previousUiFocusHwnd := CaptureForegroundWindow(hwnd)
    UIClass.editModeBtn.Text := "完成"
    WinActivate("ahk_id " hwnd)
    try UIClass.handHoldingIntervalEdit.Focus()
  } else {
    UIClass.editModeBtn.Text := "修改"
    UIClass.ui.Show("NOACTIVATE")
    RestoreForegroundWindow(RunningStatus.previousUiFocusHwnd)
    RunningStatus.previousUiFocusHwnd := 0
  }
}


DrawAccurate(x, y, size := 20) {
  g1 := Gui("+AlwaysOnTop -Caption +ToolWindow")
  g1.BackColor := "Red"
  g1.Show("x" (x - size) " y" y " w" (size * 2) " h2 NA")

  g2 := Gui("+AlwaysOnTop -Caption +ToolWindow")
  g2.BackColor := "Red"
  g2.Show("x" x " y" (y - size) " w2 h" (size * 2) " NA")

  SetTimer((*) => (g1.Destroy(), g2.Destroy()), -2000)
}

; ================== 测试用 ==================
SendOnce(*) {
}

onClickEditModeBtn(*) {
  SetUiEditMode(!RunningStatus.uiEditMode)
  AddLog(RunningStatus.uiEditMode ? "已进入配置修改模式" : "已退出配置修改模式")
}

onClickApplyTargetBtn(*) {
  mode := UIClass.targetModeDDL.Text
  value := Trim(UIClass.targetValueEdit.Value)

  if value = "" {
    AddLog("请输入窗口标题或进程名")
    return
  }

  Config.targetMode := mode
  Config.targetValue := value

  if GetGameHwnd() {
    AddLog("目标已应用: " mode " / " value)
  } else {
    AddLog("目标已保存, 当前未找到窗口")
  }

  if RunningStatus.uiEditMode {
    SetUiEditMode(false)
  }
}


; ================== 激活游戏窗口 ==================
ActivateGameWindow(*) {
  hwnd := GetGameHwnd()
  if hwnd {
    ActivateWindowById(hwnd)
  }
}

BuildGameWinMatcher(mode, value) {
  value := Trim(value)
  if value = "" {
    return ""
  }

  if mode = "进程名" {
    if InStr(value, "ahk_exe ") = 1 {
      return value
    }
    return "ahk_exe " value
  }

  return value
}

GetGameHwnd() {
  matcher := BuildGameWinMatcher(Config.targetMode, Config.targetValue)
  return matcher != "" ? WinExist(matcher) : 0
}

ActivateWindowById(hwnd, restoreMinimized := true) {
  WinShow("ahk_id " hwnd)
  try windowState := WinGetMinMax("ahk_id " hwnd)
  catch
    windowState := 0

  if restoreMinimized && (windowState = -1) {
    WinRestore("ahk_id " hwnd)
  }

  if WinActive("ahk_id " hwnd) {
    return true
  }

  targetWin := "ahk_id " hwnd
  currentWin := WinExist("A")
  currentThread := DllCall("GetCurrentThreadId", "UInt")
  foregroundThread := currentWin ? DllCall("GetWindowThreadProcessId", "Ptr", currentWin, "UInt*", 0, "UInt") : 0
  targetThread := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "UInt*", 0, "UInt")

  try {
    if foregroundThread {
      DllCall("AttachThreadInput", "UInt", currentThread, "UInt", foregroundThread, "Int", 1)
    }
    if targetThread && targetThread != currentThread {
      DllCall("AttachThreadInput", "UInt", currentThread, "UInt", targetThread, "Int", 1)
    }

    Loop 3 {
      WinActivate(targetWin)
      DllCall("SetForegroundWindow", "Ptr", hwnd)
      DllCall("BringWindowToTop", "Ptr", hwnd)
      DllCall("ShowWindow", "Ptr", hwnd, "Int", 5)

      if WinWaitActive(targetWin, , 0.4) {
        return true
      }

      SendEvent "{Alt}"
      Sleep(80)
    }
  } finally {
    if foregroundThread {
      DllCall("AttachThreadInput", "UInt", currentThread, "UInt", foregroundThread, "Int", 0)
    }
    if targetThread && targetThread != currentThread {
      DllCall("AttachThreadInput", "UInt", currentThread, "UInt", targetThread, "Int", 0)
    }
  }

  return WinActive(targetWin)
}

CaptureForegroundWindow(excludeHwnd := 0) {
  hwnd := WinExist("A")
  if !hwnd {
    return 0
  }

  if excludeHwnd && (hwnd = excludeHwnd) {
    return 0
  }

  return hwnd
}

RestoreForegroundWindow(hwnd) {
  if !hwnd || !WinExist("ahk_id " hwnd) {
    return false
  }

  if WinActive("ahk_id " hwnd) {
    return true
  }

  WinActivate("ahk_id " hwnd)
  DllCall("SetForegroundWindow", "Ptr", hwnd)
  return WinWaitActive("ahk_id " hwnd, , 0.5)
}

GetGameClientArea(&x, &y, &width, &height, activate := false) {
  hwnd := GetGameHwnd()
  if !hwnd {
    AddLog("未找到游戏窗口")
    return 0
  }

  if activate && !ActivateWindowById(hwnd) {
    AddLog("无法激活游戏窗口")
    return 0
  }

  try {
    WinGetClientPos(&x, &y, &width, &height, "ahk_id " hwnd)
  } catch {
    WinGetPos(&x, &y, &width, &height, "ahk_id " hwnd)
  }

  if (width <= 0 || height <= 0) {
    AddLog("游戏窗口尺寸异常")
    return 0
  }

  return hwnd
}

ResetCombatState() {
  RunningStatus.isInCombat := false
  RunningStatus.combatConfirmHits := 0
  RunningStatus.lastGatherTick := 0
  RunningStatus.lastRunawayTick := 0
}

StartMonitoring() {
  ResetCombatState()
  SetTimer(MonitorCombat, Config.monitorIntervalMs)
}

StopMonitoring() {
  SetTimer(MonitorCombat, 0)
  ResetCombatState()
}

StartHandHoldingMonitoring() {
  SetTimer(CheckAutoHandHolding, Config.handHoldingCheckIntervalMs)
}

StopHandHoldingMonitoring() {
  SetTimer(CheckAutoHandHolding, 0)
}

ApplyHandHoldingInterval(seconds) {
  seconds := Floor(seconds + 0)
  if (seconds < 1) {
    return false
  }

  Config.handHoldingCheckIntervalMs := seconds * 1000
  if RunningStatus.autoHandHoldingEnabled {
    StopHandHoldingMonitoring()
    StartHandHoldingMonitoring()
  }

  return true
}

SetActionButtonState(ctrl, label, isActive) {
  if !ctrl {
    return
  }

  ctrl.Text := label ": " (isActive ? "开" : "关")
  ctrl.Opt(isActive ? "+BackgroundD4E7C5 c2F4A21" : "+BackgroundF1E2CF c4A3F31")
}

RefreshActionButtons() {
  SetActionButtonState(UIClass.gatherEnergyBtn, "自动聚气", RunningStatus.avoidWarState = 1)
  SetActionButtonState(UIClass.runAwayBtn, "自动逃跑", RunningStatus.avoidWarState = 2)
  SetActionButtonState(UIClass.handHoldingBtn, "自动牵手", RunningStatus.autoHandHoldingEnabled)
}

GetActionAreaBounds(windowX, windowY, windowW, windowH, &startX, &startY, &endX, &endY) {
  startX := Round(windowX)
  endX := Round(windowX + windowW * 0.18)
  startY := Round(windowY + windowH * 0.76)
  endY := Round(windowY + windowH)
}

GetHealthBarBounds(windowX, windowY, windowW, windowH, &startX, &startY, &endX, &endY) {
  startX := Round(windowX)
  endX := Round(windowX + windowW * 0.15)
  startY := Round(windowY)
  endY := Round(windowY + windowH * 0.1)
}

GetNormalAreaBounds(windowX, windowY, windowW, windowH, &startX, &startY, &endX, &endY) {
  startX := Round(windowX)
  startY := Round(windowY)
  endX := Round(windowX + windowW * 0.1)
  endY := Round(windowY + windowH * 0.1)
}

GetRunawayBounds(windowX, windowY, windowW, windowH, &startX, &startY, &endX, &endY) {
  startX := Round(windowX + windowW * 0.45)
  startY := Round(windowY + windowH * 0.6)
  endX := Round(windowX + windowW)
  endY := Round(windowY + windowH)
}

GetRunawayFocusBounds(windowX, windowY, windowW, windowH, &startX, &startY, &endX, &endY) {
  startX := Round(windowX + windowW * 0.62)
  startY := Round(windowY + windowH * 0.68)
  endX := Round(windowX + windowW * 0.93)
  endY := Round(windowY + windowH * 0.92)
}

GetRunawayFallbackPoint(windowX, windowY, windowW, windowH, &x, &y) {
  x := Round(windowX + windowW * Config.runawayFallbackXRatio)
  y := Round(windowY + windowH * Config.runawayFallbackYRatio)
}

GetHandHoldingBounds(windowX, windowY, windowW, windowH, &startX, &startY, &endX, &endY) {
  startX := Round(windowX + windowW * 0.58)
  startY := Round(windowY + windowH * 0.49)
  endX := Round(windowX + windowW * 0.70)
  endY := Round(windowY + windowH * 0.56)
}

FindColorPoint(startX, startY, endX, endY, colorValue, tolerance) {
  if PixelSearch(&foundX, &foundY, startX, startY, endX, endY, colorValue, tolerance) {
    return {x: foundX, y: foundY, color: colorValue}
  }
  return 0
}

FindRunawayButtonClickPoint(windowX, windowY, windowW, windowH, &clickX, &clickY) {
  GetRunawayFocusBounds(windowX, windowY, windowW, windowH, &focusStartX, &focusStartY, &focusEndX, &focusEndY)
  GetRunawayFallbackPoint(windowX, windowY, windowW, windowH, &fallbackX, &fallbackY)

  points := []
  runawayColors := [RunawayButtonColor1, RunawayButtonColor2, RunawayButtonColor3]

  for color in runawayColors {
    point := FindColorPoint(focusStartX, focusStartY, focusEndX, focusEndY, color, Config.uiColorTolerance)
    if point {
      points.Push(point)
    }
  }

  if points.Length > 0 {
    sumX := 0
    sumY := 0
    for point in points {
      sumX += point.x
      sumY += point.y
    }

    clickX := Round(sumX / points.Length)
    clickY := Round(sumY / points.Length)
    return true
  }

  clickX := fallbackX
  clickY := fallbackY
  return false
}

CountCombatNearbyMatches(startX, startY, endX, endY, tolerance) {
  matches := 0
  nearbyColors := [EnergyColorNearby_1, EnergyColorNearby_2, EnergyColorNearby_3, EnergyColorNearby_4, EnergyColorNearby_5]

  for color in nearbyColors {
    if PixelSearch(&_, &_, startX, startY, endX, endY, color, tolerance) {
      matches += 1
    }
  }

  return matches
}

IsCombatActionVisible(windowX, windowY, windowW, windowH, tolerance := "") {
  if (tolerance = "") {
    tolerance := Config.combatColorTolerance
  }

  GetActionAreaBounds(windowX, windowY, windowW, windowH, &startX, &startY, &endX, &endY)
  if !PixelSearch(&_, &_, startX, startY, endX, endY, EnergyColor, tolerance) {
    return false
  }

  return CountCombatNearbyMatches(startX, startY, endX, endY, tolerance) >= Config.requiredActionNearbyMatches
}

CanRunAction(lastTick, cooldownMs) {
  return (lastTick = 0) || (A_TickCount - lastTick >= cooldownMs)
}


; 按键事件
; 自动聚气
onClickGatherEnergyBtn(ctrl, *) {
  if RunningStatus.avoidWarState != 1 {
    ; 修改一下状态
    RunningStatus.avoidWarState := 1
    RefreshActionButtons()
    AddLog("自动聚气已开启")
    StartMonitoring()
    return
  }

  ; 修改一下状态
  RunningStatus.avoidWarState := 0
  RefreshActionButtons()
  StopMonitoring()
  AddLog("自动聚气已关闭")
}

; 自动逃跑
onClickRunAwayBtn(ctrl, *) {
  if RunningStatus.avoidWarState != 2 {
    ; 修改一下状态
    RunningStatus.avoidWarState := 2
    RefreshActionButtons()
    AddLog("自动逃跑已开启")
    StartMonitoring()
    return
  }

  ; 修改一下状态
  RunningStatus.avoidWarState := 0
  RefreshActionButtons()
  StopMonitoring()
  AddLog("自动逃跑已关闭")
}

onClickHandHoldingBtn(ctrl, *) {
  RunningStatus.autoHandHoldingEnabled := !RunningStatus.autoHandHoldingEnabled
  RefreshActionButtons()

  if RunningStatus.autoHandHoldingEnabled {
    AddLog("自动牵手已开启")
    StartHandHoldingMonitoring()
    CheckAutoHandHolding()
  } else {
    StopHandHoldingMonitoring()
    AddLog("自动牵手已关闭")
  }
}

onClickApplyHandHoldingIntervalBtn(*) {
  rawValue := Trim(UIClass.handHoldingIntervalEdit.Value)
  if rawValue = "" {
    AddLog("请输入牵手间隔秒数")
    return
  }

  if !RegExMatch(rawValue, "^\d+$") {
    AddLog("牵手间隔需为正整数秒")
    return
  }

  seconds := Floor(rawValue + 0)
  if (seconds < 1) {
    AddLog("牵手间隔至少为1秒")
    return
  }

  if !ApplyHandHoldingInterval(seconds) {
    AddLog("牵手间隔应用失败")
    return
  }

  UIClass.handHoldingIntervalEdit.Value := seconds
  AddLog("牵手间隔已设置为 " seconds " 秒")

  if RunningStatus.uiEditMode {
    SetUiEditMode(false)
  }
}

IsHandHoldingDialogVisible(windowX, windowY, windowW, windowH) {
  GetHandHoldingBounds(windowX, windowY, windowW, windowH, &startX, &startY, &endX, &endY)
  matches := 0
  handHoldingColors := [HandHoldingTextColor1, HandHoldingTextColor2, HandHoldingTextColor3]

  for color in handHoldingColors {
    if PixelSearch(&_, &_, startX, startY, endX, endY, color, Config.handHoldingTextTolerance) {
      matches += 1
    }
  }

  return matches >= Config.requiredHandHoldingTextMatches
}

CheckAutoHandHolding() {
  if !RunningStatus.autoHandHoldingEnabled {
    return
  }

  hwnd := GetGameHwnd()
  if !hwnd {
    AddLog("牵手检测结果: 未找到目标窗口")
    return
  }

  if !GetGameClientArea(&windowX, &windowY, &windowW, &windowH) {
    AddLog("牵手检测结果: 未找到游戏窗口区域")
    return
  }

  if !isItInNormalCondition(windowX, windowY, windowW, windowH) {
    AddLog("牵手检测结果: 当前不在大世界")
    return
  }

  if !IsHandHoldingDialogVisible(windowX, windowY, windowW, windowH) {
    AddLog("牵手检测结果: 未识别到牵手文字")
    return
  }

  AddLog("牵手检测结果: 已识别到牵手文字, 准备按F")
  previousHwnd := CaptureForegroundWindow(hwnd)
  if !GetGameClientArea(&windowX, &windowY, &windowW, &windowH, true) {
    AddLog("牵手检测结果: 激活游戏窗口失败")
    return
  }

  Sleep(150)
  SendKey("f")
  Sleep(100)
  RestoreForegroundWindow(previousHwnd)
  AddLog("牵手检测结果: 已发送F")
}

; 自动避战逻辑, 循环检查是否进战
MonitorCombat() {
  ; 检查状态是否被关闭
  if RunningStatus.avoidWarState == 0 {
    return
  }

  if !GetGameClientArea(&windowX, &windowY, &windowW, &windowH) {
    return
  }

  if isItInNormalCondition(windowX, windowY, windowW, windowH) {
    RunningStatus.combatConfirmHits := 0
    if RunningStatus.isInCombat {
      RunningStatus.isInCombat := false
      AddLog("战斗结束, 恢复检测")
    } else {
      AddLog("正在检查是否进入战斗...")
    }
    return
  }

  AddLog("正在检查是否进入战斗...")
  if whetherEnterCombat(windowX, windowY, windowW, windowH) {
    RunningStatus.combatConfirmHits := Min(RunningStatus.combatConfirmHits + 1, Config.combatConfirmHitsRequired)
    if (RunningStatus.combatConfirmHits < Config.combatConfirmHitsRequired) {
      AddLog("疑似进入战斗, 正在二次确认...")
      return
    }

    if !RunningStatus.isInCombat {
      RunningStatus.isInCombat := true
    }

    if RunningStatus.avoidWarState == 1 {
      AddLog("进入战斗, 目前模式为: 自动聚气")
      collectEnergy(windowX, windowY, windowW, windowH)
    } else if RunningStatus.avoidWarState == 2 {
      AddLog("进入战斗, 目前模式为: 自动逃跑")
      exitCombat(windowX, windowY, windowW, windowH)
    }
  } else {
    RunningStatus.combatConfirmHits := 0
  }
}


; 判断是否进入了战斗
whetherEnterCombat(windowX := "", windowY := "", windowW := "", windowH := "") {
  if (windowX = "" || windowY = "" || windowW = "" || windowH = "") {
    if !GetGameClientArea(&windowX, &windowY, &windowW, &windowH) {
      return false
    }
  }

  if getHealthBarColor(windowX, windowY, windowW, windowH) = 0 {
    return false
  }

  return IsCombatActionVisible(windowX, windowY, windowW, windowH)
}


; 战斗中进行聚能
collectEnergy(windowX := "", windowY := "", windowW := "", windowH := "") {
  deviationValue := Config.combatColorTolerance
  if (windowX = "" || windowY = "" || windowW = "" || windowH = "") {
    if !GetGameClientArea(&windowX, &windowY, &windowW, &windowH) {
      return
    }
  }

  GetActionAreaBounds(windowX, windowY, windowW, windowH, &startX, &startY, &endX, &endY)

  ; 这里检查一下是否在换人界面, 如果在换人界面就说明精灵被打死了, 直接逃跑
  if PixelSearch(&_, &_, startX, startY, endX, endY, GreenLove_1, deviationValue)
    && PixelSearch(&_, &_, startX, startY, endX, endY, GreenLove_2, deviationValue)
    && PixelSearch(&_, &_, startX, startY, endX, endY, GreenLove_3, deviationValue) {
    AddLog("处于换人界面, 启用自动逃跑")
    ; 被打死了就逃跑
    exitCombat()
    return
  }

  ; 检查一下战斗是否结束了
  if isItInNormalCondition(windowX, windowY, windowW, windowH) {
    return
  }


  ; 检查一下是否还存在聚气图标
  if IsCombatActionVisible(windowX, windowY, windowW, windowH, deviationValue)
    && CanRunAction(RunningStatus.lastGatherTick, Config.gatherActionCooldownMs) {

    AddLog("开始执行聚气动作")
    previousHwnd := CaptureForegroundWindow(GetGameHwnd())
    if !GetGameClientArea(&windowX, &windowY, &windowW, &windowH, true) {
      return
    }

    Sleep(200)
    SendKey('x')
    Sleep(100)
    RestoreForegroundWindow(previousHwnd)
    RunningStatus.lastGatherTick := A_TickCount
  }
}


; esc退出战斗
exitCombat(windowX := "", windowY := "", windowW := "", windowH := "") {
  if (windowX = "" || windowY = "" || windowW = "" || windowH = "") {
    if !GetGameClientArea(&windowX, &windowY, &windowW, &windowH) {
      return
    }
  }

  if !isItInNormalCondition(windowX, windowY, windowW, windowH) {
    if !CanRunAction(RunningStatus.lastRunawayTick, Config.runawayActionCooldownMs) {
      return
    }

    previousHwnd := CaptureForegroundWindow(GetGameHwnd())
    if !GetGameClientArea(&windowX, &windowY, &windowW, &windowH, true) {
      return
    }

    Sleep(200)
    SendKey('Esc')
    Sleep(400)

    foundPrecisePoint := FindRunawayButtonClickPoint(windowX, windowY, windowW, windowH, &clickX, &clickY)
    if foundPrecisePoint {
      AddLog("开始执行逃跑操作")
    } else {
      AddLog("未精确命中逃跑按钮, 使用自适应坐标兜底")
    }

    Click(clickX, clickY)
    Sleep(120)
    RestoreForegroundWindow(previousHwnd)
    RunningStatus.lastRunawayTick := A_TickCount
  }
}

; 获取血条状态 return 0: 未发现血条 1:健康 2:受伤 3:濒危
getHealthBarColor(windowX := "", windowY := "", windowW := "", windowH := "") {
  if (windowX = "" || windowY = "" || windowW = "" || windowH = "") {
    if !GetGameClientArea(&windowX, &windowY, &windowW, &windowH) {
      return 0
    }
  }

  ; x起始点和终点
  startX := Round(windowX)
  endX := Round(windowX + windowW * 0.15)
  ; y起始点和终点
  startY := Round(windowY)
  endY := Round(windowY + windowH * 0.1)
  if PixelSearch(&x_, &y_, startX, startY, endX, endY, HealthBarColor1, Config.uiColorTolerance) {
    return 1
  } else if PixelSearch(&x_, &y_, startX, startY, endX, endY, HealthBarColor2, Config.uiColorTolerance) {
    return 2
  } else if PixelSearch(&x_, &y_, startX, startY, endX, endY, HealthBarColor3, Config.uiColorTolerance) {
    return 3
  }

  return 0
}

; 检查是否处于大世界状态
isItInNormalCondition(windowX := "", windowY := "", windowW := "", windowH := "") {
  if (windowX = "" || windowY = "" || windowW = "" || windowH = "") {
    if !GetGameClientArea(&windowX, &windowY, &windowW, &windowH) {
      return false
    }
  }

  startX := Round(windowX)
  startY := Round(windowY)
  endX := Round(windowX + windowW * 0.1)
  endY := Round(windowY + windowH * 0.1)

  if PixelSearch(&_, &_, startX, startY, endX, endY, 0x64d1fd, Config.uiColorTolerance)
    && PixelSearch(&_, &_, startX, startY, endX, endY, 0xffc65f, Config.uiColorTolerance)
    && PixelSearch(&_, &_, startX, startY, endX, endY, 0x2469ba, Config.uiColorTolerance) {
    return true
  }
  return false
}


; 发送按键事件
SendKey(str, time := 50) {
  Send("{" str " down}")
  Sleep(time)
  Send("{" str " up}")
  return true
}


; 添加日志
AddLog(msg) {

  if !HasProp(AddLog, "lines")
    AddLog.lines := []

  ; 当前日志带时间
  newLine := FormatTime(, "HH:mm:ss") " " msg
  isHandHoldingResult := InStr(msg, "牵手检测结果:") ? true : false

  if (AddLog.lines.Length > 0) {
    last := AddLog.lines[AddLog.lines.Length]

    if (last = newLine) {
      return
    }
    else if (!isHandHoldingResult && InStr(last, msg)) {
      AddLog.lines[AddLog.lines.Length] := newLine
    }
    else {
      AddLog.lines.Push(newLine)
    }
  }
  else {
    AddLog.lines.Push(newLine)
  }

  ; === 限制12行 ===
  if (AddLog.lines.Length > 12)
    AddLog.lines.RemoveAt(1)

  ; === 重绘 ===
  UIClass.logBox.Value := ""
  for line in AddLog.lines
    UIClass.logBox.Value .= line "`r`n"

  ; 滚动到底部
  SendMessage(0x115, 7, 0, UIClass.logBox.Hwnd)
}


; 清空当前日志
clearLog() {
  ; 1. 清空UI
  UIClass.logBox.Value := ""

  ; 2. 清空缓存队列（关键）
  AddLog.lines := []
}
