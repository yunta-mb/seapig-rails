class SeapigRouterSessionState < ActiveRecord::Base

	belongs_to :seapig_router_session

	acts_as_seapig_dependency

end
