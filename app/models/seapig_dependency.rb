class SeapigDependency < ActiveRecord::Base

	def self.bump(*names) #FIXME: mass upsert / PG 9.5
		versions = {}
		self.transaction {
			names.map { |name|
				value = self.find_by_sql(["UPDATE seapig_dependencies SET current_version = nextval('seapig_dependency_version_seq'), updated_at = now() WHERE name = ? RETURNING current_version", name])
				value = self.find_by_sql(["INSERT INTO seapig_dependencies(name, current_version, reported_version, created_at, updated_at) VALUES (?,nextval('seapig_dependency_version_seq'),0,now(),now()) RETURNING current_version",name]) if value.size == 0
				versions[name] = value[0].current_version
			}
			connection.instance_variable_get(:@connection).exec("NOTIFY seapig_dependency_changed")
		}
		versions
	end


	def self.version(name)
		self.versions(name)[name]
	end


	def self.versions(*names)
		Hash[*self.find_by_sql(["SELECT names.name, COALESCE(sd.current_version,0) AS current_version FROM (SELECT unnest(ARRAY[?]) AS name) AS names LEFT OUTER JOIN seapig_dependencies AS sd ON names.name = sd.name", names]).map { |name| [name.name,name.current_version] }.flatten]
	end


end
