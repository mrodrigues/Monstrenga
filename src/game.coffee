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
  Q = window.Q = Quintus().include("Sprites, Scenes, Input, 2D, Anim, Touch, UI").setup(maximize: true).controls(true).touch()
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
        jumpSpeed: -450

      # Add in pre-made components to get up and running quickly
      # The `2d` component adds in default 2d collision detection
      # and kinetics (velocity, gravity)
      # The `platformerControls` makes the player controllable by the
      # default input actions (left, right to move,  up or action to jump)
      # It also checks to make sure the player is on a horizontal surface before
      # letting them jump.
      @add "2d, platformerControls, animation, flippable"

      # Write event handlers to respond hook into behaviors.
      # hit.sprite is called everytime the player collides with a sprite
      @on "hit.sprite", (collision) ->

        # Check the collision, if it's the Tower, you win!
        if collision.obj.isA("Tower")
          Q.stageScene "endGame", 1,
            label: "You Won!"

          @destroy()

    step: (dt) ->
      if Q.debug
        Q.stageScene('hud', 3, @p)
    draw: (ctx) ->
      @_super(ctx)
      if Q.debug
        ctx.fillStyle = "red"
        ctx.fillRect(- 20, 20, 5, 5)
    die: ->
      Q.clearStages()
      Q.stageScene "level1"
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
      @_super p
      @owner = @p.owner

    step: (dt) ->
      @p.x = @owner.p.x
      @p.y = @owner.p.y

    draw: (ctx)->
      @_super(ctx)
      if Q.debug
        ctx.fillStyle = "red"
        x_range = if @owner.direction() == "left"
          -@p.w
        else
          0
        y_range = -@owner.p.h / 2
        ctx.fillRect(x_range, y_range, @p.w, @p.h)

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

      @state = @WALKING
      @range = new Q.Range(w: 100, h: 20, owner: this)

      # Enemies use the Bounce AI to change direction 
      # whenver they run into something.
      @add "2d, aiBounce, fearOfHeight, animation, flippable"
      return

    direction: ->
      if @p.vx < 0
        "left"
      else
        "right"

    draw: (ctx) ->
      @_super(ctx)
      @range.draw(ctx)

    step: (dt) ->
      @range.step(dt)

      switch @state
        when @WALKING
          if Q.overlap(@range, Q.player)
            @panic()
        when @DEAD
          @p.vx = 0
          @p.angle = 90

    panic: ->
      @state = @PANIC
      @p.vx *= -2
      @del("fearOfHeight")

    die: ->
      Q.player.loseLife()
      @destroy()

  Q.Sprite.extend "Trap",
    init: (p) ->
      @_super p,
        w: 20
        h: 20
      @on "hit.sprite", (collision) ->
        collision.obj.die()

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
    return

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
    Q.player = stage.insert(new Q.Player(x: 74, y: 1105))

    # Give the stage a moveable viewport and tell it
    # to follow the player.
    stage.add("viewport").follow Q.player

    # Add in a couple of enemies
    window.enemy1 = new Q.Enemy(
      x: 100
      y: 17
    )

    stage.insert enemy1

    window.trap1 = new Q.Trap(
      x: 882
      y: 209
    )
    stage.insert trap1
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
  Q.load "player.png, player.json, human.png, human.json, level.json, tiles.png, background-wall.png", ->

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
