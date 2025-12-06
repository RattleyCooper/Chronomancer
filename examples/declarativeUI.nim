# Declarative UI elements with local state
# and lifetime bound to behavior.

import chronomancer
import vmath
import nico
import macros

const orgName = "RattleyCooper"
const appName = "Declarative UI Example"

var ui* = newChronomancer(fps=120)
var mousePos* = ivec2(0, 0)

type
  Box* = ref object
    x*, y*, w*, h*: int

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
  var logic = newStmtList()
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
      of "child":
        logic.add quote do:
          `code`

  var td = ident("teardownIds")

  if scopedCode.len != 0:
    logic.add quote do:
      `scopedCode`

  logic.add quote do:
    var `td` = (-1, -1, -1, -1)

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

  if onHold.len != 0 and onRelease.len != 0:
    logic.add quote do:
      `td`[2] = `r`.callbackId()
      `r`.while (`b`.contains(mousePos) and mousebtn(`mbtn`)):
        `onHold`
      do: `onRelease`

  if onInside.len != 0 and onOutside.len != 0:
    logic.add quote do:
      `td`[3] = `r`.callbackId()
      `r`.while `b`.contains(mousePos):
        `onInside`
      do: `onOutside`

  result.add quote do:
    block:
      `logic`

  echo result.repr


let mainPanel = Box(
  x: 50, y: 50,
  w: 100, h: 100
)

let feedButton = Box(
  x: 10, y: 10,
  w: 10, h: 10
)

let cleanButton = Box(
  x: 0, y: 0,
  w: 30, h: 30
)

ui.closeable:
  ui.box(mainPanel, 0):
    scoped:
      # Set up main panel
      discard
    hover:
      echo "In Panel"
    exit:
      echo "Out of panel"
    child:
      ui.box(feedButton, 0):
        scoped:
          var dragging = false
          feedButton.x += mainPanel.x
          feedButton.y += mainPanel.y
        child:
          ui.box(cleanButton, 0):
            hover:
              echo "in clean"
            exit:
              echo "out clean"
            click:
              echo "clean button clicked"
              ui.close:
                echo "Closed all"
        hover:
          echo "Mouse Entered"
          dragging = true
          echo dragging
        exit:
          echo "Mouse Exited"
          dragging = false
        click:
          echo "Mouse Clicked"
          ui.closeSelf:
            echo "Closed"

proc gameInit() =
  discard

proc gameUpdate(dt: float32) =
  ui.tick()

proc gameDraw() =
  cls()

nico.init(orgName, appName)
nico.createWindow(appName, 128, 128, 4, false)
nico.run(gameInit, gameUpdate, gameDraw)

