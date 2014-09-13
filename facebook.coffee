###
Copyright © 2014 Jesse the Game

Embeds the Facebook JS sdk into Angular JS.

licence: MIT-style license

Bits taken from
https://github.com/Ciul/angular-facebook/blob/master/lib/angular-facebook.js

authors:
  - Ciul
###
angular.module 'facebook', []

.provider 'facebook', ->
  @config =
    appId        : undefined # App ID
    status       : true      # check login status
    cookie       : true      # enable cookies to give server access to session
    xfbml        : true      # parse XFBML

  @settings =
    locale       : 'en_gb'
    autoLogin    : yes     # Automatically try to login on load
    autoIdentify : yes     # Get the user information on login
    autoRoot     : yes     # Insert #fb-root div to the top of the document
    autoScript   : yes     # Insert <script async> tag to load the FB sdk
    quiet        : no      # Output log information or not

  @session =
    user: null
    status: undefined

  @log = (args...) =>
    console.log args... unless @settings.quiet

  @insertRoot = ->
    return if document.getElementById 'fb-root'
    fbroot = document.createElement 'div'
    fbroot.id = 'fb-root'
    document.body.insertBefore fbroot, document.body.childNodes[0]

  @insertScript = ->
    src           = "//connect.facebook.net/#{facebook.settings.locale}/all.js"
    script        = document.createElement 'script'
    script.id     = 'facebook-jssdk'
    script.async  = true

    # Prefix protocol when testing locally
    src = 'https:' + src if window.location.protocol is 'file'

    script.src = src

    # TODO: Fix for IE < 9, and yet supported by latest browsers
    head = document.getElementsByTagName('head')[0]
    head.appendChild script

  # facebook.picture user, 'large'
  # facebook.picture 123456, 400, 400
  @picture = (id_or_obj, type_or_width, height) ->
    id = if typeof id_or_obj is 'string' then id_or_obj else id_or_obj?.id

    return null unless id

    query = switch
      when height
        "?width=#{type_or_width}&height=#{height}"
      when type_or_width
        "?type=#{type_or_width}"
      else
        ""

    scheme = if window.location.protocol is 'file' then 'https:' else ''

    "#{scheme}//graph.facebook.com/#{id}/picture#{query}"

  @$get = ['$q', '$rootScope', ($q, $rootScope) =>
    sdkdfd = $q.defer()

    @sdk = sdkdfd.promise.then

    @api = (args...) =>
      @sdk (FB) ->
        FB.api args...

    @init = (FB) =>
      FB.init @config
      sdkdfd.resolve FB

    @on = (event, callback) ->
      $rootScope.$on "facebook:#{event}", callback

    ###
    # TODO introduce rootScope.$off ?
    facebook.off = (event, callback) ->
      $rootScope.$off "facebook:#{event}", callback
    ###

    # Options include
    # `scope`: comma separated permissions to be granted by connecting user
    #
    # Read full documentation here
    # https://developers.facebook.com/docs/reference/javascript/FB.login
    @login = (options) =>
      dfd = $q.defer()

      @sdk (FB) ->
        FB.getLoginStatus ({status, authResponse}) ->
          if status == 'connected'
            dfd.resolve authResponse
          else
            FB.login ({authResponse}) ->
              dfd.resolve authResponse
            , options

      dfd.promise

    @logout = =>
      dfd = $q.defer()

      @sdk (FB) ->
        FB.logout dfd.resolve

      dfd.promise

    @identify = =>
      dfd = $q.defer()

      @api '/me', (user) =>
        #TODO error handling?
        @log "Good to see you, #{user.name}" unless @settings.quiet
        user.picture = @picture user, 'large'
        @session.user = user
        $rootScope.$broadcast 'facebook:auth.identify'
        dfd.resolve user

      dfd.promise

    this
  ]

  this

.run ['facebook', '$rootScope', '$window', (facebook, $rootScope, $window) ->
  $rootScope.facebook = facebook

  facebook.on 'auth.authResponseChange', (event, data) ->
    facebook.session.status = data.status
    facebook.session.auth = data.authResponse

  facebook.on 'auth.statusChange', (event, data) ->
    switch data.status
      when 'connected'
        facebook.identify() if facebook.settings.autoIdentify
      when 'not_authorized'
        facebook.login() if facebook.flags.autoLogin
      else
        facebook.login() if facebook.flags.autoLogin

  # This is called by the FB sdk when its script is loaded
  $window.fbAsyncInit = ->
    for event in [
      'edge.create'
      'edge.remove'
      'xfbml.render'
      'auth.authResponseChange'
      'auth.statusChange'
      'auth.sessionChange'
      'auth.login'
      'auth.logout'
      'auth.prompt'
      'comments.create'
      'comments.remove'
      'message.send'
    ]
      do (event) ->
        $window.FB.Event.subscribe event, (data) ->
          $rootScope.$broadcast "facebook:#{event}", data

    facebook.init $window.FB

  facebook.insertRoot() if facebook.settings.autoRoot
  facebook.insertScript() if facebook.settings.autoScript
]

