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

BotGame = (botFirst) ->
    @botFirst = botFirst
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

Grid::rows = ->
    rows = []

    x = 0
    while x < @size
        row = []
        y = 0
        while y < @size
            @pushNotNullCell(x, y, row)
            y++
        rows.push row
        x++

    y = 0
    while y < @size
        row = []
        x = 0
        while x < @size
            @pushNotNullCell(x, y, row)
            x++
        rows.push row
        y++

    x = 0
    y = 0
    row = []
    while x < @size
        @pushNotNullCell(x, y, row)
        x++
        y = x
    rows.push row

    x = 0
    y = @size - 1
    row = []
    while x < @size
        @pushNotNullCell(x, y, row)
        x++
        y--
    rows.push row

    return rows

Grid::pushNotNullCell = (x, y, row) ->
    if @cells[x][y]
        row.push @cells[x][y]
    else
        cell =
            x: x
            y: y
            value: ' '
        row.push cell

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

Grid::removeCell = (cell) ->
    @cells[cell.x][cell.y] = null
    return

Grid::withinBounds = (position) ->
  return position.x >= 0 and position.x < @size and position.y >= 0 and position.y < @size

Grid::cellGood = (x, y, value) ->
    unless @cells[x][y] and @cells[x][y].value == value
        return false
    else
        return true

Grid::getGoodCellRows = (cell, goodCount) ->
    rows = []

    x = cell.x
    y = 0
    count = 0
    row = []
    while y < @size
        if @cellGood(x, y, cell.value)
            count++
        @pushNotNullCell(x, y, row)
        y++
    if count == goodCount
        rows.push row

    x = 0
    y = cell.y
    count = 0
    row = []
    while x < @size
        if @cellGood(x, y, cell.value)
            count++
        @pushNotNullCell(x, y, row)
        x++
    if count == goodCount
        rows.push row

    if cell.x == cell.y
        x = 0
        y = 0
        count = 0
        row = []
        while x < @size
            if @cellGood(x, y, cell.value)
                count++
            @pushNotNullCell(x, y, row)
            x++
            y = x
        if count == goodCount
            rows.push row

    if Math.abs(cell.x - cell.y) == @size - 1 or cell.x == cell.y
        x = 0
        y = @size - 1
        count = 0
        row = []
        while x < @size
            if @cellGood(x, y, cell.value)
                count++
            @pushNotNullCell(x, y, row)
            x++
            y--
        if count == goodCount
            rows.push row

    return rows

Grid::findTwoInRow = (value) ->
    rows = @rows()
    ret = []
    x = 0
    while x < rows.length
        if @isTwoInRow(rows[x], value)
            ret.push rows[x]
        x++
    return ret

Grid::isTwoInRow = (row, value) ->
    countV = 0
    countE = 0
    x = 0
    while x < 3
        if row[x]
            if row[x].value == value
                countV++
            if row[x].value == ' '
                countE++
        x++
    return countV == 2 and countE == 1

Grid::findFirstAvailableCell = (row) ->
    if row.length > 0
        i = 0
        while i < row.length
            if row[i].value == ' '
                return row[i]
            i++
    return null

GameManager::setup = ->
  @grid = new Grid(@size)
  @over = false
  @won = false
  @nextX = true
  @actuate()
  return

GameManager::getGrid = ->
    return @grid

GameManager::getRenderer = ->
  return @renderer

GameManager::isNextFirstHand = ->
    return @nextX

GameManager::isGameTerminated = ->
  if @over or @won
    true
  else
    false

GameManager::checkGameTerminated = (msg) ->
    if @isGameTerminated()
        msg.send "Game is OVER! Please restart."
        return true
    return false

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
  if @checkGameTerminated()
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

  if @grid.getGoodCellRows(newCell, 3).length > 0
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

Room::startWithOpponent = (msg, opponent) ->
    @opponent = opponent
    hubotRenderer = new Renderer()
    hubotRenderer.setMsg msg
    @game = new GameManager(3, hubotRenderer)

Room::mark = (position, msg) ->
    if @game.checkGameTerminated(msg)
        return
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

BotGame::startWithMsg = (msg) ->
    hubotRenderer = new Renderer()
    hubotRenderer.setMsg msg
    @game = new GameManager(3, hubotRenderer)
    if @botFirst
         @botMark(msg)
    return

