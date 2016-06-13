require './config/environment.rb'

class SeapigRouterSessionStateProducer < Producer

	@patterns = [ 'web-session-state-*' ]


	def self.produce(object_id)
		object_id =~ /web-session-state-([^-]+)\:(\d+)/
		session_key = $1
		state_id = $2.to_i
		version = Time.new.to_f
		session = SeapigRouterSession.find_by(key: session_key)
		return [false, SeapigDependency.versions('SeapigRouterSessionState#'+session_key)] if not session
		state = SeapigRouterSessionState.find_by(seapig_router_session_id: session.id, state_id: state_id)
		return [false, SeapigDependency.versions('SeapigRouterSessionState#'+session_key)] if not state
		data = state.state
		[data, version]
	end

end
