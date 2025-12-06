# A simulation of warehouse dynamics and perverse quota incentives.
# Simulation assumes 1 tick = 15 seconds, so 4 ticks = 1 minute.
# Workers can be lazy, and even "snipe" the most efficient orders
# making them appear more productive, even if they're wasting 
# the most time.
#
#

import ../src/chronomancer
import std/random, strformat

randomize()
var r = initRand()
var clock = newChronomancer(fps=60*4)
var ticks = 0
var hrs8 = 1920

type
  Task = enum
    tIdle, tAssigning, tPicking, tTalking, tStaging

  Order = ref object
    picks: Mutable[int]
    avgTTP: Mutable[int]
    total: Mutable[int]

  Worker = ref object
    name: Mutable[string]
    walkTime: Mutable[int]
    pickTime: Mutable[int]
    totalPicked: Mutable[int]
    totalOrders: Mutable[int]
    talkTime: Mutable[int]
    talking: Mutable[bool]
    hasTask: Mutable[bool]
    action: Mutable[Task]
    statsPicked: Mutable[int]
    previousAction: Mutable[Task]
    currentOrder: Order
    laziness: Mutable[int]
    snipesOrders: Mutable[bool]
    triage: Mutable[bool]
    efficiency: Mutable[int]
    orderHistory: Mutable[seq[Order]]
    breakTime: Mutable[int]

proc smallFastOrder(amount: int): seq[Order] =
  for i in 1..amount:
    result.add Order(
      picks: Mutable[int](value: r.rand(1..15)),
      avgTTP: Mutable[int](value: r.rand(1..4))
    )
    result[i-1].total = mutable result[i-1].picks.value

proc smallSlowOrder(amount: int): seq[Order] =
  for i in 1..amount:
    result.add Order(
      picks: Mutable[int](value: r.rand(1..15)),
      avgTTP: Mutable[int](value: r.rand(4*2..4*4))
    )
    result[i-1].total = mutable result[i-1].picks.value

proc mediumFastOrder(amount: int): seq[Order] =
  for i in 1..amount:
    result.add Order(
      picks: Mutable[int](value: r.rand(16..30)),
      avgTTP: Mutable[int](value: r.rand(1..4))
    )
    result[i-1].total = mutable result[i-1].picks.value

proc mediumSlowOrder(amount: int): seq[Order] =
  for i in 1..amount:
    result.add Order(
      picks: Mutable[int](value: r.rand(16..30)),
      avgTTP: Mutable[int](value: r.rand(4*2..4*4))
    )
    result[i-1].total = mutable result[i-1].picks.value

proc largeFastOrder(amount: int): seq[Order] =
  for i in 1..amount:
    result.add Order(
      picks: Mutable[int](value: r.rand(31..70)),
      avgTTP: Mutable[int](value: r.rand(1..4))
    )
    result[i-1].total = mutable result[i-1].picks.value

proc largeSlowOrder(amount: int): seq[Order] =
  for i in 1..amount:
    result.add Order(
      picks: Mutable[int](value: r.rand(31..70)),
      avgTTP: Mutable[int](value: r.rand(4..4*4))
    )
    result[i-1].total = mutable result[i-1].picks.value

proc createWorkers(amount: int = 4): seq[Worker] =
  for i in 1..amount:
    var history: Mutable[seq[Order]] = mutable @[Order()]
    result.add Worker(
      name: mutable("na"),
      action: mutable tIdle,
      previousAction: mutable tIdle,
      statsPicked: mutable 0,
      laziness: mutable 1,
      totalPicked: mutable 0,
      totalOrders: mutable 0,
      currentOrder: Order(picks: mutable 0, avgTTP: mutable 0, total: mutable 0),
      snipesOrders: mutable false,
      efficiency: mutable 1,
      triage: mutable false,
      orderHistory: history,
      breakTime: mutable 240
    )

proc makeOrders(): seq[Order] =
  result.add smallFastOrder(40)
  result.add smallSlowOrder(4)
  result.add mediumFastOrder(8)
  result.add mediumSlowOrder(2)
  result.add largeFastOrder(2)
  result.add largeSlowOrder(1)

var workers = createWorkers(10)
var orders = makeOrders()
orders.shuffle()
echo orders.len
let quota = 128

proc snipeBestOrder(w: Worker): Order =
  # Take larger, faster orders.
  var bestScore = -1.0
  var bestIdx = -1

  for i, o in orders:
    let score = float(o.picks.value) / float(o.avgTTP.value)
    if score > bestScore:
      bestScore = score
      bestIdx = i

  result = orders[bestIdx]
  orders.del(bestIdx)

proc triageOrder(w: Worker): Order =
  # Take smaller, slower orders.
  var bestScore = -1.0
  var bestIdx = -1

  for i, o in orders:
    let score = float(o.avgTTP.value) / float(o.picks.value)
    if score > bestScore:
      bestScore = score
      bestIdx = i

  result = orders[bestIdx]
  orders.del(bestIdx)

