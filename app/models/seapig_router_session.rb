class SeapigRouterSession < ActiveRecord::Base

	has_many :seapig_router_session_states

	acts_as_seapig_dependency


	def self.generate
		session = SeapigRouterSession.new
		begin
			session.key = (('a'..'z').to_a + ('A'..'Z').to_a + (0..9).to_a).shuffle[0..10].join('')
			session.save!
		rescue ActiveRecord::RecordNotUnique
			retry
		end
		session
	end

end
