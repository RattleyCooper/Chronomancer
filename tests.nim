import src/reactick
import unittest2

type 
  TestObj = ref object
    value: int

var clock = ReacTick(fps:60)

proc newTestObj(): TestObj =
  result.new()
  result.value = 0

echo "Starting tests."
var runEvery = newTestObj()
var runAfter = newTestObj()
var scheduleEvery = newTestObj()
var scheduleAfter = newTestObj()
var watchEvery = newTestObj()
var watchAfter = newTestObj()
var whenEvery = newTestObj()
var whenAfter = newTestObj()
var watchEveryC = newTestObj()
var watchAfterC = newTestObj()
var whenEveryC = newTestObj()
var whenAfterC = newTestObj()

suite "Run":
  test "Every":
    # --- Run Every ---
    clock.run every(1) do():
      runEvery.value += 1

    clock.tick()
    assert clock.multiShots.len == 1
    assert runEvery.value == 1

  test "After":
    # --- Run After ---
    clock.run after(1) do():
      runAfter.value += 1

    assert clock.oneShots.len == 1
    clock.tick(false)
    assert runAfter.value == 1
    assert clock.oneShots.len == 0

suite "Schedule":
  test "Every":
    # --- Schedule Every ---
    let schEv = clock.schedule every(1) do():
      scheduleEvery.value += 1

    assert schEv == 2
    assert clock.multiShots.len == 2
    clock.tick(false)
    assert scheduleEvery.value == 1
    clock.cancel(schEv)
    assert clock.multiShots.len == 1
  
  test "After":
    # --- Schedule After ---
    let schAf = clock.schedule after(1) do():
      scheduleAfter.value += 1

    assert schAf == 3
    assert clock.oneShots.len == 1
    clock.tick(false)
    assert scheduleAfter.value == 1
    clock.cancel(schAf)
    assert clock.oneShots.len == 0

suite "Watch":
  test "Every":
    # --- Watch Every ---
    clock.watch watchEvery.value == 0, every(1) do():
      watchEvery.value += 1

    assert clock.multiShots.len == 2
    # trigger evaluation of condition
    clock.tick(false)
    assert clock.multiShots.len == 3
    assert watchEvery.value == 0
    # trigger callback
    clock.tick(false)
    assert watchEvery.value == 1
  
  test "After":
    # --- Watch After ---
    clock.watch watchAfter.value == 0, after(1) do():
      watchAfter.value += 1

    assert clock.multiShots.len == 4
    # Evaluate condition
    clock.tick(false)
    assert clock.oneShots.len == 1
    assert watchAfter.value == 0
    # trigger callback
    clock.tick(false)
    assert watchAfter.value == 1

suite "When":
  test "Every":
    # --- When Every ---
    clock.when whenEvery.value == 0, every(1) do():
      whenEvery.value += 1

    assert clock.multiShots.len == 4
    # trigger condition / watcher removed.
    clock.tick(false)
    assert clock.multiShots.len == 4
    assert whenEvery.value == 0
    # trigger callback
    clock.tick(false)
    assert whenEvery.value == 1

  test "After":
    # --- When After ---
    clock.when whenAfter.value == 0, after(1) do():
      whenAfter.value += 1

    assert clock.multiShots.len == 5
    # trigger condition / watcher removed.
    clock.tick(false)
    assert clock.multiShots.len == 4
    assert whenAfter.value == 0
    clock.tick(false)
    assert whenAfter.value == 1

suite "Cancelable Watch":
  test "Every":
    # --- Cancelable Watch Every ---
    clock.cancelable:
      clock.watch watchEveryC.value > -1, every(1) do():
        watchEveryC.value += 1
        clock.cancel()

    assert clock.multiShots.len == 5
    # trigger evaluation of condition
    clock.tick(false)
    assert clock.multiShots.len == 6
    assert watchEveryC.value == 0
    # trigger callback which removes watcher
    clock.tick(false)
    assert watchEveryC.value == 1
    # make sure they're removed
    clock.tick(false)
    clock.tick(false)
    assert clock.multiShots.len == 4
    assert watchEveryC.value == 1

  test "After":
    # --- Cancelable Watch After ---
    clock.cancelable:
      clock.watch watchAfterC.value == 0, after(1) do():
        watchAfterC.value += 1
        clock.cancel()

    assert clock.multiShots.len == 5
    # Evaluate condition
    clock.tick(false)
    assert clock.oneShots.len == 1
    assert watchAfterC.value == 0
    # trigger callback which removes watcher.
    clock.tick(false)
    assert watchAfterC.value == 1
    assert clock.oneShots.len == 0
    # make sure they're removed
    clock.tick(false)
    clock.tick(false)
    assert clock.multiShots.len == 4
    assert clock.oneShots.len == 0
    assert watchAfterC.value == 1

suite "Cancelable When":
  test "Every":
    # --- Cancelable When Every ---
    clock.cancelable:
      clock.when whenEveryC.value == 0, every(1) do():
        whenEveryC.value += 1
        clock.cancel()

    assert clock.multiShots.len == 5
    # trigger condition / watcher removed.
    clock.tick(false)
    assert clock.multiShots.len == 5
    assert whenEveryC.value == 0
    # trigger callback which removes callback
    clock.tick(false)
    assert whenEveryC.value == 1
    assert clock.multiShots.len == 4
    # Make sure they're removed.
    clock.tick(false)
    clock.tick(false)
    assert clock.multiShots.len == 4
    assert whenEveryC.value == 1
  
  test "After":
    # --- Cancelable When After ---
    clock.cancelable:
      clock.when whenAfterC.value == 0, after(1) do():
        whenAfterC.value += 1
        clock.cancel()

    assert clock.multiShots.len == 5
    # trigger condition / watcher removed.
    clock.tick(false)
    assert clock.multiShots.len == 4
    assert clock.oneShots.len == 1
    assert whenAfterC.value == 0
    # trigger callback
    clock.tick(false)
    assert clock.multiShots.len == 4
    assert clock.oneShots.len == 0
    assert whenAfterC.value == 1
    # Make sure it's removed
    clock.tick(false)
    clock.tick(false)
    assert whenAfterC.value == 1


# Run the sim for 5 seconds.
var t = 0
clock.run every(60) do():
  echo t + 1
  t += 1

for i in 0..clock.multiShots.high:
  clock.multiShots[i].frame = 1

assert clock.oneShots.len == 0

echo "Running sim for 5 seconds..."
while t < 5:
  clock.tick()

# Asserts
suite "Ending States":
  test "Clear Callbacks":
    clock.clear()
    assert clock.multiShots.len == 0
    assert clock.oneShots.len == 0

  test "Check Values":
    assert runEvery.value == 328
    assert runAfter.value == 1
    assert scheduleEvery.value == 1
    assert scheduleAfter.value == 1
    assert watchEvery.value == 1
    assert watchAfter.value == 1
    assert whenEvery.value == 319
    assert whenAfter.value == 1
    assert watchEveryC.value == 1
    assert watchAfterC.value == 1
    assert whenEveryC.value == 1
    assert whenAfterC.value == 1