@e = (content)->
        content.__seapig_binding_element__ = {
                }
        content


class @SeapigBinding


        constructor: (seapig_server, options = {})->
                @seapig_server = seapig_server
                @debug = options.debug
                @view(options.view) if options.view
                @onchange = options.onchange
                @valid = false
                @initialized = false
                @object = false
                @object_id = null
                @elements = null
                @shadow = { __seapig_binding_element__: {state: {},conflict: {},updated_at: {}}}
                @selector = (data) -> data
                @model(options.model) if options.model?

        state: (element)->

        view: (view)->
                $(document).on('click',view+' .seapig-binding-element-delete', (event) =>
                        console.log('BINDING: A-element clicked.',event) if @debug
                        element = @element_find(event.target)
                        @element_remove(element[0],element[1],$(dom_element).hasClass('seapig-bindind-autosave'))
                        false
                        )


        #FIXME: OOize all element_* methods

        element_remove: (parent,id,save)->
                console.log("removing", parent, id) if @debug

        element_find: (dom_element)->
                path = []
                while dom_element
                        id = $(dom_element).attr('data-seapig-binding-element')
                        path.push(id) if id
                        dom_element = dom_element.parentElement
                path = path.reverse()
                id = path.pop()
                parent = @elements
                for step in path
                        parent = parent[step]
                [parent, id]


        update_element: (elements, key, shadows, shadow_key, element, remote) ->
                        if typeof(remote) == "object"
                                if typeof(remote) == "undefined"                                                       #delete
                                        delete elements[key]
                                        delete shadows[shadow_key]
                                else
                                        if (element? != remote?) or (typeof(element) != typeof(remote)) or (Array.isArray(element) != Array.isArray(remote))  #(re-)create
                                                element = if remote == null then null else if Array.isArray(remote) then [] else {}
                                                shadows[shadow_key] = { __seapig_binding_element__: {state: {},conflict: {},updated_at: {}}}
                                        elements[key] = element
                                        @update(elements[key],shadows[shadow_key],remote) if element?                  #update
                        else
                                if typeof(remote) == "undefined"                                                       #delete
                                        delete elements[key]
                                        delete shadows[shadow_key]
                                else                                                                                   #update
                                        elements[key] = remote
                                        if element != remote
                                                shadows[shadow_key] ||= { __seapig_binding_element__: {state: {},conflict: {},updated_at: {}}}
                                                shadows[shadow_key].__seapig_binding_element__.updated_at[key] = new Date()


        update: (elements, shadow, remotes)->
                throw "wut? a vampaya?" if not shadow?
                console.log("updating",elements,shadow,remotes) if @debug


                if Array.isArray(elements)
                        console.log('array') if @debug
                        elements_by_id = _.object(([(e? and e.id or i), e] for e,i in elements))
                        remotes_by_id = _.object(([(e? and e.id or i), e] for e,i in remotes))
                        shadow_shadow = _.object([k,v] for k,v of shadow)
                        console.log("elements_by_id, remotes_by_id", elements_by_id, remotes_by_id ) if @debug

                        added_elements = _.difference(_.keys(remotes_by_id),_.keys(elements_by_id))
                        removed_elements = _.difference(_.keys(elements_by_id),_.keys(remotes_by_id))
                        console.log("added", added_elements) if @debug
                        console.log("removed", removed_elements) if @debug
                        elements.length = 0
                        shadow.length = 0
                        for remote_element,i in remotes
                                id = (remote_element? and remote_element.id or i)
                                element = elements_by_id[id]
                                console.log('adding',remote_element,id,element) if @debug
                                @update_element(elements,i,shadow,id,element,remote_element)
                        console.log(elements) if @debug

                else
                        console.log('object') if @debug
                        added_elements = _.difference(_.keys(remotes),_.keys(elements))
                        common_elements = _.intersection(_.keys(remotes),_.keys(elements))
                        removed_elements = _.difference(_.keys(elements),_.keys(remotes))
                        console.log("added", added_elements) if @debug
                        console.log("common", common_elements) if @debug
                        console.log("removed", removed_elements) if @debug

                        for element in added_elements
                                @update_element(elements,element,shadow,element,elements[element],remotes[element])

                        for element in removed_elements
                                switch shadow.__seapig_binding_element__.state[element]
                                        when 'clean', undefined
                                                @update_element(elements,element,shadow,element,elements[element],remotes[element])
                                        else
                                                console.log('filth! 1')

                        for element in common_elements
                                switch shadow.__seapig_binding_element__.state[element]
                                        when 'clean', undefined
                                                @update_element(elements,element,shadow,element,elements[element],remotes[element])
                                        else
                                                console.log('filth! 2')



        model: (object_id)->
                return if object_id == @object_id
                @object_id = object_id

                if @object
                        @object.unlink()
                        @valid = false
                        @initialized = false

                if @object_id
                        @object = @seapig_server.slave(@object_id)
                        @object.onchange = ()=>
                                if @object.valid
                                        console.log('BINDING: Data update received.') if @debug
                                        new_elements = @selector(JSON.parse(JSON.stringify(@object.object)))
                                        @elements ||= (if Array.isArray(new_elements) then [] else {})
                                        @shadow ||= (if Array.isArray(new_elements) then [] else {})
                                        @update(@elements,@shadow,new_elements)
                                        @initialized = true
                                        console.log(@elements) if @debug
                                @valid = @object.valid
                                @onchange() if @onchange
                        @data = @object.object

                @onchange() if @onchange
