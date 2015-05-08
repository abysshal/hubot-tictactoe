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

### 游戏相关名词说明

- 棋子, `X` 或 `O` 标记
- 方格, 摆放棋子的位置
- 棋盘 , 3 * 3 的方格
- 落子, 在某一个方格内放置一个棋子
- 组, 一个横行/竖列/对角线内的3个空格组成


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


### Bot对战

在此模式中,用户和Bot轮流落子决出胜负,用户可通过不同指令规定先后手.

#### 数据结构

与单用户模式类似,只是增加了BotGame的定义,用于保存Bot的先后手定义:

```
BotGame = (botFirst) ->
    @botFirst = botFirst
    @game = null
    return
```

#### Bot游戏策略

在Bot先手或者用户落子完成且判断游戏还没有结束的情况下,需要调用Bot游戏决策方法,获取下一步Bot落子的位置,最终输出返回给用户.

而根据[wiki](http://en.wikipedia.org/wiki/Tic-tac-toe)上的信息,游戏双方都存在最优策略,所以此处我们便要在Bot游戏决策方法中实现最优策略.
所谓最优策略,即存在8种落子的方法,从前往后依次做判断,当某一种方法的条件符合时,即采取该方法的落子策略.

1. `Win`, 如果当前棋盘上已经有两个本方的棋子在同一组,则落子在第三个子处即可获取胜利.
2. `Block`, 如果当前棋盘上已经有两个对手的棋子在同一组,则落子在第三个子处阻止对手在下回合获胜.
3. `Fork`, 放置一个子使两个组内都有本方两个子而没有对方的子.
4. `Blocking an opponent's fork`, 放置一个子使得某一组内存在两个本方棋子,而迫使对手在下回合必须放置在该组的第三个子处来阻止本方获胜,但是又不能使对方下回合落子后出现两个组内都存在对方两个棋子的情况.
5. `Center`, 放置在棋盘中心位置.
6. `Opposite corner`, 如果对手有棋子在4个角落中,则落子在对手棋子对角线上的角落.
7. `Empty corner`, 落子在角落.
8. `Empty side`, 落子在上下左右四条边的中间位置.

#### 实现方法

1. `Win`, 获取当前棋盘上所有的8个组,判断每个组是否存在一个为空白,2个为本方棋子,若有,则落子在空白处.
2. `Block`, 获取当前棋盘上所有的8个组,判断每个组是否存在一个为空白,2个为对方棋子,若有,则落子在空白处.
3. `Fork`, 获取当前棋盘上所有空白的方格,逐一尝试,在某个空白方格处放置本方棋子后,获取当前棋盘上所有8个组,判断组内含一个空白,2个本方棋子的组的数量,若大于等于2个组,则落子在当前尝试的方格处.
4. `Blocking an opponent's fork`, 获取当前棋盘上所有空白的方格,逐一尝试,在某个空白方格处放置本方棋子后,获取跟该方格相关的所有组(2-4个),判断组内含一个空白,2个本方棋子的组的数量,若大于0,则再次逐组尝试,在该组空白方格上放置对手棋子后,获取对手棋子相关的所有组(2-4个),判断组内含一个空白,两个对手棋子的组的数量,若等于0,则落子在本方空白落子处,并返回.
5. `Center`, 如果中心方格为空白,则落子在中心方格.
6. `Opposite corner`, 对四个角落逐一判断,若对手棋子在某个角落,而该角落对角线上的角落是空白的,则落子在空白角落.
7. `Empty corner`, 对四个角落逐一判断,若某个角落是空白的,则落子在该角落.
8. `Empty side`, 对上下左右四条边的中间位置逐一判断,若某个位置是空白的,则落子在该位置.

***其中方法4. `Blocking an opponent's fork` 还有其他的表述策略, 暂未尝试实现***


#### 对战测试

Bot first:

```
tttbot> tttbot ttt bot first
Shell has started a game of Tic-Tac-Toe VS Bot - Bot first
-------
| | | |
| | | |
| | | |
-------
Next: X
Bot`s turn:
-------
| | | |
| |X| |
| | | |
-------
Next: O
Bot: center
tttbot> tttbot ttt bot 1
-------
|O| | |
| |X| |
| | | |
-------
Next: X
Bot`s turn:
-------
|O|X| |
| |X| |
| | | |
-------
Next: O
Bot: block fork
tttbot> tttbot ttt bot 8
-------
|O|X| |
| |X| |
| |O| |
-------
Next: X
Bot`s turn:
-------
|O|X| |
|X|X| |
| |O| |
-------
Next: O
Bot: block fork
tttbot> tttbot ttt bot 6
-------
|O|X| |
|X|X|O|
| |O| |
-------
Next: X
Bot`s turn:
-------
|O|X| |
|X|X|O|
| |O|X|
-------
Next: O
Bot: corner
tttbot> tttbot ttt bot 3
-------
|O|X|O|
|X|X|O|
| |O|X|
-------
Next: X
Bot`s turn:
-------
|O|X|O|
|X|X|O|
|X|O|X|
-------
Next: O
===Tie!===
Bot: corner
```

User first:

```
tttbot> tttbot ttt bot start
Shell has started a game of Tic-Tac-Toe VS Bot
-------
| | | |
| | | |
| | | |
-------
Next: X
tttbot> tttbot ttt bot 5
-------
| | | |
| |X| |
| | | |
-------
Next: O
Bot`s turn:
-------
|O| | |
| |X| |
| | | |
-------
Next: X
Bot: corner
tttbot> tttbot ttt bot 8
-------
|O| | |
| |X| |
| |X| |
-------
Next: O
Bot`s turn:
-------
|O|O| |
| |X| |
| |X| |
-------
Next: X
Bot: block
tttbot> tttbot ttt bot 3
-------
|O|O|X|
| |X| |
| |X| |
-------
Next: O
Bot`s turn:
-------
|O|O|X|
| |X| |
|O|X| |
-------
Next: X
Bot: block
tttbot> tttbot ttt bot 4
-------
|O|O|X|
|X|X| |
|O|X| |
-------
Next: O
Bot`s turn:
-------
|O|O|X|
|X|X|O|
|O|X| |
-------
Next: X
Bot: block
tttbot> tttbot ttt bot 9
-------
|O|O|X|
|X|X|O|
|O|X|X|
-------
Next: O
===Tie!===
```


## 其他

- 脚本源码: [hubot-tictactoe](https://github.com/abysshal/hubot-tictactoe)
- 欢迎上[Slack](http://dreamingfish.slack.com/)在`#general`频道调戏`@hbot`

