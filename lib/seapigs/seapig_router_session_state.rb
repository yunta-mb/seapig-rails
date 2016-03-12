require './config/environment.rb'

class SeapigRouterSessionStateProducer < Producer

	@patterns = [ 'web-session-state-*' ]


	def self.produce(object_id)
		object_id =~ /web-session-state-([^-]+)\:(\d+)/
		session_key = $1
		state_id = $2.to_i
		version = Time.new.to_f
		p session_key, object_id
		session = SeapigRouterSession.find_by(key: session_key)
		state = SeapigRouterSessionState.find_by(seapig_router_session_id: session.id, state_id: state_id)
		return [false, {SeapigRouterSessionState: SeapigRouterSessionState.seapig_dependency_version}] if not state
		data = state.state
		[data, version]
	end

end
