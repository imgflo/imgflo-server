hasClassName = (el, name) ->
  new RegExp('(?:^|\\s+)' + name + '(?:\\s+|$)').test el.className

addClassName = (el, name) ->
  if !hasClassName(el, name)
    el.className = if el.className then [
      el.className
      name
    ].join(' ') else name
  return

removeClassName = (el, name) ->
  if hasClassName(el, name)
    c = @className
    el.className = c.replace(new RegExp('(?:^|\\s+)' + name + '(?:\\s+|$)', 'g'), '')
  return

### TODO:
# - make input picking a dialog "paste URL here"
# - hide output URL, use "copy image link" instead
# - move execute button down, change to spinner when processing (font-awesome?)
# - move graph details to below the graph selector
#
# - Don't show auth input fields all the time.
# If authed, checkmark OK. Not authed, allow to drop down to enter.
# - Allow to register new API keys "apps"
# - Allow to copy API keys/secret pair out.
# - Link out to API docs
#
# - add selected/deselected indicator to graph list
# - add invalidated/working/completed indicator on processed image
# - add API/authentication status element to header, shows when authed correctly
# -
# - make images use up available space vertically, centered
#
# Maybe
# - make HEAD request to check if image is cached,
# and then show without pressing execute?
#
# Later:
#
# - allow to upload image
# - allow to take picture with webcam
# - add progress bar for request processing.
# - add persisted history, with prev/next buttons in pictureSection
###

getDemoData = (callback) ->
  req = new XMLHttpRequest

  req.onreadystatechange = ->
    if req.readyState == 4
      if req.status == 200
        d = JSON.parse(req.responseText)
        return callback(null, d)
      else
        e = new Error(req.status)
        return callback(e, null)
    return

  req.open 'GET', '/graphs', true
  req.send()
  return

getVersionInfo = (callback) ->
  req = new XMLHttpRequest

  req.onreadystatechange = ->
    if req.readyState == 4
      if req.status == 200
        d = JSON.parse(req.responseText)
        return callback(null, d)
      else
        e = new Error(req.status)
        return callback(e, null)
    return

  req.open 'GET', '/version', true
  req.send()
  return

createGraphProperties = (container, name, graph, values) ->
  if typeof graph.inports == 'undefined'
    return null
  inports = Object.keys(graph.inports)
  inports.forEach (name) ->
    port = graph.inports[name]
    console.log 'p', name, port.metadata
    value = values[name]
    if name == 'input'
      return
    portInfo = document.createElement('li')
    portInfo.className = 'line'
    portName = document.createElement('label')
    portName.className = 'portLabel'
    portInput = document.createElement('input')
    portName.innerHTML = '<span>' + name + '</span>'

    # set an appropriate type
    # TODO: set min and max, if exists. Maybe use range??
    def = port.metadata?.default
    type = port.metadata?.type
    if type == 'int'
      portInput.type = 'number'
      if port.metadata.minimum? and port.metadata.maximum?
        portInput.step = (port.metadata.maximum - port.metadata.minimum)/20
        portInput.min = port.metadata.minimum
        portInput.max = port.metadata.maximum
      else
        portInput.step = 1.0
    else if type == 'number'
      portInput.type = 'number'
      if port.metadata.minimum? and port.metadata.maximum?
        portInput.min = port.metadata.minimum
        portInput.max = port.metadata.maximum
        portInput.step = (port.metadata.maximum - port.metadata.minimum)/20
      else
        portInput.step = 0.25
    else if type == 'enum' and port.metadata.values?
      portInput = document.createElement('select')
      for v in port.metadata.values
        i = document.createElement('option')
        i.value = v
        i.innerHTML = v
        if v == value
          i.selected = true
        else if v == def
          i.selected = true
        portInput.appendChild i
    else if type == 'boolean'
      portInput.type = 'checkbox'
      portInput.value = if def then 'on' else 'off' if def?
    else if type == 'color'
      # TODO: also support opacity in colors. Needs to be a separate widget, 0-100% maybe.
      portInput.type = 'color'
      if def
        def = def.substring(0, 7) if def.length == 9
        portInput.value = def
    else if type == 'buffer'
      # Ignored
    else if type
      console.log 'Warking: Unknown port type', type
      portInput.type = type

    portInput.defaultValue = def if def?
    portInput.placeholder = def.toString() if def?

    portInput.name = name
    portInput.className = 'portInput'

    # show current value
    if typeof value != 'undefined'
      portInput.value = value
    # TODO: show information about type,value ranges, default value, description etc

    # show decription
    description = port.metadata?.description or ""
    portDescription = document.createElement('label')
    portDescription.className = 'portDescription'
    portDescription.innerHTML = '<span>' + description + '</span>'

    portInfo.appendChild portName
    portName.appendChild portInput
    portInfo.appendChild portDescription
    container.appendChild portInfo
    return
  container

createGraphList = (container, graphs, onClicked) ->
  Object.keys(graphs).forEach (name) ->
    if typeof graphs[name].inports != 'undefined'
      graph = graphs[name]
      e = document.createElement('li')
      e.onclick = onClicked
      displayName = name.replace('_', ' ')
      e.className = 'graphEntry'
      p = document.createElement('label')
      p.innerHTML = displayName
      e.appendChild p
      img = document.createElement('img')
      img.src = graph.thumbnailUrl
      e.appendChild img
      e.setAttribute 'data-graph-id', name
      container.appendChild e
    return
  container

