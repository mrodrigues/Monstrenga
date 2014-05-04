# # Quintus platformer example
#
# [Run the example](../quintus/examples/platformer/index.html)
# WARNING: this game must be run from a non-file:// url
# as it loads a level json file.
#
# This is the example from the website homepage, it consists
# a simple, non-animated platformer with some enemies and a 
# target for the player.
window.addEventListener "load", ->

  # Set up an instance of the Quintus engine  and include
  # the Sprites, Scenes, Input and 2D module. The 2D module
  # includes the `TileLayer` class as well as the `2d` componet.

  # Maximize this game to whatever the size of the browser is

  # And turn on default input controls and touch input (for UI)
  Q = window.Q = Quintus({audioSupported: [ 'wav','mp3','ogg' ]}).
    include("Audio, Sprites, Scenes, Input, 2D, Anim, Touch, UI").
    setup(maximize: true).
    controls().
    touch().
    enableSound()

  #Q.debug = true

  # ## Components
  Q.component "fearOfHeight",
    added: ->
      @entity.on "step", this, "step"
    step: (dt) ->
      y_offset = 20
      x_offset = 10
      x_offset *= switch @entity.direction()
        when "left" then -1
        when "right" then 1
      unless Q.stage().locate(@entity.p.x + x_offset, @entity.p.y + y_offset, Q.SPRITE_ALL)
        @entity.p.vx *= -1

  Q.component "flippable",
    added: ->
      @entity.on "step", this, "step"
    step: (dt) ->
      if @entity.p.vx > 0
        @entity.play("walk_right")
      else if @entity.p.vx < 0
        @entity.play("walk_left")

  # ## Player Sprite
  # The very basic player sprite, this is just a normal sprite
  # using the player sprite sheet with default controls added to it.
  Q.Sprite.extend "Player",

    # the init constructor is called on creation
    init: (p) ->

      # You can call the parent's constructor with this._super(..)
      @_super p,
        sheet: "player" # Setting a sprite sheet sets sprite width and height
        sprite: "player"
        x: 410 # You can also set additional properties that can
        y: 90 # be overridden on object creation
        life: 1
        jumpSpeed: -560
        gravity: 1.5
        points: [[-11,15],[-11,-15],[12,-15],[12,15]]

      # Add in pre-made components to get up and running quickly
      # The `2d` component adds in default 2d collision detection
      # and kinetics (velocity, gravity)
      # The `platformerControls` makes the player controllable by the
      # default input actions (left, right to move,  up or action to jump)
      # It also checks to make sure the player is on a horizontal surface before
      # letting them jump.
      @add "2d, platformerControls, animation, flippable"
      @on("jump")

    step: (dt) ->
      if @p.landed > 0
        @p.playedJump = false
      if Q.debug
        Q.stageScene('hud', 3, @p)
    draw: (ctx) ->
      @_super(ctx)
      if Q.debug
        ctx.fillStyle = "red"
        ctx.fillRect(- 20, 20, 5, 5)
    die: ->
      unless Q.debug
        Q.audio.play('die.mp3')
        Q.clearStages()
        Q.stageScene "level1"
    jump: ->
      if !@p.playedJump
        Q.audio.play('jump.mp3')
        @p.playedJump = true
    jumped: (obj) ->
      obj.p.playedJump = false
    updateHud: ->
      Q.stageScene('hud', 3, @p)
    loseLife: ->
      if @p.life == 0
        @die()
      else
        @p.life -= 1
        @updateHud()

  # ## Tower Sprite
  # Sprites can be simple, the Tower sprite just sets a custom sprite sheet
  #Q.Sprite.extend "Tower",
  #  init: (p) ->
  #    @_super p,
  #      sheet: "tower"

  #    return

  Q.Sprite.extend "Range",
    init: (p) ->
      @_super p,
        type: Q.SPRITE_NONE
      @owner = @p.owner

    step: (dt) ->
      @p.x = @owner.p.x + @p.w / 2
      if @owner.direction() == "left"
        @p.x -= @p.w
      @p.y = @owner.p.y - @owner.p.h / 2

  # ## Enemy Sprite
  # Create the Enemy class to add in some baddies
  Q.Sprite.extend "Enemy",
    WALKING: 0
    DEAD: 1
    PANIC: 2

    init: (p) ->
      @_super p,
        sheet: "human"
        sprite: "human"
        vx: 100
        runningFactor: 2

      @state = @WALKING
      @range = new Q.Range(w: 400, h: 20, owner: this)

      # Enemies use the Bounce AI to change direction 
      # whenver they run into something.
      @add "2d, aiBounce, fearOfHeight, animation, flippable"

      @rangeAddedToStage = false

    direction: ->
      if @p.vx < 0
        "left"
      else
        "right"

    draw: (ctx) ->
      @_super(ctx)

    step: (dt) ->
      unless @rangeAddedToStage
        @stage.insert @range
        @rangeAddedToStage = true

      switch @state
        when @WALKING
          if Q.overlap(@range, Q.player)
            @panic()
        when @DEAD
          @p.vx = 0
          @p.angle = 90

    panic: ->
      Q.audio.play('scream.mp3')
      @state = @PANIC
      @p.vx *= -@p.runningFactor
      @del("fearOfHeight")

    die: ->
      Q.audio.play('die.mp3')
      Q.player.loseLife()
      @destroy()

  Q.Sprite.extend "Trap",
    init: (p) ->
      @_super p,
        asset: "trap.png"
        points: [[-16,16],[-9,-2],[9,-2],[16,16]]
      @on "hit.sprite", (collision) ->
        collision.obj.die()

  Q.Sprite.extend "Door",
    init: (p) ->
      @_super p,
        asset: "door.png"
      @on "hit.sprite", (collision) ->
        if collision.obj.isA("Player")
          Q.stageScene "endGame", 1,
            label: "You won!"

  Q.scene "hud", (stage) ->
    container = stage.insert(new Q.UI.Container(
      x: 50
      y: 0
    ))
    container.insert(new Q.UI.Text(
      x: 600
      y: 20
      label: "Life: #{Q.player.p.life}"
      color: "black"
    ))
    if Q.debug
      container.insert(new Q.UI.Text(
        x: 200
        y: 20
        label: "x: #{Q.player.p.x}, y: #{Q.player.p.y}"
        color: "red"
      ))
    container.fit 20

  # ## Level1 scene
  # Create a new scene called level 1
  Q.scene "level1", (stage) ->

    # Add in a repeater for a little parallax action
    stage.insert new Q.Repeater(
      asset: "background-wall.png"
      speedX: 0.5
      speedY: 0.5
    )

    # Add in a tile layer, and make it the collision layer
    stage.collisionLayer new Q.TileLayer(
      dataAsset: "level.json"
      sheet: "tiles"
    )

    # Create the player and add them to the stage
    Q.player = stage.insert(new Q.Player(x: 74, y: 1521))

    # Give the stage a moveable viewport and tell it
    # to follow the player.
    stage.add("viewport").follow Q.player

    # Add in a couple of enemies

    window.enemy1 = new Q.Enemy(
      x: 190
      y: 1361
    )

    stage.insert enemy1

    stage.insert new Q.Enemy(
      x: 240
      y: 1073
    )

    stage.insert new Q.Enemy(
      x: 300
      y: 625
    )

    stage.insert new Q.Enemy(
      x: 100
      y: 337
    )

    window.trap1 = new Q.Trap(
      x: 175
      y: 689
    )
    stage.insert trap1

    stage.insert new Q.Trap(
      x: 209
      y: 689
    )

    stage.insert new Q.Trap(
      x: 399
      y: 689
    )

    stage.insert new Q.Trap(
      x: 433
      y: 689
    )

    stage.insert new Q.Trap(
      x: 209
      y: 1041
    )

    stage.insert new Q.Trap(
      x: 241
      y: 1041
    )

    stage.insert new Q.Trap(
      x: 399
      y: 1201
    )

    stage.insert new Q.Trap(
      x: 431
      y: 1201
    )

    stage.insert new Q.Trap(
      x: 431
      y: 1201
    )

    stage.insert new Q.Trap(
      x: 175
      y: 401
    )

    stage.insert new Q.Trap(
      x: 206
      y: 401
    )

    stage.insert new Q.Trap(
      x: 237
      y: 401
    )

    stage.insert new Q.Trap(
      x: 271
      y: 401
    )

    window.door = stage.insert new Q.Door(
      x: 401
      y: 96
    )

    Q.stageScene('hud', 3, Q.player.p)

  # To display a game over / game won popup box, 
  # create a endGame scene that takes in a `label` option
  # to control the displayed message.
  Q.scene "endGame", (stage) ->
    container = stage.insert(new Q.UI.Container(
      x: Q.width / 2
      y: Q.height / 2
      fill: "rgba(0,0,0,0.5)"
    ))
    button = container.insert(new Q.UI.Button(
      x: 0
      y: 0
      fill: "#CCCCCC"
      label: "Play Again"
    ))
    label = container.insert(new Q.UI.Text(
      x: 10
      y: -10 - button.p.h
      label: stage.options.label
    ))

    # When the button is clicked, clear all the stages
    # and restart the game.
    button.on "click", ->
      Q.clearStages()
      Q.stageScene "level1"
      return


    # Expand the container to visibily fit it's contents
    # (with a padding of 20 pixels)
    container.fit 20
    return


  # ## Asset Loading and Game Launch
  # Q.load can be called at any time to load additional assets
  # assets that are already loaded will be skipped
  # The callback will be triggered when everything is loaded
  Q.load "player.png, player.json, human.png, human.json, trap.png, door.png, level.json, tiles.png, background-wall.png, jump.mp3, scream.mp3, die.mp3, bg.mp3", ->

    # Sprites sheets can be created manually
    Q.sheet "tiles", "tiles.png",
      tilew: 32
      tileh: 32

    # Or from a .json asset that defines sprite locations
    Q.compileSheets "player.png", "player.json"
    Q.compileSheets "human.png", "human.json"

    Q.animations("player", {
      walk_right: { frames: [0], rate: 1/15, flip: false, loop: true },
      walk_left: { frames:  [0], rate: 1/15, flip:"x", loop: true }
    })

    Q.animations("human", {
      walk_right: { frames: [0], rate: 1/15, flip: false, loop: true },
      walk_left: { frames:  [0], rate: 1/15, flip:"x", loop: true }
    })

    # Finally, call stageScene to run the game
    Q.stageScene "level1"
    Q.audio.play "bg.mp3", loop: true

  , progressCallback: (loaded, total) ->
      element = document.getElementById("loading_progress")
      element.style.width = Math.floor(loaded/total*100) + "%"
      if loaded == total
        document.getElementById("loading").style.display = "none"
# ## Possible Experimentations:
# 
# The are lots of things to try out here.
# 
# 1. Modify level.json to change the level around and add in some more enemies.
# 2. Add in a second level by creating a level2.json and a level2 scene that gets
#    loaded after level 1 is complete.
# 3. Add in a title screen
# 4. Add in a hud and points for jumping on enemies.
# 5. Add in a `Repeater` behind the TileLayer to create a paralax scrolling effect.
