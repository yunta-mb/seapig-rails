class CreateSeapigVersions < ActiveRecord::Migration
  def change
    create_table :seapig_dependencies do |t|
      t.text :name
      t.bigint :current_version
      t.bigint :reported_version

      t.timestamps null: false
    end
    
    execute 'CREATE INDEX ON seapig_dependencies(name,current_version)'
    execute 'CREATE INDEX ON seapig_dependencies((current_version != reported_version)) WHERE current_version != reported_version'
    execute 'CREATE SEQUENCE seapig_dependency_version_seq OWNED BY seapig_dependencies.current_version'
  end
end

# insert into seapig_dependencies (name,current_version,reported_version,created_at,updated_at) select 'reported' || generate_series, generate_series, generate_series, now(), now() from generate_series(1,1000000);
# insert into seapig_dependencies (name,current_version,reported_version,created_at,updated_at) select 'not-reported' || generate_series, generate_series, generate_series - 1 , now(), now() from generate_series(1,1000);
