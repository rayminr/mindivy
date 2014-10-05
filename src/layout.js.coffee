class BasicLayout
  constructor: (@mindmap)->
    @TOPIC_Y_PADDING = 10
    @TOPIC_X_PADDING = 30
    @JOINT_WIDTH = 16 # 折叠点的宽度

  go: ->
    root_topic = @mindmap.root_topic

    # 第一次遍历：深度优先遍历
    # 渲染所有节点并且计算各个节点的布局数据
    @_layout_r1 root_topic

    # 第二次遍历：宽度优先遍历
    # 定位所有节点
    root_topic.pos 0, 0
    @_layout_r2 root_topic


  ## TODO 重构
  _layout_r1: (topic)->
    # 如果不是一级子节点/根节点，根据父节点的 side 来为当前节点的 side 赋值
    if topic.depth > 1
      topic.side = topic.parent.side


    # 如果是根节点，分成左右两侧计算布局数据
    if topic.is_root()
      topic.layout_left_children_height = 0
      topic.layout_right_children_height = 0

      topic.left_children_each (i, child)=>
        @_layout_r1 child
        topic.layout_left_children_height += child.layout_area_height + @TOPIC_Y_PADDING
      topic.layout_left_children_height -= @TOPIC_Y_PADDING

      topic.right_children_each (i, child)=>
        @_layout_r1 child
        topic.layout_right_children_height += child.layout_area_height + @TOPIC_Y_PADDING
      topic.layout_right_children_height -= @TOPIC_Y_PADDING

      topic.render()

      return

    
    topic.layout_left_children_height  = 0
    topic.layout_right_children_height = 0
    if topic.is_opened()
      for child in topic.children
        @_layout_r1 child
        topic.layout_left_children_height  += child.layout_area_height + @TOPIC_Y_PADDING
        topic.layout_right_children_height += child.layout_area_height + @TOPIC_Y_PADDING

      topic.layout_left_children_height  -= @TOPIC_Y_PADDING
      topic.layout_right_children_height -= @TOPIC_Y_PADDING

    topic.render() # 生成 dom，同时计算 topic.layout_height
    topic.layout_area_height = Math.max topic.layout_height, topic.layout_left_children_height


  _layout_r2: (topic)->
    mid_y = topic.layout_top + topic.layout_height / 2.0

    # 左侧
    topic.layout_left_children_top   = mid_y - topic.layout_left_children_height / 2.0
    topic.layout_left_children_right = topic.layout_left - @TOPIC_X_PADDING

    t = topic.layout_left_children_top
    topic.left_children_each (i, child)=>
      left = topic.layout_left_children_right - child.layout_width
      top = t + (child.layout_area_height - child.layout_height) / 2.0
      child.pos left, top
      @_layout_r2 child

      t += child.layout_area_height + @TOPIC_Y_PADDING


    # 右侧
    topic.layout_right_children_top  = mid_y - topic.layout_right_children_height / 2.0
    topic.layout_right_children_left = topic.layout_left + topic.layout_width + @TOPIC_X_PADDING

    t = topic.layout_right_children_top
    topic.right_children_each (i, child)=>
      left = topic.layout_right_children_left
      top  = t + (child.layout_area_height - child.layout_height) / 2.0
      child.pos left, top
      @_layout_r2 child

      t += child.layout_area_height + @TOPIC_Y_PADDING

  draw_lines: ->
    # console.log '开始画线'
    root_topic = @mindmap.root_topic
    @_d_r root_topic

  _d_r: (topic)->
    if topic.has_children()
      # 如果当前节点有子节点，则创建针对该子节点的 canvas 图层
      ctx = @_init_canvas_on topic
      for child in topic.children
        # 每个子节点画一条曲线
        @_draw_line topic, child, ctx
        @_d_r child

  _init_canvas_on: (topic)->
    # 根节点
    if topic.is_root()
      left  = topic.layout_left_children_right - 50 # 左侧子节点的右边缘，向左偏移 50px
      right = topic.layout_right_children_left + 50 # 右侧子节点的左边缘，向右偏移 50px

      top = Math.min topic.layout_left_children_top, topic.layout_right_children_top # 所有子节点的上边缘
      bottom_left  = topic.layout_left_children_top + topic.layout_left_children_height # 左侧总高度
      bottom_right = topic.layout_right_children_top + topic.layout_right_children_height # 右侧总高度
      bottom = Math.max bottom_left, bottom_right

      # console.log left, right, top, bottom

    else
      # 左侧节点
      if topic.side is 'left'
        left  = topic.layout_left_children_right - 50 # 所有子节点的右边缘，向左偏移 50px
        right = topic.layout_left + topic.layout_width # 当前节点的右边缘

      # 右侧节点
      if topic.side is 'right'
        left  = topic.layout_left # 当前节点的左边缘
        right = topic.layout_right_children_left + 50 # 所有子节点的左边缘，向右偏移 50px

      top    = topic.layout_left_children_top # 所有子节点的上边缘
      bottom = top + topic.layout_left_children_height # 所有子节点的下边缘

    # 计算 canvas 区域宽高
    width  = right - left
    height = bottom - top

    if not topic.$canvas
      topic.$canvas = jQuery '<canvas>'

    topic.$canvas
      .css
        'left': left
        'top': top
        'width': width
        'height': height
      .attr
        'width': width
        'height': height
      .appendTo @mindmap.$topics_area    

    ctx = topic.$canvas[0].getContext '2d'
    ctx.clearRect 0, 0, width, height
    ctx.translate -left, -top

    return ctx

  _draw_line: (parent, child, ctx)->
    # 在父子节点之间绘制连线
    if parent.is_root()
      @_draw_line_0 parent, child, ctx
      return

    # 其他非根节点，这里要区分左右
    if parent.side is 'left'
      @_draw_line_n_left parent, child, ctx
    else if parent.side is 'right'
      @_draw_line_n_right parent, child, ctx

  # 在根节点上绘制曲线
  _draw_line_0: (parent, child, ctx)->
    # 绘制贝塞尔曲线
    # 两个端点
    # 父节点的中心点
    x0 = parent.layout_left + parent.layout_width / 2.0
    y0 = parent.layout_top  + parent.layout_height / 2.0

    # 这里要区分左右子节点
    if child.side is 'left'
      # 子节点的右侧中点
      x1 = child.layout_left + child.layout_width
    if child.side is 'right'
      # 子节点的左侧中点
      x1 = child.layout_left
    
    y1 = child.layout_top + child.layout_height / 2.0

    # 两个控制点
    if child.side is 'left'
      xc1 = x0 - 30
    if child.side is 'right'
      xc1 = x0 + 30 
    
    yc1 = y0

    xc2 = (x0 + x1) / 2.0
    yc2 = y1 

    ctx.lineWidth = 2
    ctx.strokeStyle = '#666'

    ctx.beginPath()
    ctx.moveTo x0, y0
    ctx.bezierCurveTo xc1, yc1, xc2, yc2, x1, y1 
    ctx.stroke()

  _draw_line_n_left: (parent, child, ctx)->
    # 绘制贝塞尔曲线
    # 两个端点
    # 父节点的左侧中点
    x0 = parent.layout_left - @JOINT_WIDTH
    y0 = parent.layout_top  + parent.layout_height / 2.0

    # 子节点的右侧中点
    x1 = child.layout_left + child.layout_width
    y1 = child.layout_top + child.layout_height / 2.0

    # 两个控制点
    xc1 = (x0 + x1) / 2.0
    yc1 = y0

    xc2 = xc1
    yc2 = y1

    ctx.lineWidth = 2
    ctx.strokeStyle = '#666'

    ctx.beginPath()
    ctx.moveTo x0, y0
    ctx.bezierCurveTo xc1, yc1, xc2, yc2, x1, y1 
    ctx.stroke()

  _draw_line_n_right: (parent, child, ctx)->
    # 绘制贝塞尔曲线
    # 两个端点
    # 父节点的右侧中点
    x0 = parent.layout_left + parent.layout_width + @JOINT_WIDTH
    y0 = parent.layout_top  + parent.layout_height / 2.0

    # 子节点的左侧中点
    x1 = child.layout_left
    y1 = child.layout_top + child.layout_height / 2.0

    # 两个控制点
    xc1 = (x0 + x1) / 2.0
    yc1 = y0

    xc2 = xc1
    yc2 = y1

    ctx.lineWidth = 2
    ctx.strokeStyle = '#666'

    ctx.beginPath()
    ctx.moveTo x0, y0
    ctx.bezierCurveTo xc1, yc1, xc2, yc2, x1, y1 
    ctx.stroke()

window.BasicLayout = BasicLayout