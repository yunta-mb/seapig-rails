class @SeapigRouter


        constructor: (seapig_server, session_id, mountpoint, initial_search, debug = false)->
                @seapig_server = seapig_server
                @session_id = session_id
                @mountpoint = mountpoint
                @debug = debug
                @initial_search = initial_search

                @state = {session_id: @session_id, id: 0}
                @volatile = {}

                @session_data = @seapig_server.master('web-session-data-'+@session_id)
                @session_data.object.states = [ @state ]
                @session_data.sequence = 1
                @session_data.bases = {}
                @session_data.diffs = {}
                @session_data.changed()

                @session_data_saved = @seapig_server.slave('web-session-saved-'+@session_id)
                @session_data_saved.onchange = ()=>
                        return if not @session_data_saved.valid
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
                        previous_state = JSON.parse(JSON.stringify(@state))
                        @state = data.state
                        @update_location()
                        @onstatechange(@state,previous_state) if @onstatechange?


        url_to_diff: (pathname, search)->
                spl = pathname.split(@mountpoint)
                spl.shift()
                spl = spl.join(@mountpoint).split('/')
                if spl.shift() == 'a'
                        path_session_id = spl.shift()
                        path_state_id = spl.shift()
                        if not path_state_id
                                return { replace: @mountpoint+'a/'+@session_id+'/0'+window.location.search }
                else
                        return { replace: @mountpoint+'a/'+@session_id+'/0?'+(@initial_search.replace(/^\?/,'')+window.location.search.replace(/^\?/,'&')).replace(/^&/,'') }

                total_diff = []
                partial_diff = []
                while spl.length > 0
                       total_diff.push([spl.shift(),spl.shift()])
                if search.length > 1
                        for pair in search.split('?')[1].split('&')
                                total_diff.push(pair.split('=',2))
                                partial_diff.push(pair.split('=',2))

                console.log('Parsed location: session_id:',path_session_id,' partial_diff:', partial_diff) if @debug

                { total: total_diff, partial: partial_diff, session_id: path_session_id, state_id: path_state_id }


        location_changed: () ->
                return if @replacing_state
                console.log('ROUTER: Location changed to:    pathname:', window.location.pathname, '    search:', window.location.search) if @debug

                diff = @url_to_diff(window.location.pathname,window.location.search)
                if diff.replace?
                        console.log('ROUTER: Invalid url, replacing with:', diff.replace) if @debug
                        window.history.replaceState(@state,null,diff.replace)
                        return @location_changed()

                if diff.session_id == @session_id
                        @state_change(diff.partial)
                else
                        if @remote_state?
                                @state_change_to_remote(diff.total) #oaueia
                        else
                                @state_valid = false
                                if diff.state_id == '0'
                                        @state = {session_id: diff.session_id, id: 0}
                                        @state_change(diff.total)
                                else
                                        @remote_state = @seapig_server.slave('web-session-state-'+diff.session_id+':'+diff.state_id)
                                        @remote_state.onchange = ()=>
                                                return if not @remote_state.valid
                                                @state = _.clone(@remote_state.object)
                                                @state_change(diff.total)
                                                @remote_state.unlink()
                                                @remote_state = null


        state_commit: () ->
                if @state.uncommitted
                        console.log("Deferred commit") if @debug
                        delete @state.uncommitted
                @session_data.object.states.push(@state)
                @session_data.changed()
                clearTimeout(@commit_timer) if @commit_timer
                @commit_at = null
                @commit_timer = null
                @update_location()


        state_change: (diff,defer = 0) ->
                commit_at = Date.now() + defer
                previous_state = JSON.parse(JSON.stringify(@state))
                if diff.length > 0
                        console.log("Applying change at:", defer, commit_at,"to",@state) if @debug
                        next_state = @state
                        if not @state.uncommitted?
                                base_state = @state
                                next_state = _.clone(@state)
                                next_state.session_id = @session_id
                                next_state.id = @session_data.sequence++
                                @session_data.bases[next_state.id] = base_state
                                @session_data.diffs[next_state.id] = []
                        next_state = @state_diff_apply(next_state, diff)
                        console.log("Pre-filter next-state", next_state)
                        @statefilter(next_state,previous_state) if @statefilter?
                        console.log("Post-filter next-state", next_state)
                        @state = next_state
                        @session_data.diffs[@state.id] = @session_data.diffs[@state.id].concat(diff)
                        if commit_at <= Date.now()
                                @state_commit()
                        else
                                @state.uncommitted = true
                                if (not @commit_at) or (commit_at < @commit_at)
                                        console.log("Deferring commit by,till:", commit_at - Date.now(), commit_at) if @debug
                                        clearTimeout(@commit_timer) if @commit_timer
                                        @commit_at = commit_at
                                        @commit_timer = setTimeout((()=> @state_commit()), @commit_at - Date.now())

                @state_valid = true
                @onstatechange(@state,previous_state) if @onstatechange?


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
                                        (obj[spl[spl.length-1]] ||= []).push(value)
                        else
                                if hash
                                        delete obj[spl[spl.length-1]]
                                else
                                        obj[spl[spl.length-1]].splice(_.indexOf(obj[spl[spl.length-1]], value),1)
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
                        path_overlay += @state_diff_to_path(@session_data.diffs[state.id])

                console.log('Calculated url:',@mountpoint+'a/'+base_state.session_id+'/'+base_state.id+path_overlay) if @debug
                @mountpoint+'a/'+base_state.session_id+'/'+base_state.id+path_overlay


        update_location: () ->
                console.log("ROUTER: State changed to:    state:", @state, '    url:', @current_url()) if @debug
                @replacing_state = true
                window.history.replaceState(@state,null,@current_url())
                @replacing_state = false


        stealth_change: (query, defer = 1000) ->
                [pathname, search] = query.split("?")
                pathname = window.location.pathname if pathname.length == 0
                diff = @url_to_diff(pathname,"?"+(search or ""))
                @state_change(diff.partial,defer)
