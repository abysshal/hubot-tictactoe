# Description:
#   A Tic-Tac-Toe Game Engine for Hubot
#
# Commands:
#   hubot ttt start - Start a game of Tic-Tac-Toe
#   hubot ttt <number> - Mark the Cell
#   hubot ttt restart - Restart the current game of Tic-Tac-Toe
#   hubot ttt stop - Stop the current game of Tic-Tac-Toe
#
# Notes:
#   Number Commands:
#     1 |   2   |   3
#     4 |   5   |   6
#     7 |   8   |   9
#
# Author:
#   Hui

Cell = (pos, value) ->
  @x = pos.x
  @y = pos.y
  @value = value or ' '
  return

Grid = (size) ->
  @size = size
  @cells = []
  @build()
  return

GameManager = (size, renderer) ->
  @size = size
  @renderer = renderer
  @setup()
  return

Grid::build = ->
  x = 0
  while x < @size
    row = @cells[x] = []
    y = 0
    while y < @size
      row.push null
      y++
    x++
  return

Grid::availableCells = ->
  cells = []
  @eachCell (x, y, cell) ->
    unless cell
      cells.push
        x: x
        y: y
    return
  return cells

Grid::eachCell = (callback) ->
  x = 0
  while x < @size
    y = 0
    while y < @size
      callback x, y, @cells[x][y]
      y++
    x++
  return

Grid::cellsAvailable = ->
  return !!@availableCells().length

Grid::cellAvailable = (position) ->
  return not @cellOccupied(position)

Grid::cellOccupied = (position) ->
  return !!@cellContent(position)

Grid::cellContent = (position) ->
  if @withinBounds(position)
    return @cells[position.x][position.y]
  else
    return null

Grid::insertCell = (cell) ->
  @cells[cell.x][cell.y] = cell
  return

Grid::withinBounds = (position) ->
  return position.x >= 0 and position.x < @size and position.y >= 0 and position.y < @size

Grid::cellGood = (x, y, value) ->
    unless @cells[x][y] and @cells[x][y].value == value
        return false
    else
        return true

Grid::winWithCell = (cell) ->
    x = cell.x
    y = 0
    flag = true
    while y < @size
        unless @cellGood(x, y, cell.value)
            flag = false
        y++
    if flag
        return true

    x = 0
    y = cell.y
    flag = true
    while x < @size
        unless @cellGood(x, y, cell.value)
            flag = false
        x++
    if flag
        return true

    if cell.x == cell.y
        x = 0
        y = 0
        flag = true
        while x < @size
            unless @cellGood(x, y, cell.value)
                flag = false
            x++
            y = x
    if flag
        return true

    if Math.abs(cell.x - cell.y) == @size - 1 or cell.x == cell.y
        x = 0
        y = @size - 1
        flag = true
        while x < @size
            unless @cellGood(x, y, cell.value)
                flag = false
            x++
            y--
        if flag
            return true

    return false


GameManager::setup = ->
  @grid = new Grid(@size)
  @over = false
  @won = false
  @nextX = true
  @actuate()
  return

GameManager::getRenderer = ->
  return @renderer

GameManager::isGameTerminated = ->
  if @over or @won
    true
  else
    false

GameManager::actuate = ->
  @renderer.render @grid,
    over: @over,
    won: @won,
    terminated: @isGameTerminated(),
    nextX: @nextX
  return

GameManager::mark = (position,msg) ->
  self = this
  if @isGameTerminated()
      msg.send "Game is OVER! Please restart."
      return
  unless @grid.cellAvailable(position)
    msg.send "Cell not available, please try again."
    return
  if @nextX
      newCell = new Cell(position, 'X')
      @nextX = false
  else
      newCell = new Cell(position, 'O')
      @nextX = true
  @grid.insertCell(newCell)
  @actuate()

  if @grid.winWithCell(newCell)
      msg.send "===#{newCell.value} WIN!==="
      @won = true
      return

  unless @grid.cellsAvailable()
      msg.send "===Tie!==="
      @over = true
      return

  return

Renderer = ->
  @msg = undefined

Renderer::setMsg = (msg) ->
  @msg = msg

Renderer::renderHorizontalLine = (length) ->
  self = this
  i = 0
  message = '-'
  while i < length
    message += '--'
    i++
  self.msg.send message

Renderer::render = (grid, metadata) ->
  self = this;
  self.renderHorizontalLine grid.cells.length
  grid.cells.forEach (column) ->
    message = '|'
    column.forEach (cell) ->
      value = if cell then cell.value else ' '
      message += value + '|'
    self.msg.send message
  self.renderHorizontalLine grid.cells.length
  if metadata.nextX
    self.msg.send "Next: X"
  else
    self.msg.send "Next: O"


gameManagerKey = 'TTTGameManager'

getUserName = (msg) ->
  if msg.message.user.mention_name?
    msg.message.user.mention_name
  else
    msg.message.user.name

sendHelp = (robot, msg) ->
  prefix = robot.alias or robot.name
  msg.send "Start Game: #{prefix} ttt start"
  msg.send "Mark Cell: #{prefix} ttt {number}"
  msg.send "Numbers: 1 2 3"
  msg.send "Numbers: 4 5 6"
  msg.send "Numbers: 7 8 9"
  msg.send "Restart Game: #{prefix} ttt restart"
  msg.send "Stop Game: #{prefix} ttt stop"

module.exports = (robot) ->
  robot.respond /ttt start/i, (msg) ->
    gameManager = robot.brain.get(gameManagerKey)

    unless gameManager?
      msg.send "#{getUserName(msg)} has started a game of Tic-Tac-Toe."
      hubotRenderer = new Renderer()
      hubotRenderer.setMsg msg
      gameManager = new GameManager(3, hubotRenderer)
      robot.brain.set(gameManagerKey, gameManager)
      robot.brain.save()
    else
      msg.send "Tic-Tac-Toe game already in progress."
      sendHelp robot, msg

  robot.respond /ttt help/i, (msg) ->
    sendHelp robot, msg

  robot.respond /ttt ([1-9])/i, (msg) ->

    cellNum = parseInt(msg.match[1],10)
    #msg.send "Parsed Number #{cellNum}"
    position =
         x: Math.floor((cellNum - 1) / 3)
         y: (cellNum - 1) % 3

#    msg.send "x:#{position.x}, y:#{position.y}"

    gameManager = robot.brain.get(gameManagerKey)
    unless gameManager?
      msg.send "No Tic-Tac-Toe game in progress."
      sendHelp robot, msg
      return

    hubotRenderer = gameManager.getRenderer()
    hubotRenderer.setMsg msg
    gameManager.mark(position,msg)

  robot.respond /ttt restart/i, (msg) ->
    gameManager = robot.brain.get(gameManagerKey)
    unless gameManager?
      msg.send "No Tic-Tac-Toe game in progress."
      sendHelp robot, msg
      return

    msg.send "#{getUserName(msg)} has started a game of Tic-Tac-Toe."
    gameManager.setup()

  robot.respond /ttt stop/i, (msg) ->
    robot.brain.set(gameManagerKey, null)
    robot.brain.save()

    msg.send "#{getUserName(msg)} has stopped a game of Tic-Tac-Toe."