BotGame::mark = (position, msg) ->
    if @game.checkGameTerminated(msg)
        return
    if @botFirst == @game.isNextFirstHand()
        msg.send "It's not your turn! Please wait for Bot`s move.."
        return

    @game.mark(position, msg)
    if not @game.isGameTerminated()
        @botMark(msg)
    return

BotGame::botMark = (msg) ->
    msg.send "Bot`s turn:"

    if @botFirst == @game.isNextFirstHand()
        if @botFirst
            botValue = 'X'
            opValue = 'O'
        else
            botValue = 'O'
            opValue = 'X'

        if @markWin(botValue, msg)
            msg.send "Bot: win"
            return

        if @markBlock(opValue, msg)
            msg.send "Bot: block"
            return

        if @markFork(botValue, msg)
            msg.send "Bot: fork"
            return

        if @markBlockFork(opValue, botValue, msg)
            msg.send "Bot: block fork"
            return

        if @markCenter(msg)
            msg.send "Bot: center"
            return

        if @markOppositeCornerOrEmptyCorner(msg)
            msg.send "Bot: corner"
            return

        if @markEmptySide(msg)
            msg.send "Bot: side"
            return

        #====Mark Next Available Cell====
        @markNextAvailable(msg)
        msg.send "Bot: available"
        #==============================
    return

#===========Bot Strategy========
BotGame::markWin = (botValue, msg) ->
    rows = @game.getGrid().findTwoInRow(botValue)
    if rows.length > 0
        x = 0
        while x < 3
            if rows[0][x].value != botValue
                @game.mark(rows[0][x], msg)
                return true
            x++
    return false

BotGame::markBlock = (opValue, msg) ->
    return @markWin(opValue, msg)

BotGame::markFork = (botValue, msg) ->
    grid = @game.getGrid()
    cells = grid.availableCells()
    if cells.length > 0
        i = 0
        while i < cells.length
            cell =
                x: cells[i].x
                y: cells[i].y
                value: botValue
            grid.insertCell(cell)
            rows = grid.findTwoInRow(botValue)
            grid.removeCell(cell)
            if rows.length >= 2
                @game.mark(cell, msg)
                return true
            i++
    return false

BotGame::markBlockFork = (opValue, botValue, msg) ->
    grid = @game.getGrid()
    cells = grid.availableCells()
    if cells.length > 0
        i = 0
        while i < cells.length
            cell =
                x: cells[i].x
                y: cells[i].y
                value: botValue
            grid.insertCell(cell)
            rows = grid.getGoodCellRows(cell, 2)
            if rows.length > 0
                j = 0
                while j < rows.length
                    aCell = grid.findFirstAvailableCell(rows[j])
                    if aCell
                        opCell =
                            x: aCell.x
                            y: aCell.y
                            value: opValue
                        grid.insertCell(opCell)
                        tmpRows = grid.getGoodCellRows(opCell, 2)
                        grid.removeCell(opCell)
                        if tmpRows.length <= 0
                            grid.removeCell(cell)
                            @game.mark(cell, msg)
                            return true
                    j++
            grid.removeCell(cell)
            i++
    return false

BotGame::markCenter = (msg) ->
    center =
        x: 1
        y: 1
    if @game.getGrid().cellAvailable(center)
        @game.mark(center, msg)
        return true
    return false

BotGame::markOppositeCornerOrEmptyCorner = (msg) ->
    grid = @game.getGrid()

    cellLeftTop =
        x: 0
        y: 0
    cellLeftBottom =
        x: 2
        y: 0
    cellRightTop =
        x: 0
        y: 2
    cellRightBottom =
        x: 2
        y: 2

    if grid.cellOccupied(cellLeftTop) and grid.cellAvailable(cellRightBottom)
        @game.mark(cellRightBottom, msg)
        return true
    if grid.cellOccupied(cellLeftBottom) and grid.cellAvailable(cellRightTop)
        @game.mark(cellRightTop, msg)
        return true
    if grid.cellOccupied(cellRightTop) and grid.cellAvailable(cellLeftBottom)
        @game.mark(cellLeftBottom, msg)
        return true
    if grid.cellOccupied(cellRightBottom) and grid.cellAvailable(cellLeftTop)
        @game.mark(cellLeftTop, msg)
        return true

    if grid.cellAvailable(cellLeftTop)
        @game.mark(cellLeftTop, msg)
        return true
    if grid.cellAvailable(cellLeftBottom)
        @game.mark(cellLeftBottom)
        return true
    if grid.cellAvailable(cellRightTop)
        @game.mark(cellRightTop)
        return true
    if grid.cellAvailable(cellRightBottom)
        @game.mark(cellRightBottom)
        return true

    return false

