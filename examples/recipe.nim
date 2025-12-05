import ../src/reactick
import strformat


var kitchen = newReacTick(fps=30)

# Define different types to create a model for a recipe
type
  RecipeState = enum
    rStarting, rCombineDry, rCombineWet, rMix, rPour, rCooking

  IngredientMeasurement = enum
    whole, cups, tbsp, tspn

  Ingredient = ref object
    name: string
    amount: float
    measurement: IngredientMeasurement
    dry: bool

  Recipe = ref object
    name: string
    cookTime: int
    cookTemp: int
    ingredients: seq[Ingredient]
    state: RecipeState
    previousState: RecipeState
    dryCombined: bool
    wetCombined: bool

  Oven = ref object
    temp: int
    targetTemp: int
    preheated: bool
    contains: Recipe

# Create a recipe for Banana Bread
var bananaBread = Recipe(
  name: "Banana Bread",
  cookTime: 55,
  cookTemp: 350,
  state: rStarting,
  previousState: rStarting,
  dryCombined: false,
  wetCombined: false,
  ingredients: @[
    Ingredient(name: "Banana",          measurement: whole, amount: 3,    dry: false),
    Ingredient(name: "Egg",             measurement: whole, amount: 1,    dry: false),
    Ingredient(name: "Butter",          measurement: cups,  amount: 1/3,  dry: false),
    Ingredient(name: "Sugar",           measurement: cups,  amount: 3/4,  dry: true),
    Ingredient(name: "Baking Soda",     measurement: tspn,  amount: 1.0,  dry: true),
    Ingredient(name: "Salt",            measurement: tspn,  amount: 0.1,  dry: true),
    Ingredient(name: "Vanilla Extract", measurement: tspn,  amount: 1,    dry: false),
  ]
)

var oven = Oven(
  temp: 0,
  targetTemp: bananaBread.cookTemp,
  preheated: false,
  contains: nil
)

# Preheat the oven.
kitchen.cooldown oven.temp != oven.targetTemp, 1:
  if oven.temp == 0:
    echo fmt"Preheating oven to {oven.targetTemp}"
  oven.temp += 1
  if oven.temp == oven.targetTemp:
    echo fmt"Oven preheated to {oven.targetTemp}F"

# To start the recipe we'll start combining dry ingredients.
kitchen.when bananaBread.state == rStarting, after(60) do():
  # Switch to the "Combining Dry State"
  bananaBread.previousState = bananaBread.state
  bananaBread.state = rCombineDry

# Combine Dry
kitchen.when bananaBread.state == rCombineDry, after(60) do():
  # Switch to the "Combining Dry State"
  bananaBread.previousState = bananaBread.state
  bananaBread.state = rCombineWet

  echo "\nCombining Dry!"
  for c, ingredient in bananaBread.ingredients:
    if ingredient.dry:
      echo fmt"Combining {ingredient.amount} {ingredient.measurement} {ingredient.name}"
  bananaBread.dryCombined = true
  echo "Dry ingredients combined"

# Combine wet.
kitchen.when bananaBread.state == rCombineWet, after(60) do():
  bananaBread.previousState = bananaBread.state
  bananaBread.state = rMix
  echo "\nCombining Wet!"
  for ingredient in bananaBread.ingredients:
    if not ingredient.dry:
      echo fmt"Combining {ingredient.amount} {ingredient.measurement} {ingredient.name}"
  echo "Wet ingredients combined"
  bananaBread.wetCombined = true

# Start mixing
kitchen.when bananaBread.state == rMix, after(60) do():
  echo "\nStart mixing!"
  bananaBread.previousState = bananaBread.state
  bananaBread.state = rPour
  echo "Dry/wet ingredients mixed!"

# Start pouring the mix
kitchen.when bananaBread.state == rPour, after(60) do():
  echo "\nStart Pouring!"
  bananaBread.previousState = bananaBread.state
  bananaBread.state = rCooking
  echo "Mix is poured"

# Put banana bread in the oven.
kitchen.when oven.temp >= oven.targetTemp, after(60) do():
  echo "\nPlacing banana bread in the oven!"
  oven.contains = bananaBread

# Wait until oven is preheated and oven contains a recipe.
# Then start cooking.
kitchen.watch oven.temp >= oven.targetTemp and oven.contains != nil, every(1) do():
  bananaBread.cookTime -= 1
  if bananaBread.cookTime == 0:
    echo fmt"{bananaBread.name} is done!"

while true:
  kitchen.tick()

