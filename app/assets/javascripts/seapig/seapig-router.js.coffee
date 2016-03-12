class @SeapigRouter


        constructor: (seapig_server, session_id, initial_search, debug = false)->
                @seapig_server = seapig_server
                @session_id = session_id
                @debug = debug
                @initial_search = initial_search

                @state = {session_id: @session_id, id: 0}

                @session_data = @seapig_server.master('web-session-data-'+@session_id)
                @session_data.object.states = [ @state ]
                @session_data.sequence = 1
                @session_data.bases = {}
                @session_data.changed()

                @session_data_saved = @seapig_server.slave('web-session-saved-'+@session_id)
                @session_data_saved.onchange = ()=>
                        while @session_data.object.states[0]? and @session_data.object.states[0].id < @session_data_saved.object.max_state_id
                                @session_data.object.states.shift()
                        console.log('Session saved, updating url:',@current_url()) if @debug
                        @replacing_state = true
                        window.history.replaceState(@state,null,@current_url()) if @state_valid
                        @replacing_state = false


                @replacing_state = false
                @state_valid = false

                $(document).on('click','a', (event) =>
                        console.log('ROUTER: A-element clicked, changing location to:', $(event.target).attr('href')) if @debug
                        return true if not ($(event.target).attr('href')[0] == '?')
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
                spl.shift()
                if spl.shift() == 'a'
                        path_session_id = spl.shift()
                        path_state_id = spl.shift()
                else
                        window.history.replaceState(@state,null,'/a/'+@session_id+'/0'+@initial_search)
                        return @location_changed()

                total_diff = []
                partial_diff = []
                while spl.length > 0
                       total_diff.push([spl.shift(),spl.shift()])
                if window.location.search.length > 0
                        for pair in window.location.search.split('?')[1].split('&')
                                total_diff.push(pair.split('=',2))
                                partial_diff.push(pair.split('=',2))
                console.log('Parsed location: session_id:',path_session_id,' partial_diff:', partial_diff) if @debug

                if path_session_id == @session_id
                        @state_change(partial_diff)
                else
                        if @remote_state?
                                @state_change_to_remote(total_diff)
                        else
                                @state_valid = false
                                if path_state_id == '0'
                                        @remote_state = {object: {session_id: path_session_id, id: 0}}
                                        @state_change_to_remote(total_diff)
                                else
                                        @remote_state = @seapig_server.slave('web-session-state-'+path_session_id+':'+path_state_id)
                                        @remote_state.onchange = ()=> @state_change_to_remote(total_diff)


        state_change_to_remote: (diff) ->
                @state = _.clone(@remote_state.object)
                if diff.length > 0
                        @state_change(diff)
                else
                        #@session_data.object.states.push(@state)
                        @state_valid = true
                        @state_changed()


        state_change: (diff) ->
                base_state = @state
                @state = @state_diff_apply(_.clone(@state), diff)
                @state.diff = diff
                @statefilter(@state) if @statefilter?
                @state.session_id = @session_id
                @state.id = @session_data.sequence++
                @session_data.bases[@state.id] = base_state
                @session_data.object.states.push(@state)
                @session_data.changed()
                if @remote_state?
                        @remote_state.unlink() if @remote_state.object.id > 0
                        @remote_state = null
                @state_valid = true
                @state_changed()


        state_diff_apply: (state, diff)->
                for entry in diff
                        address = entry[0]
                        value = entry[1]
                        add = (address[0] != '-')
                        hash = (address[address.length-1] != '~')
                        address = address[1..-1] if address[0] == '-'
                        address = address[0..-2] if address[address.length-1] == '~'
                        obj = state
                        spl = address.split('~')
                        for subobj,i in spl
                                if i < (spl.length-1)
                                        obj[subobj] = {} if not obj[subobj]?
                                        obj = obj[subobj]
                        if add
                                if hash
                                        obj[spl[spl.length-1]] = value
                                else
                                        obj[spl[spl.length-1]].push(value)
                        else
                                if hash
                                        delete obj[spl[spl.length-1]]
                                else
                                        state[entry[0]].splice(_.indexOf(state[entry[0]], value),1)
                state


        state_diff_to_path: (diff)->
                ('/'+entry[0]+'/'+entry[1] for entry in diff).join("") or ""


        current_url: ()->
                base_state = @state
                chain = []
                while @session_data.bases[base_state.id] and (@session_id == base_state.session_id) and ((@session_data_saved.object.max_state_id or 0 ) < base_state.id)
                        chain.unshift(base_state)
                        base_state = @session_data.bases[base_state.id]
                console.log('Last shareable url:', base_state, chain) if @debug
                path_overlay = ""
                for state in chain
                        console.log('-',state) if @debug
                        path_overlay += @state_diff_to_path(state.diff)

                console.log('Calculated url:','/a/'+base_state.session_id+'/'+base_state.id+path_overlay) if @debug
                '/a/'+base_state.session_id+'/'+base_state.id+path_overlay


        state_changed: () ->

                console.log("ROUTER: State changed to:    state:", @state, '    url:', @current_url()) if @debug
                @replacing_state = true
                window.history.replaceState(@state,null,@current_url())
                @replacing_state = false

                @onstatechange(@state) if @onstatechange?