BotGame::markEmptySide = (msg) ->
    grid = @game.getGrid()

    cellLeft =
        x: 1
        y: 0
    cellTop =
        x: 0
        y: 1
    cellRight =
        x: 1
        y: 2
    cellBottom =
        x: 2
        y: 1

    if grid.cellAvailable(cellLeft)
        @game.mark(cellLeft, msg)
        return true
    if grid.cellAvailable(cellTop)
        @game.mark(cellTop, msg)
        return true
    if grid.cellAvailable(cellRight)
        @game.mark(cellRight, msg)
        return true
    if grid.cellAvailable(cellBottom)
        @game.mark(cellBottom, msg)
        return true

    return false

BotGame::markNextAvailable = (msg) ->
    cells = @game.getGrid().availableCells()
    if cells.length > 0
        @game.mark(cells[cells.length - 1], msg)
        return true
    else
        msg.send "NO available cell in Bot`s turn.."
    return false

#===========Utils=================

#=========================================

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

getPosition = (numberStr) ->
    cellNum = parseInt(numberStr, 10)
    position =
         x: Math.floor((cellNum - 1) / 3)
         y: (cellNum - 1) % 3
    return position

loadGameManager = (robot, key, msg) ->
    gameManager = robot.brain.get(key)
    unless gameManager?
      msg.send "No Tic-Tac-Toe game in progress."
      sendHelp robot, msg
      return null
    return gameManager

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
  msg.send "#{prefix} ttt bot first - Start a game of Tic-Tac-Toe VS #{prefix} - Bot First"
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
    gameManager = loadGameManager(robot, getGameKey(msg), msg)
    if gameManager
        gameManager.mark(getPosition(msg.match[1]), msg)

  robot.respond /ttt me restart/i, (msg) ->
    gameManager = loadGameManager(robot, getGameKey(msg), msg)
    if gameManager
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
      room = loadGameManager(robot, getRoomGameKey(getUserName(msg)), msg)
      if room
          room.mark(getPosition(msg.match[1]), msg)
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

  robot.respond /ttt bot start/i, (msg) ->
      botGame = robot.brain.get(getBotGameKey(msg))

      unless botGame?
        msg.send "#{getUserName(msg)} has started a game of Tic-Tac-Toe VS Bot"
        botGame = new BotGame(false)
        botGame.startWithMsg(msg)
        robot.brain.set(getBotGameKey(msg), botGame)
        robot.brain.save()
      else
        msg.send "Tic-Tac-Toe game already in progress."
        sendHelp robot, msg

  robot.respond /ttt bot first/i, (msg) ->
        botGame = robot.brain.get(getBotGameKey(msg))

        unless botGame?
          msg.send "#{getUserName(msg)} has started a game of Tic-Tac-Toe VS Bot - Bot first"
          botGame = new BotGame(true)
          botGame.startWithMsg(msg)
          robot.brain.set(getBotGameKey(msg), botGame)
          robot.brain.save()
        else
          msg.send "Tic-Tac-Toe game already in progress."
          sendHelp robot, msg

  robot.respond /ttt bot ([1-9])/i, (msg) ->
      botGame = loadGameManager(robot, getBotGameKey(msg), msg)
      if botGame
          botGame.mark(getPosition(msg.match[1]), msg)

  robot.respond /ttt bot restart/i, (msg) ->
      botGame = loadGameManager(robot, getBotGameKey(msg), msg)
      if botGame
          msg.send "#{getUserName(msg)} has started a game of Tic-Tac-Toe VS Bot"
          botGame.startWithMsg(msg)

  robot.respond /ttt bot stop/i, (msg) ->
      robot.brain.set(getBotGameKey(msg), null)
      robot.brain.save()

      msg.send "#{getUserName(msg)} has stopped a game of Tic-Tac-Toe."