proc assignBrain(w: Worker) =
  # Idle state. 30 seconds of walking to a computer
  clock.mode (w.action.value == tIdle and orders.len > 0):
    clock.run after(2 * w.laziness.value) do():
      w.action.value = tAssigning
  do: w.previousAction.value = w.action.value

  # Assigning -> around 1 minutes to log on, 
  # find an order, assign it and print labels.
  clock.mode w.action.value == tAssigning:
    clock.run after(4 * w.laziness.value) do():
      if orders.len > 0:
        if w.triage.value:
          if r.rand(1.0) > 0.60:
            w.currentOrder = w.triageOrder()
          else:
            w.currentOrder = orders.pop()
        elif w.snipesOrders.value:
          if r.rand(1.0) > 0.25:
            w.currentOrder = w.snipeBestOrder()
          else:
            w.currentOrder = orders.pop()
        else:
          w.currentOrder = orders.pop()
        w.action.value = tPicking
      else:
        w.action.value = tIdle
  do:
    w.previousAction.value = w.action.value

  # Picking -> Use average time to pick to simulate 
  # difficult items that take longer. Difference 
  # between a fast and a slow order.
  clock.cooldown (w.currentOrder.picks.value > 0), w.currentOrder.avgTTP.value:
    var pickPT = 1 + w.efficiency.value
    if pickPT > w.currentOrder.picks.value:
      pickPT = w.currentOrder.picks.value
    w.currentOrder.picks.value -= pickPt
    w.statsPicked.value += pickPT
    w.totalPicked.value += pickPT

  # Picking -> Change state when no picks are left.
  clock.mode w.action.value == tPicking:
    clock.latch w.currentOrder.picks.value == 0:
      w.action.value = tStaging
  do: w.previousAction.value = w.action.value

  # Staging -> Process the time it takes to stage an order.
  # this is based on a (fixed rate * worker laziness) + the
  # averate time to pick an item. Longer to pick == longer
  # to stage (build pallet, wrap pallet, bundle items, etc.)
  let cdVal = ((1 * w.laziness.value) + w.currentOrder.avgTTP.value)
  let cooldownVal = max(cdVal - w.efficiency.value, 1)
  clock.cooldown (w.action.value == tStaging and w.statsPicked.value > 0), cooldownVal:
    w.statsPicked.value -= 1
    if w.statsPicked.value <= 0 and w.action.value == tStaging:
      w.previousAction.value = w.action.value
      if w.totalPicked.value >= quota:
        w.action.value = tTalking
      else:
        w.action.value = tIdle
      w.statsPicked.value = 0
      w.totalOrders.value += 1
      w.orderHistory.value.add w.currentOrder

  # Talking -> Once workers meet their quota they might 
  # stop working to chat for extended periods of time.
  clock.mode w.action.value == tTalking:
    clock.run after(8 * w.laziness.value) do():
      # Go back to picking (or Staging if they finished right before talking)
      w.action.value = tIdle
  do: discard

  # Increase worker laziness once the quota is hit.
  clock.latch w.totalPicked.value >= quota:
    w.laziness.value += w.laziness.value

proc setupSim(c: int) =
  let i = c
  var mcNames = @[
    "J", "A", "L", "R", "P", "M", "D", "J2", "D2", "E"
  ]
  workers[i].name.value = mcNames[i]
  let name = workers[i].name.value

  if name == "J":
    workers[i].laziness.value = 3
    workers[i].snipesOrders.value = true
  elif name == "D":
    workers[i].laziness.value = 2
    workers[i].snipesOrders.value = true
  elif name == "D2":
    workers[i].efficiency.value = 4
  elif name == "A":
    workers[i].laziness.value = 1
    workers[i].efficiency.value = 2
  elif name == "P":
    workers[i].laziness.value = 2
    workers[i].efficiency.value = 3
    workers[i].triage.value = true
  elif name == "J2":
    workers[i].laziness.value = 1

  let state = workers[i].action
  let pstate = workers[i].previousAction
  clock.reactVar workers[i].action.value:
    echo fmt"{name} state changed to {pstate.value}->{state.value}"

  workers[i].assignBrain()

for i in 0..workers.high:
  setupSim(i)

clock.reactvar orders.len:
  echo orders.len

clock.run every(1) do():
  ticks += 1

clock.time.scale.value = 3.0

while orders.len > 0 and ticks != hrs8:
  clock.tick()

for i in 0..workers.high:
  let name = workers[i].name.value
  let picked = workers[i].totalPicked.value
  let orders = workers[i].totalOrders.value
  echo fmt"{name} picked {picked} items and completed {orders} orders"
  for c in 1..workers[i].orderHistory.value.high:
    var s = workers[i].orderHistory.value
    var o = s[c]
    echo fmt"  Order #{c} - Picks: {o.total.value} | AvgTTP: {o.avgTTP.value} | Efficiency: {float(o.total.value) / float(o.avgTTP.value)}"


var picksLeft = 0
for i in 0..workers.high:
  picksLeft += workers[i].currentOrder.picks.value

var ordersLeft = 0
for i in 0..workers.high:
  if workers[i].currentOrder.picks.value > 0:
    ordersLeft += 1

echo ""
if picksLeft == 0:
  echo "Finished Before EOD."
  let minLeft = (hrs8 - ticks) div 4
  echo fmt"{minLeft} minutes left"
  echo fmt"{orders.len} orders left"
else:
  echo fmt"Workload too high! {ordersLeft} left!"
  echo fmt"{picksLeft} remaining picks."

