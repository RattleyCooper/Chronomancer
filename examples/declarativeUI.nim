# Declarative UI elements with local state
# and lifetime bound to behavior.

import chronomancer
import vmath
import nico
import macros

let orgName = "RattleyCooper"
let appName = "Declarative UI with Chronomancer"

var ui* = newChronomancer(fps=120)
var mousePos* = ivec2(0, 0)

type
  Box* = ref object
    x*, y*, w*, h*, ox*, oy*: int

proc newBox*(x, y, w, h: int): Box =
  result.new()
  result.x = x
  result.y = y
  result.w = w
  result.h = h

proc contains*(b: Box, v: IVec2): bool =
  let (x, y) = (v.x, v.y)
  if x < b.x: false
  elif x > b.x + b.w: false
  elif y < b.y: false
  elif y > b.y + b.h: false
  else: true

proc closeRange(r: Chronomancer, first: int, last: int) =
  for i in first..last:
    r.cancel(i)

template close*(r: Chronomancer): untyped =
  r.closeRange(firstId, lastId)

template close*(r: Chronomancer, body: untyped): untyped =
  r.closeRange(firstId, lastId)
  body

template closeSelf*(r: Chronomancer): untyped =
  r.cancel(teardownIds)

template closeSelf*(r: Chronomancer, body: untyped): untyped =
  r.cancel(teardownIds)
  body

template closeable*(r: Chronomancer, body: untyped): untyped =
  # Create panels with 
  block:
    var firstId {.inject.} = r.callbackId()
    var lastId {.inject.} = -1
    body
    lastId = r.callbackId() - 1

# Update Mouse
ui.run every(1) do():
  let mp = mouse()
  mousePos.x = mp[0]
  mousePos.y = mp[1]

macro box*(r: Chronomancer, b: Box, mbtn: range[0..2], body: untyped): untyped =
  # We create empty nodes for the logic
  var onHover = newStmtList()
  var onExit = newStmtList()
  var onClick = newStmtList()
  var onHold = newStmtList()
  var onRelease = newStmtList()
  var onInside = newStmtList()
  var onOutside = newStmtList()
  var scopedCode = newStmtList()
  var draw = newStmtList()
  var logic = newStmtList()
  var child = newStmtList()
  result = newStmtList()

  for stmt in body:
    if stmt.kind in {nnkCall, nnkCommand}:
      let label = stmt[0].strVal
      let code = stmt[1]
      case label
      of "hover": onHover = code
      of "exit": onExit = code
      of "click": onClick = code
      of "hold": onHold = code
      of "release": onRelease = code
      of "inside": onInside = code
      of "outside": onOutside = code
      of "scoped": scopedCode.add code
      of "draw": draw.add code
      of "child": child.add code

  var td = ident("teardownIds")
  let theBox = ident("box")
  let drag = ident("dragging")

  if scopedCode.len != 0:
    logic.add quote do:
      `scopedCode`

  logic.add quote do:
    var `td` = (-1, -1, -1, -1, -1)
    var `drag` = false

  if onHover.len != 0 and onExit.len != 0:
    logic.add quote do:
      `td`[0] = `r`.callbackId()
      # 1. Handle Hover/Exit (State Mode)
      `r`.mode `b`.contains(mousePos):
        `onHover`
      do:
        `onExit`

  if onClick.len != 0:
    logic.add quote do:
      `td`[1] = `r`.callbackId()
      # 2. Handle Click (Event Pulse)
      `r`.while (`b`.contains(mousePos)):
        if mousebtnp(`mbtn`): # Only detects single click
          `onClick`
      do: discard

  if onInside.len != 0 and onOutside.len != 0:
    logic.add quote do:
      `td`[3] = `r`.callbackId()
      `r`.while `b`.contains(mousePos) or `drag`:
        `onInside`
      do: `onOutside`

  if onHold.len != 0 and onRelease.len != 0:
    logic.add quote do:
      `td`[2] = `r`.callbackId()
      `r`.while (`b`.contains(mousePos) and mousebtn(`mbtn`)):
        `onHold`
      do: 
        `onRelease`
        `drag` = false

  if draw.len != 0:
    logic.add quote do:
      `td`[4] = `r`.callbackId()
      `r`.run every(1) do():
        let `theBox` = `b`
        `draw`

  result.add quote do:
    block:
      `logic`
      `child`

  echo result.repr


let mainPanel = Box(
  x: 50, y: 50,
  w: 100, h: 100
)

let closeButton = Box(
  x: 0, y: 0,
  w: 30, h: 30
)

ui.closeable: 
  ui.box(mainPanel, 0):
    scoped:
      var cornerx = mainPanel.x + mainPanel.w
      var cornery = mainPanel.y + mainPanel.h
      var grabOffset = ivec2(0, 0)
    hold:
      dragging = true
      grabOffset = mousePos - ivec2(mainPanel.x, mainPanel.y)
    release:
      discard
    inside:
      if dragging:
        mainPanel.x = mousePos.x - grabOffset.x
        mainPanel.y = mousePos.y - grabOffset.y
    outside:
      discard
    draw:
      cornerx = mainPanel.x + mainPanel.w
      cornery = mainPanel.y + mainPanel.h
      setColor(66)
      rectfill(mainPanel.x, mainPanel.y, cornerx, cornery)

    child:
      ui.box(closeButton, 0):
        scoped:
          closeButton.x += mainPanel.x
          closeButton.y += mainPanel.y
          var cornerx = closeButton.x + closeButton.w
          var cornery = closeButton.y + closeButton.h
          var color = 27
          setColor(color)
        draw:
          closeButton.x = mainPanel.x + closeButton.ox
          closeButton.y = mainPanel.y + closeButton.oy
          cornerx = closeButton.x + closeButton.w
          cornery = closeButton.y + closeButton.h
          setColor(color)
          rectfill(closeButton.x, closeButton.y, cornerx, cornery)
        hover:
          color = 30
        exit:
          color = 27
        click:
          ui.close

proc gameInit() =
  discard

proc gameUpdate(dt: float32) =
  ui.tick()

proc gameDraw() =
  cls()

nico.init(orgName, appName)
nico.createWindow(appName, 128, 128, 4, false)
nico.run(gameInit, gameUpdate, gameDraw)

