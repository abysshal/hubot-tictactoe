chai = require 'chai'
sinon = require 'sinon'
chai.use require 'sinon-chai'

expect = chai.expect

describe 'tictactoe', ->
  beforeEach ->
    @robot =
      respond: sinon.spy()

    require('../src/tictactoe')(@robot)

  it 'registers respond listeners', ->
    expect(@robot.respond).to.have.been.calledWith(/ttt start/i)
    expect(@robot.respond).to.have.been.calledWith(/ttt help/i)
    expect(@robot.respond).to.have.been.calledWith(/ttt ([1-9])/i)
    expect(@robot.respond).to.have.been.calledWith(/ttt restart/i)
    expect(@robot.respond).to.have.been.calledWith(/ttt stop/i)
