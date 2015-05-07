# Hubot插件开发:井字游戏

此项目实施的主要目的:

- 学习[Hubot](https://hubot.github.com/)脚本的开发方法.
- 学习使用[CoffeeScript](https://github.com/coffee-js/coffee-script).
- 温习[Tic-Tac-Toe](http://en.wikipedia.org/wiki/Tic-tac-toe)玩法.

此项目实现的主要目标:

- 在[Slack](https://slack.com/)上与Robot或者好友进行TicTacToe的对战.

此文主要记录项目实施的过程与结果,适合小白用户阅读.


## 搭建项目环境

已有基础环境

- 操作系统: Mac OSX 10.10.4
- Node.JS:0.12.2
- npm:2.7.5
- redis-server:3.0.0

第一步,我们创建本项目所使用的文件根目录

```
mkdir tttgame
cd tttgame
```

第二步,创建hubot-tictactoe项目,参考[官方Example](https://github.com/hubot-scripts/hubot-example)结构:

```
mkdir hubot-tictactoe
cd hubot-tictactoe
npm init
```

第三步,我们直接创建一个本项目专用的tttbot(Hubot完整安装使用方式请参见官网):

```
mkdir tttbot
cd tttbot
yo hubot
```

第四步,在tttbot中安装hubot-tictactoe脚本:

```
cd tttbot
npm link ../hubot-tictactoe
```

第五步,编辑 `tttbot/external-scripts.json`, 增加`hubot-tictactoe`.

至此,开发目录和调试环境都已经搭建完毕,可运行hubot验证,运行前请确保Redis-server已经正常配置并运行:

```
cd tttbot
bin/hubot
```

## 项目开发

### 功能点及步骤

1. 实现单游戏单用户运行,验证游戏框架正确性
2. 实现双用户对战模式.
3. 尝试Bot端游戏策略,实现人机对战.

### 单游戏单用户

此模式主要为了实现并验证游戏框架的正确性,采用单个用户模拟对战双方,轮流输入'X'和'O'来展现对战,并最终结束游戏,得出胜负手.与hubot的交互可以先简单采用`Shell` adapter.


#### 输入指令与帮助信息

在`hubot-tictactoe/src`目录下新建`tictactoe.coffee`脚本, 增加帮助命令,这里我们将我们的脚本所使用到的子命令固定为`ttt`,并且指定了4条指令:

```
# Commands:
#   hubot ttt start - Start a game of Tic-Tac-Toe
#   hubot ttt <number> - Mark the Cell
#   hubot ttt restart - Restart the current game of Tic-Tac-Toe
#   hubot ttt stop - Stop the current game of Tic-Tac-Toe
#
# Notes:
#   Number Commands:
#     1	 |   2   |   3
#     4	 |   5   |   6
#     7	 |   8   |   9
#
```

此部分为注释,但是会在`help`命令中输出显示,例如:

```
tttbot> tttbot help
tttbot adapter - Reply with the adapter
tttbot animate me <query> - The same thing as `image me`, except adds a few parameters to try to return an animated GIF instead.
tttbot echo <text> - Reply back with <text>
tttbot help - Displays all of the help commands that tttbot knows about.
tttbot help <query> - Displays all help commands that match <query>.
tttbot image me <query> - The Original. Queries Google Images for <query> and returns a random top result.
tttbot map me <query> - Returns a map view of the area returned by `query`.
tttbot mustache me <query> - Searches Google Images for the specified query and mustaches it.
tttbot mustache me <url> - Adds a mustache to the specified URL.
tttbot ping - Reply with pong
tttbot pug bomb N - get N pugs
tttbot pug me - Receive a pug
tttbot the rules - Make sure tttbot still knows the rules.
tttbot time - Reply with current time
tttbot translate me <phrase> - Searches for a translation for the <phrase> and then prints that bad boy out.
tttbot translate me from <source> into <target> <phrase> - Translates <phrase> from <source> into <target>. Both <source> and <target> are optional
tttbot ttt <number> - Mark the Cell
tttbot ttt restart - Restart the current game of Tic-Tac-Toe
tttbot ttt start - Start a game of Tic-Tac-Toe
tttbot ttt stop - Stop the current game of Tic-Tac-Toe
tttbot youtube me <query> - Searches YouTube for the query and returns the video embed link.
ship it - Display a motivation squirrel

```

增加输出`ttt`指令的帮助内容的方法:

```
sendHelp = (robot, msg) ->
  prefix = robot.alias or robot.name
  msg.send "Start Game: #{prefix} ttt start"
  msg.send "Mark Cell: #{prefix} ttt {number}"
  msg.send "Numbers: 1 2 3"
  msg.send "Numbers: 4 5 6"
  msg.send "Numbers: 7 8 9"
  msg.send "Restart Game: #{prefix} ttt restart"
  msg.send "Stop Game: #{prefix} ttt stop"
```

增加获取会话消息的发送者信息的方法:

```
getUserName = (msg) ->
  if msg.message.user.mention_name?
    msg.message.user.mention_name
  else
    msg.message.user.name
```

#### 数据与持久化

游戏在一个3*3的棋盘上进行,我们定义每一个小格子的数据为:

```
Cell = (x, y, value) ->
	@x = x 
	@y = y
	@value = value
```

一整个棋盘由一个3*3的二维数组构成,数组元素为Cell:

```
Grid = (size) ->
	@size = size
	@cells = []
```
一局游戏由一个棋盘和若干状态构成:

```
Game = (size) ->
	@size = size
	@grid = new Grid(@size)
	@won = false
	@over = false
	@nextX = false
```

每一局游戏的数据根据交互指令进行修改并持久化,可以直接调用hubot提供的键值对存储方法,后台默认使用的是Redis:


```
robot.brain.set(KEY, VALUE)
robot.brain.save
...
robot.brain.get(KEY)
```

#### 落子处理逻辑

用户输入落子指令之后:

1. 判断当前棋局是否已经结束(胜局或者平局),若已经结束,则提示并返回.
2. 判断落子位置是否在棋盘内,若不在,则提示并返回.
3. 判断落子位置当前是否为空,若已经有子,则提示并返回.
4. 确认落子并更新棋盘记录,输出当前棋盘状态.
5. 根据当前落子记录判断当前棋盘是否已经产生胜利者或者出现平局,提示并返回.


#### 胜局和平局判断

游戏的规则是当一行或者一列或者对角线上的3个格子内的标记相同,则获胜.实际操作中,如果要判断一张棋盘的当前状态是否有获胜方,则需要分别扫描3行3列和两个对角线,共做8组判断.当然,我们可以认为,在某一方落子之前,棋盘上是没有获胜方的,而当该子落下之后,假如出现了获胜方,则复合获胜判断条件的那一组中肯定包含刚落下的子.即我们只需要判断与刚落子有关的组即可确定当前是否有获胜方.

这样又可以根据落子的位置分为三种情况来考虑:

- 落子在2,4,6,8号位,只需要判断落子所在行和列,共2组判断.
- 落子在1,3,7,9号位,除了所在行和列,还需要判断一条对角线,共3组判断.
- 落子在5号位,除了所在行和列,还需要判断两条对角线,共4组判断.

如上,每一次落子之后只需要进行2-4组判断即可判断胜局.

而当落子之后既没有产生胜利方,棋盘上也没有剩余的位置可以落子的时候,则判定双方位平局.


#### 实战测试

```
tttbot> tttbot ttt start
Shell has started a game of Tic-Tac-Toe.
-------
| | | |
| | | |
| | | |
-------
Next: X
tttbot> tttbot ttt 5
-------
| | | |
| |X| |
| | | |
-------
Next: O
tttbot> tttbot ttt 9
-------
| | | |
| |X| |
| | |O|
-------
Next: X
tttbot> tttbot ttt 4
-------
| | | |
|X|X| |
| | |O|
-------
Next: O
tttbot> tttbot ttt 6
-------
| | | |
|X|X|O|
| | |O|
-------
Next: X
tttbot> tttbot ttt 3
-------
| | |X|
|X|X|O|
| | |O|
-------
Next: O
tttbot> tttbot ttt 7
-------
| | |X|
|X|X|O|
|O| |O|
-------
Next: X
tttbot> tttbot ttt 8
-------
| | |X|
|X|X|O|
|O|X|O|
-------
Next: O
tttbot> tttbot ttt 2
-------
| |O|X|
|X|X|O|
|O|X|O|
-------
Next: X
tttbot> tttbot ttt 1
-------
|X|O|X|
|X|X|O|
|O|X|O|
-------
Next: O
===Tie!===
```

一般,双方都使用最优策略总是会出现平局的情况.

### 双用户对战

此模式主要为了实现两个用户在聊天室中可以进行游戏的对战.对战方法为:

- 用户A建立房间R1.
- 用户B加入房间R1,此时对战自动开始,A先手,B后手.
- A与B轮流落子直到决出胜负.

与单用户模式的主要区别是增加了房间的定义:

```
Room = (name, creator) ->
  @name = name
  @creator = creator
  @opponent = null
  @game = null
  return
```

房间使用唯一的`name`进行区分,且固定了对战双方,只有他们的指令才会被对应到指定的房间.

由于双方轮流落子且有先后手之分,还需要对双方的落子指令进行判断,只有在自己的回合的落子指令才有效.


### Bot游戏策略

***TODO***

## 其他

- 脚本源码: [hubot-tictactoe](https://github.com/abysshal/hubot-tictactoe)
- 欢迎上[Slack](http://dreamingfish.slack.com/)在`#general`频道调戏`@hbot`


