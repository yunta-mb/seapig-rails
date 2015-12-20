class @SeapigServer


        constructor: (url, options = {})->
                @url = url
                @options = options
                @slave_objects = {}
                @master_objects = {}
                @connect()


        connect: () ->
                @connected = false

                @socket = new WebSocket(@url,'SeaPig-0.0')

                @socket.onerror = (error) =>
                        console.log('Seapig socket error', error)
                        @socket.close()

                @socket.onclose = () =>
                        console.log('Seapig connection closed')
                        for object_id, object of @slave_objects
                                object.valid = false
                        setTimeout((=>@connect()), 2000)

                @socket.onopen = () =>
                        console.log('Seapig connection opened')
                        @connected = true
                        @socket.send(JSON.stringify(action: 'client-options-set', options: @options))
                        for object_id, object of @slave_objects
                                @socket.send(JSON.stringify(action: 'object-consumer-register', id: object_id, latest_known_version: object.version))

                @socket.onmessage = (event) =>
                        #console.log('Seapig message received', event)
                        data = JSON.parse(event.data)
                        switch data.action
                                when 'object-update'
                                        @slave_objects[data.id].patch(data) if @slave_objects[data.id]
                                else
                                        console.log('Seapig received a stupid message', data)


        slave: (object_id) ->
                @socket.send(JSON.stringify(action: 'object-consumer-register', id: object_id, latest_known_version: null)) if @connected
                @slave_objects[object_id] = new SeapigObject(object_id)


        unlink: (object_id) ->
                delete @slave_objects[object_id]
                @socket.send(JSON.stringify(action: 'unlink', id: object_id)) if @connected



class SeapigObject


        constructor: (id) ->
                @id = id
                @valid = false
                @version = null
                @object = {}
                @shadow = {}
                @onchange = null


        patch: (data) ->
                if not data.old_version?
                        delete @object[key] for key, value of @object
                else if not _.isEqual(@version, data.old_version)
                        console.log("Seapig lost some updates, this shouldn't ever happen", @version, data.old_version)
                jsonpatch.apply(@object, data.patch)
                @version = data.new_version
                @valid = true
                @onchange() if @onchange?

        changed: () ->
                @version += 1
                patch = jsonpatch.compare(@shadow, @object)
                console.log(patch)
                @shadow = JSON.parse(JSON.stringify(@object))
