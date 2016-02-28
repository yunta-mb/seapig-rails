class @SeapigRouter


        constructor: (seapig_server, session_id, initial_state, debug = false)->
                @seapig_server = seapig_server
                @session_id = session_id
                @debug = debug

                @state = _.extend({session_id: @session_id, id: 0}, initial_state)

                @session_data = @seapig_server.master('web-session-data-'+@session_id)
                @session_data.object.states = [ @state ]
                @session_data.sequence = 1
                @session_data.changed()

                @session_data_saved = @seapig_server.slave('web-session-saved-'+@session_id)
                @session_data_saved.onchange = ()=>
                        while @session_data.object.states[0]? and @session_data.object.states[0].id < @session_data_saved.object.max_state_id
                                @session_data.object.states.shift()
                        @replacing_state = true
                        window.history.replaceState(@state,null,@current_url())
                        @replacing_state = false


                @replacing_state = false
                @state_valid = false

                $(document).on('click','a', (event) =>
                        console.log('ROUTER: A-element clicked, changing location to:', event.target.href) if @debug
                        return true if not event.target.href[0] == '?'
                        window.history.pushState(null,null,event.target.href)
                        @location_changed()
                        false
                        )

                window.onpopstate = (data) =>
                        @state = data.state
                        @state_changed()



        location_changed: () ->
                return if @replacing_state
                console.log('ROUTER: Location changed to:    pathname:', window.location.pathname, '    search:', window.location.search) if @debug

                spl = window.location.pathname.split('/')
                if spl[1] == 'a'
                        path_session_id = spl[2]
                        path_state_id = spl[3]
                else
                        path_session_id = @session_id
                        path_state_id = 0

                overlay = {}
                if window.location.search.length > 0
                        for pair in window.location.search.split('?')[1].split('&')
                                spl = pair.split('=',2)
                                overlay[spl[0]] = spl[1]

                if path_session_id == @session_id
                        @state_change(overlay)
                else
                        if @remote_state?
                                @state_change_to_remote(overlay)
                        else
                                @state_valid = false
                                @remote_state = @seapig_server.slave('web-session-state-'+path_session_id+':'+path_state_id)
                                @remote_state.onchange = ()=> @state_change_to_remote(overlay)


        state_change_to_remote: (overlay) ->
                @state = _.clone(@remote_state.object)
                if _.size(overlay) > 0
                        @state_change(overlay)
                else
                        @state_valid = true
                        @state_changed()


        state_change: (overlay) ->
                @state = _.extend(_.clone(@state), overlay)
                @statefilter(@state) if @statefilter?
                @state.session_id = @session_id
                @state.id = @session_data.sequence++
                @session_data.object.states.push(@state)
                @session_data.changed()
                if @remote_state?
                        @remote_state.unlink()
                        @remote_state = null
                @state_valid = true
                @state_changed()


        current_url: ()->
                '/a/'+@state.session_id+'/'+@state.id+(if (@session_data_saved.object.max_state_id >= @state.id or @state.session_id != @session_id) then '' else '#NOT-SHAREABLE')

        state_changed: () ->

                console.log("ROUTER: State changed to:    state:", @state, '    url:', @current_url()) if @debug
                @replacing_state = true
                window.history.replaceState(@state,null,@current_url())
                @replacing_state = false

                @onstatechange(@state) if @onstatechange?
