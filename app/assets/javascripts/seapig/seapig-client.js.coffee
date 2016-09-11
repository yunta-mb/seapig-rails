class @SeapigServer


        constructor: (url, options = {})->
                @url = url
                @options = options
                @slave_objects = {}
                @master_objects = {}
                @connect()


        connect: () ->
                @connected = false

                @socket = new WebSocket(@url)

                @socket.onerror = (error) =>
                        console.log('Seapig socket error', error)
                        @socket.close()

                @socket.onclose = () =>
                        console.log('Seapig connection closed') if @options.debug
                        for object_id, object of @slave_objects
                                object.valid = false
                                object.onchange() if object.onchange?
                        setTimeout((=>@connect()), 2000)

                @socket.onopen = () =>
                        console.log('Seapig connection opened') if @options.debug
                        @connected = true
                        @socket.send(JSON.stringify(action: 'client-options-set', options: @options))
                        for object_id, object of @slave_objects
                                @socket.send(JSON.stringify(action: 'object-consumer-register', id: object_id, latest_known_version: object.version))
                        for object_id, object of @master_objects
                                @socket.send(JSON.stringify(action: 'object-producer-register', pattern: object_id))
                                object.upload(0,{})

                @socket.onmessage = (event) =>
                        #console.log('Seapig message received', event)
                        data = JSON.parse(event.data)
                        switch data.action
                                when 'object-update'
                                        @slave_objects[data.id].patch(data) if @slave_objects[data.id]
                                when 'object-produce'
                                        @master_objects[data.id].upload(0,{}) if @master_objects[data.id]
                                else
                                        console.log('Seapig received a stupid message', data)


        slave: (object_id) ->
                @socket.send(JSON.stringify(action: 'object-consumer-register', id: object_id, latest_known_version: 0)) if @connected
                @slave_objects[object_id] = new SeapigObject(@,object_id)


        master: (object_id) ->
                @socket.send(JSON.stringify(action: 'object-producer-register', pattern: object_id)) if @connected
                @master_objects[object_id] = new SeapigObject(@,object_id)


        unlink: (object_id)->
                if @slave_objects[object_id]?
                        delete @slave_objects[object_id]
                        @socket.send(JSON.stringify(action: 'object-consumer-unregister', id: object_id)) if @connected
                if @master_objects[object_id]?
                        delete @master_objects[object_id]
                        @socket.send(JSON.stringify(action: 'object-producer-unregister', id: object_id)) if @connected


class SeapigObject


        constructor: (server,id) ->
                @server = server
                @id = id
                @valid = false
                @version = 0
                @object = {}
                @shadow = {}
                @onchange = null


        patch: (data) ->
                if data.old_version == 0 or data.value?
                        delete @object[key] for key, value of @object
                else if not _.isEqual(@version, data.old_version)
                        console.log("Seapig lost some updates, this shouldn't ever happen. object:",@id," version:", @version, " old_version:", data.old_version)
                if data.value?
                        for key,value of data.value
                                @object[key] = value
                else
                        jsonpatch.apply(@object, data.patch)
                @version = data.new_version
                @valid = true
                @onchange() if @onchange?

        changed: () ->
                old_version = @version
                @version += 1
                old_object = @shadow
                @shadow = JSON.parse(JSON.stringify(@object))
                @upload(old_version, old_object)


        upload: (old_version, old_object)->
                message = {
                        id: @id
                        action: 'object-patch'
                        old_version: old_version
                        new_version: @version
                        patch: jsonpatch.compare(old_object, @shadow)
                        }
                @server.socket.send(JSON.stringify(message)) if @server.connected


        unlink: () ->
                @server.unlink(@id)
