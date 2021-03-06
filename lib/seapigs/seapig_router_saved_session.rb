require './config/environment.rb'

class SeapigRouterSessionSaved < Producer

	@patterns = [ 'web-session-saved-*' ]


	def self.produce(object_id)
		object_id =~ /web-session-saved-([^-]+)/
		session_key = $1
		version = SeapigDependency.versions('SeapigRouterSessionState#'+session_key)
		session = SeapigRouterSession.find_by(key: session_key)
		return [false, version] if not session
		max_state = session.seapig_router_session_states.order("state_id DESC").first
		data = {
			max_state_id: (max_state and max_state.state_id or -1)
		}
		[data, version]
	end

end
