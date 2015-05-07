# Description:
#   A Tic-Tac-Toe Game Engine for Hubot
#
# Commands:
#   hubot ttt help - Show help of the TicTacToe game
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

Room = (name, creator) ->
  @name = name
  @creator = creator
  @opponent = null
  @game = null
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

GameManager::isNextFirstHand = ->
    return @nextX

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
  @renderer.setMsg(msg)
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

Room::getCreator = ->
    return @creator

Room::getOpponent = ->
    return @opponent

Room::getGame = ->
    return @game

Room::startWithOpponent = (msg, opponent) ->
    @opponent = opponent
    hubotRenderer = new Renderer()
    hubotRenderer.setMsg msg
    @game = new GameManager(3, hubotRenderer)

Room::mark = (position, msg) ->
    name = getUserName(msg)
    if (name == @creator and @game.isNextFirstHand()) or (name == @opponent and not @game.isNextFirstHand())
        @game.mark(position, msg)
        return

    if name == @creator
        othername = @opponent
    else
        othername = @creator

    msg.send "It's not your turn! Please wait for #{othername} `s move"
    return

getGameKey = (msg) ->
    return "TTTGame" + getUserName(msg)

getRoomKey = (name) ->
    return "TTTRoom" + name

getRoomGameKey = (name) ->
    return "TTTRoomGame" + name

getBotGameKey = (msg) ->
    return "TTTBotGame" + getUserName(msg)

getUserName = (msg) ->
  if msg.message.user.mention_name?
    msg.message.user.mention_name
  else
    msg.message.user.name

sendHelp = (robot, msg) ->
  prefix = robot.alias or robot.name
  msg.send "===Help for ttt, a Tic-Tac-Toe Game==="
  msg.send "#{prefix} ttt me start - Start a game of Tic-Tac-Toe VS #{getUserName(msg)}"
  msg.send "#{prefix} ttt me <number> - Mark the Cell"
  msg.send "#{prefix} ttt me restart - Restart the current game of Tic-Tac-Toe"
  msg.send "#{prefix} ttt me stop - Stop the current game of Tic-Tac-Toe"
  msg.send "#{prefix} ttt room create <name> - Create a Game Room & wait for the opponent"
  msg.send "#{prefix} ttt room join <name> - Join a Game Room & start the game"
  msg.send "#{prefix} ttt room <number> - Mark the Cell"
  msg.send "#{prefix} ttt room stop - Stop the current game of Tic-Tac-Toe"
  msg.send "#{prefix} ttt bot start - Start a game of Tic-Tac-Toe VS #{prefix}"
  msg.send "#{prefix} ttt bot <number> - Mark the Cell"
  msg.send "#{prefix} ttt bot restart - Restart the current game of Tic-Tac-Toe"
  msg.send "#{prefix} ttt bot stop - Stop the current game of Tic-Tac-Toe"
  msg.send "Number: 1 2 3"
  msg.send "Number: 4 5 6"
  msg.send "Number: 7 8 9"
  msg.send "Name:[a-zA-Z0-9]+"
  msg.send "===END==="


module.exports = (robot) ->

  robot.respond /ttt help/i, (msg) ->
    sendHelp robot, msg

  robot.respond /ttt me start/i, (msg) ->
    gameManager = robot.brain.get(getGameKey(msg))

    unless gameManager?
      msg.send "#{getUserName(msg)} has started a game of Tic-Tac-Toe VS #{getUserName(msg)}"
      hubotRenderer = new Renderer()
      hubotRenderer.setMsg msg
      gameManager = new GameManager(3, hubotRenderer)
      robot.brain.set(getGameKey(msg), gameManager)
      robot.brain.save()
    else
      msg.send "Tic-Tac-Toe game already in progress."
      sendHelp robot, msg

  robot.respond /ttt me ([1-9])/i, (msg) ->

    cellNum = parseInt(msg.match[1],10)
    position =
         x: Math.floor((cellNum - 1) / 3)
         y: (cellNum - 1) % 3

    gameManager = robot.brain.get(getGameKey(msg))
    unless gameManager?
      msg.send "No Tic-Tac-Toe game in progress."
      sendHelp robot, msg
      return

    gameManager.mark(position, msg)

  robot.respond /ttt me restart/i, (msg) ->
    gameManager = robot.brain.get(getGameKey(msg))
    unless gameManager?
      msg.send "No Tic-Tac-Toe game in progress."
      sendHelp robot, msg
      return

    msg.send "#{getUserName(msg)} has started a game of Tic-Tac-Toe VS #{getUserName(msg)}"
    gameManager.setup()

  robot.respond /ttt me stop/i, (msg) ->
    robot.brain.set(getGameKey(msg), null)
    robot.brain.save()

    msg.send "#{getUserName(msg)} has stopped a game of Tic-Tac-Toe."

  robot.respond /ttt room create ([a-zA-Z0-9]+)/i, (msg) ->
      name = msg.match[1]
      roomkey = getRoomKey(name)
      room =  robot.brain.get(roomkey)
      unless room?
         room = new Room(name, getUserName(msg))
         robot.brain.set(roomkey, room)
         robot.brain.save()
         msg.send "#{getUserName(msg)} created a Room:#{name}"
         msg.send "Input `ttt room join #{name}` to join the room"
         return
      else
         msg.send "This room has already be created, please try another one or join it"
         sendHelp robot, msg
         return

  robot.respond /ttt room join ([a-zA-Z0-9]+)/i, (msg) ->
      name = msg.match[1]
      roomkey = getRoomKey(name)
      room = robot.brain.get(roomkey)
      unless room?
          msg.send "Room not exists, please try another one or create by yourself"
          sendHelp robot, msg
          return
      else
          msg.send "Game started: #{room.creator} VS #{getUserName(msg)}"
          msg.send "#{room.creator}: X"
          msg.send "#{getUserName(msg)}: O"
          room.startWithOpponent(msg, getUserName(msg))
          robot.brain.set(roomkey, null)
          robot.brain.set(getRoomGameKey(room.getCreator()), room)
          robot.brain.set(getRoomGameKey(room.getOpponent()), room)
          robot.brain.save()
          return

  robot.respond /ttt room ([1-9])/i, (msg) ->

      cellNum = parseInt(msg.match[1],10)
      position =
            x: Math.floor((cellNum - 1) / 3)
            y: (cellNum - 1) % 3

      room = robot.brain.get(getRoomGameKey(getUserName(msg)))
      unless room?
        msg.send "No Tic-Tac-Toe Room Game in progress."
        sendHelp robot, msg
        return

      room.mark(position, msg)
      return

  robot.respond /ttt room stop/i, (msg) ->
      username = getUserName(msg)
      room = robot.brain.get(getRoomGameKey(username))
      if room
          robot.brain.set(getRoomGameKey(username), null)

          if username == room.getCreator()
              robot.brain.set(getRoomGameKey(room.getOpponent()), null)
          else
              robot.brain.set(getRoomGameKey(room.getCreator()), null)

          robot.brain.save()

      msg.send "#{getUserName(msg)} has stopped a Room Game of Tic-Tac-Toe."
