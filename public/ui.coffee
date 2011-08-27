class Plot
  
  constructor : (@manager, @front, @mid, @back) ->
    @fp = @front.getContext '2d'
    @mp = @mid.getContext '2d'
    @bp = @back.getContext '2d'
    @size  = @front.height
    @scale = @size / 10.0
    @pen = @mp
  
  drawTiles : ->
    @bp.fillStyle = '#999999'
    @bp.fillRect 0, 0, @size, @size
    
    @bp.fillStyle = '#cccccc'
    for x in [0..10]
      for y in [x%2..10] by 2
        @bp.fillRect x*@scale, y*@scale, @scale, @scale

  drawEntities : ->
    @pen = @mp
    @pen.clearRect 0, 0, @size, @size
    for x in [0..9]
      for y in [0..9]
        if e = @manager.getEntityAt(x, y)
          @[e.constructor.name.toLowerCase()](e)

  block : (e) ->
    [x,y] = e.position
    @pen.fillStyle = "#000000"
    @pen.fillRect x*@scale + 4, y*@scale + 4, @scale - 8, @scale - 8
    
  mirror : (e) ->
    [x, y] = e.position
    
    @pen.strokeStyle = e.color || "#000000"
    @pen.beginPath()
    if e.orientation % 2 == 1 # NW
      @pen.moveTo(x*@scale + 4, y*@scale + 4)
      @pen.lineTo((x+1)*@scale - 4, (y+1)*@scale - 4)
    else
      @pen.moveTo((x+1)*@scale - 4, y*@scale + 4)
      @pen.lineTo(x*@scale + 4, (y+1)*@scale - 4)
    @pen.closePath()
    @pen.stroke()
  
  prism : (e) ->
    [x,y] = e.position
    
    @pen.save()
    @pen.translate((x+0.5) * @scale, (y+0.5) * @scale)
    @pen.rotate(Math.PI/2 * (e.orientation-1))
    @pen.fillStyle = "#000000"
    @pen.fillRect(4-@scale/2, -@scale/2, @scale-8, 8)
    @pen.fillRect(-4, -@scale/2, 4, @scale)
    @pen.restore()
  
  filter : (e) -> @mirror(e)
    
  coordsToSquare : (e) ->
    offset = $(@front).offset()
    
    [Math.floor((e.pageX - offset.left)/@scale/UI.zoomLevel),
     Math.floor((e.pageY - offset.top)/@scale/UI.zoomLevel)]

  clearLast : () ->
    if @lastMouseMove
      @fp.clearRect @lastMouseMove[0]*@scale, @lastMouseMove[1]*@scale, @scale, @scale
    

  hoverHandler : (e) ->
    @clearLast()

    return if UI.zoomLevel < 0.25

    @lastMouseMove = [x,y] = @coordsToSquare e
        
    @fp.strokeStyle = '#00ff00' # ugly color for debugging
    @fp.strokeRect x*@scale+2, y*@scale+2, @scale-4, @scale-4

    # display tool
    if !@manager.getEntityAt(x, y) and UI.tool
      @pen = @fp
      @[UI.tool.toLowerCase()](new (window[UI.tool])([x,y], 1, true))
    
  clickHandler : (e) ->
    return if UI.zoomLevel < 0.25
    
    [x, y] = @coordsToSquare e
    
    if entity = @manager.getEntityAt(x, y)
      if e.which == 3 # right click
        @manager.removeEntityAt(x, y)
      else
        @manager.rotateEntityClockwise(x, y)
    else if UI.tool
      @manager.addEntity(new (window[UI.tool])([x,y], 1, true))
    @drawEntities()
    @clearLast()
    
UI =
  zoomLevel : 1 # between 0 and 1 with 1 being max zoom level and 0.25 being 4x further away
  topLeft   : [0, 0]
  plots     : []
  container : false
  mousedown : false
  tool      : false
  worldDims : [2500, 2500]
      
  draw : ->
    for plot in @plots
      plot.drawTiles()
  
  
  reposition : (origin = false) ->
    [x, y] = @topLeft    
    bodyW = $("body").width()
    bodyH = $("body").height()
    
    x = Math.min(Math.max(x, 0), @worldDims[0] - bodyW)
    y = Math.min(Math.max(y, 0), @worldDims[1] - bodyH) 
    
    for prefix in ['', '-o-', '-moz-', '-webkit-', '-ms-']
      @container.css "#{prefix}transform-origin", origin if origin
      @container.css "#{prefix}transform", "scale(#{@zoomLevel}) translate(#{x}px, #{y}px)"
  
  
  installHandlers : ->
    $(document).mousedown (e) ->
      UI.mousedown = [e.pageX, e.pageY]
      
    $(document).mouseup (e) ->
      UI.mousedown = false
      
    $(document).bind 'contextmenu', -> false
      
    $(document).mousemove (e) =>
      if @mousedown
        # pan, TODO: make this scale properly
        @topLeft[0] += (e.pageX - @mousedown[0]) / @zoomLevel
        @topLeft[1] += (e.pageY - @mousedown[1]) / @zoomLevel
        @reposition()
        @mousedown = [e.pageX, e.pageY]
      true
      
    $(document).mousewheel (e, delta) =>
      if delta > 0
        @zoomLevel *= 1.2
      else
        @zoomLevel /= 1.2
      
      @zoomLevel = Math.max(0.1, Math.min(1, @zoomLevel))
      
      if @zoomLevel < 0.25
        $("#palate").fadeOut()
      else
        $("#palate").fadeIn()
        
      @reposition("#{e.pageX}px #{e.pageY}px")
      
    
    $("#palate li").click (e) -> UI.tool = $(this).data("tool")
  
  addPlot : (puzzle, $div, interactive) ->
    p = new Plot(puzzle, $div.find('.fg')[0], $div.find('.mg')[0], $div.find('.bg')[0])
    if interactive
      $div.mousemove (e) -> p.hoverHandler(e) or true
      $div.mouseup (e)   -> p.clickHandler(e) or true
      $div.mouseout (e)  -> p.clearLast()     or true
    @plots.push p