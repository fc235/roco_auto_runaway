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
  static gatherActionCooldownMs := 2200
  static runawayActionCooldownMs := 1500
  static combatColorTolerance := 16
  static uiColorTolerance := 8
  static requiredActionNearbyMatches := 3
}


; 当前运行状态
class RunningStatus {
  ; 是否启动自动聚气/逃跑 0: 关闭 1:自动聚气 2:自动逃跑
  static avoidWarState := 0
  static isInCombat := false
  static lastGatherTick := 0
  static lastRunawayTick := 0
}

; ui实例类
class UIClass {
  static ui := ""
  static targetModeDDL := ""
  static targetValueEdit := ""
  static applyTargetBtn := ""
  static gatherEnergyBtn := ""
  static runAwayBtn := ""
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


; ================== GUI ==================
InitGui() {
  global ui

  ; TraySetIcon("app.ico", 1, true)

  ui := Gui("-Resize -MaximizeBox -MinimizeBox +AlwaysOnTop")
  ui.Title := "洛克王国  自动避战"


  ; --- 不抢焦点 ---
  hwnd := ui.Hwnd
  exStyle := DllCall("GetWindowLongPtr", "Ptr", hwnd, "Int", -20, "Ptr")
  DllCall("SetWindowLongPtr", "Ptr", hwnd, "Int", -20, "Ptr", exStyle | 0x08000000)

  OnMessage(0x21, WM_MOUSEACTIVATE)
  WM_MOUSEACTIVATE(*) {
    return 3  ; MA_NOACTIVATE
  }

  ui.AddText("xm y+15", "目标窗口")

  UIClass.targetModeDDL := ui.AddDropDownList("x+10 yp-3 w80", ["窗口标题", "进程名"])
  if (Config.targetMode = "进程名") {
    UIClass.targetModeDDL.Choose(2)
  } else {
    UIClass.targetModeDDL.Choose(1)
  }

  UIClass.targetValueEdit := ui.AddEdit("x+8 yp w110", Config.targetValue)
  UIClass.applyTargetBtn := ui.AddButton("x+8 yp-1 w50 h23", "应用")
  UIClass.applyTargetBtn.OnEvent("Click", onClickApplyTargetBtn)

  ; --- 按钮 ---
  UIClass.gatherEnergyBtn := ui.AddButton("xm y+18 w100 h30", "自动聚气: 关")
  UIClass.gatherEnergyBtn.OnEvent("Click", onClickGatherEnergyBtn)

  UIClass.runAwayBtn := ui.AddButton("xm y+20 w100 h30", "自动逃跑: 关")
  UIClass.runAwayBtn.OnEvent("Click", onClickRunAwayBtn)

  ; GuiCtrl := ui.AddStatusBar("h30", "运行中...")

  UIClass.logBox := ui.AddEdit("ym x+15 w160 h130 ReadOnly -Border -VScroll -HScroll +Disabled")
  UIClass.logBox.SetFont("s9 c000000", "Consolas")


  ; testBtn := ui.AddButton("xm y+20 w100 h30", "测试按钮")

  ; 设置关闭事件, 关闭gui的时候关闭脚本
  ui.OnEvent("Close", GuiClose)  ; 绑定关闭事件

  GuiClose(*) {
    ExitApp()  ; 点击 X 时退出脚本
  }


  UIClass.ui := ui
  ui.Show("w360 h165 NOACTIVATE")
}


; ================== 入口 ==================
Main() {
  ElevatePrivileges()
  InitGui()
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

ActivateWindowById(hwnd) {
  WinShow("ahk_id " hwnd)
  try windowState := WinGetMinMax("ahk_id " hwnd)
  catch
    windowState := 0

  if (windowState = -1) {
    WinRestore("ahk_id " hwnd)
  }
  Sleep(100)

  WinActivate("ahk_id " hwnd)
  return WinWaitActive("ahk_id " hwnd, , 2)
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

GetActionAreaBounds(windowX, windowY, windowW, windowH, &startX, &startY, &endX, &endY) {
  startX := Round(windowX)
  endX := Round(windowX + windowW * 0.18)
  startY := Round(windowY + windowH * 0.76)
  endY := Round(windowY + windowH)
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
    ; 修改按键文字
    ctrl.Text := "自动聚气: 开"
    UIClass.runAwayBtn.Text := "自动逃跑: 关"
    AddLog("自动聚气已开启")
    StartMonitoring()
    return
  }

  ; 修改一下状态
  RunningStatus.avoidWarState := 0
  ; 修改按键文字
  ctrl.Text := "自动聚气: 关"
  UIClass.runAwayBtn.Text := "自动逃跑: 关"
  StopMonitoring()
  AddLog("自动聚气已关闭")
}

; 自动逃跑
onClickRunAwayBtn(ctrl, *) {
  if RunningStatus.avoidWarState != 2 {
    ; 修改一下状态
    RunningStatus.avoidWarState := 2
    ; 修改按键文字
    ctrl.Text := "自动逃跑: 开"
    UIClass.gatherEnergyBtn.Text := "自动聚气: 关"
    AddLog("自动逃跑已开启")
    StartMonitoring()
    return
  }

  ; 修改一下状态
  RunningStatus.avoidWarState := 0
  ; 修改按键文字
  ctrl.Text := "自动逃跑: 关"
  UIClass.gatherEnergyBtn.Text := "自动聚气: 关"
  StopMonitoring()
  AddLog("自动逃跑已关闭")
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
    if !GetGameClientArea(&windowX, &windowY, &windowW, &windowH, true) {
      return
    }

    Sleep(200)
    SendKey('x')
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

    if !GetGameClientArea(&windowX, &windowY, &windowW, &windowH, true) {
      return
    }

    Sleep(200)
    SendKey('Esc')
    Sleep(400)

    startX := Round(windowX + windowW * 0.45)
    startY := Round(windowY + windowH * 0.6)
    endX := Round(windowX + windowW)
    endY := Round(windowY + windowH)

    if PixelSearch(&x, &y, startX, startY, endX, endY, 0xf4eee1, Config.uiColorTolerance) {
      AddLog("开始执行逃跑操作")
      Click(x, y + 10)
      RunningStatus.lastRunawayTick := A_TickCount
    }
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
}


; 添加日志
AddLog(msg) {

  if !HasProp(AddLog, "lines")
    AddLog.lines := []

  ; 当前日志带时间
  newLine := FormatTime(, "HH:mm:ss") " " msg

  if (AddLog.lines.Length > 0) {
    last := AddLog.lines[AddLog.lines.Length]

    if (last = newLine) {
      return
    }
    else if (InStr(last, msg)) {
      AddLog.lines[AddLog.lines.Length] := newLine
    }
    else {
      AddLog.lines.Push(newLine)
    }
  }
  else {
    AddLog.lines.Push(newLine)
  }

  ; === 限制5行 ===
  if (AddLog.lines.Length > 5)
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