createRequestUrl = (graphname, parameters, apiKey, apiSecret) ->
  hasQuery = Object.keys(parameters).length > 0
  search = graphname + (if hasQuery then '?' else '')
  for key of parameters
    value = encodeURIComponent(parameters[key])
    search += key + '=' + value + '&'
  if hasQuery
    search = search.substring(0, search.length - 1)
    # strip trailing &
  url = '/graph/' + search
  if apiKey or apiSecret
    base = search + apiSecret
    token = CryptoJS.MD5(base)
    url = '/graph/' + apiKey + '/' + token + '/' + search
  url

getGraphProperties = (container, name, graphdef) ->
  props = {}
  inputs = Array.prototype.slice.call container.getElementsByTagName('input')
  inputs = inputs.concat Array.prototype.slice.call container.getElementsByTagName('select')
  for input in inputs
    type = graphdef.inports[input.name]
    if input.type == 'checkbox'
      val = input.checked.toString()
      props[input.name] = val if val != input.defaultValue
    else if input.value?
      props[input.name] = input.value if input.value != input.defaultValue

  return props

parseQuery = (qstr) ->
  query = {}
  a = qstr.substr(1).split('&')
  i = 0
  while i < a.length
    b = a[i].split('=')
    query[decodeURIComponent(b[0])] = decodeURIComponent(b[1] or '')
    i++
  query

startsWith = (str, sub) ->
  str.indexOf(sub) == 0

main = ->

  id = (n) ->
    document.getElementById n

  activeGraphName = null
  availableGraphs = null

  readApiInfo = ->
    id('apiKey').value = localStorage['imgflo-server-api-key'] or ''
    id('apiSecret').value = localStorage['imgflo-server-api-secret'] or ''
    return

  readApiInfo()

  id('clearApiInfo').onclick = ->
    localStorage['imgflo-server-api-key'] = ''
    localStorage['imgflo-server-api-secret'] = ''
    readApiInfo()
    return

  processCurrent = ->
    graph = activeGraphName
    props = getGraphProperties(id('graphProperties'), graph, availableGraphs[graph])
    props.input = id('inputUrl').value
    apiKey = id('apiKey').value
    apiSecret = id('apiSecret').value
    localStorage['imgflo-server-api-key'] = apiKey
    localStorage['imgflo-server-api-secret'] = apiSecret
    url = createRequestUrl(graph, props, apiKey, apiSecret)
    bg = 'url("' + url + '")'
    console.log 'processing:', url, bg

    ###
    id('processedImage').onload = function() {
        id('processedImage').className = "visible";
    };
    id('processedImage').src = u;
    ###

    id('processedUrl').value = url
    id('processedImage').style.backgroundImage = bg
    return

  id('runButton').onclick = processCurrent

  setInputUrl = (url) ->
    console.log 'setting input', url
    if !startsWith(url, 'http')
      # Resolve to fully qualified URL
      loc = window.location
      url = loc.protocol + '//' + loc.host + '/' + url
    if id('inputUrl').value != url
      id('inputUrl').value = url
    bg = 'url("' + url + '")'
    id('originalImage').style.backgroundImage = bg
    return

  onInputChanged = (event) ->
    url = id('inputUrl').value
    setInputUrl url
    return

  id('inputUrl').onblur = onInputChanged
  onInputChanged()

  setActiveGraph = (name, properties) ->
    if typeof availableGraphs[name] == 'undefined'
      return false
    activeGraphName = name
    container = id('graphProperties')
    len = container.children.length
    #container.innerHTML = '';
    i = 0
    while i < len
      container.removeChild container.children[0]
      i++
    createGraphProperties container, name, availableGraphs[name], properties
    true

  onGraphClicked = (event) ->
    name = event.currentTarget.getAttribute('data-graph-id')
    console.log 'onGraphClicked', name
    setActiveGraph name, {}
    return

  getDemoData (err, demo) ->
    if err
      throw err
    availableGraphs = demo.graphs
    Object.keys(availableGraphs).forEach (name) ->
      graph = availableGraphs[name]
      props = 
        width: 150
        input: id('inputUrl').value
      apiKey = id('apiKey').value
      apiSecret = id('apiSecret').value
      localStorage['imgflo-server-api-key'] = apiKey
      localStorage['imgflo-server-api-secret'] = apiSecret
      graph.thumbnailUrl = createRequestUrl(name, props, apiKey, apiSecret)
      return
    if startsWith(window.location.pathname, '/debug')
      # Set the UI widgets state based on what is in the URL
      params = parseQuery(window.location.search)
      parts = window.location.pathname.split('/')
      graph = parts[3]
      if parts.length >= 6
        graph = parts[5]
      setInputUrl params.input
      setActiveGraph graph, params
    else
      setActiveGraph 'desaturate', {}
    processCurrent()
    createGraphList id('graphList'), demo.graphs, onGraphClicked
    return
  getVersionInfo (err, res) ->
    version = 'Unknown'
    if !err and res.server
      version = res.server.toString()
    id('version').innerHTML = 'imgflo-server: ' + version
    return
  return

main()

