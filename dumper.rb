class Array
  
  def to_sql(*anything)
    bananas = map do |leaf|
      leaf.to_sql(*anything)
    end
    SQLMonkey.sort_out_bananas(bananas)
  end
  
end

module ActiveRecord
  class Base

    def to_sql(baton={})
      TreeClimber.new(self, baton).climb_with(SQLMonkey)
    end
  
    def to_sql_file(filepath, options={})
      File.open(filepath, "w") do |fp|
        fp << to_sql(options)
      end
    end
    
  end
end

module SQLMonkey
  
  extend self
  
  def harvest(model, baton)
    bananas = []
    if baton[:add_deletes]
      bananas << "DELETE FROM #{model.class.quoted_table_name} WHERE #{model.connection.quote_column_name(model.class.primary_key)} = #{model.quoted_id}"
    end
    bananas << "INSERT INTO #{model.class.quoted_table_name} " +
      "(#{model.send(:quoted_column_names).join(', ')}) " +
      "VALUES(#{model.send(:attributes_with_quotes).values.join(', ')})"
    bananas
  end
  
  def sort_out_bananas(bananas)
    bananas.join(";\n")
  end
  
end

module FixtureMonkey
  
  extend self
  
  def harvest(model, bacon)
    { "#{model.class.to_s.tableize}_#{model.id}" => model.attributes }.to_yaml(:separator => "")
  end
  
  def sort_out_bananas(bananas)
    bananas.join("\n")
  end
  
end

class TreeClimber
  
  attr_reader :model, :baton
  
  def initialize(model, baton={})
    @model = model
    @baton = baton
    initialize_baton
  end
  
  def initialize_baton
    baton[:ignore_associations_for] ||= []
    baton[:ignore_models] ||= []
    baton[:ignore_tables] ||= []
    baton[:dumped_ids] ||= Hash.new { |hsh,key| hsh[key] = Array.new }
    baton[:current_level] ||= baton[:level].to_i
    baton[:debug] ||= false
    baton[:add_deletes] ||= false    
  end
  
  def climb_with(monkey)    
    return if baton[:ignore_models].include?(model.class)
    return if baton[:ignore_tables].include?(model.class.table_name)
    
    if baton[:dumped_ids][model.class].include?(model.id)
      return
    else
      baton[:dumped_ids][model.class] << model.id
    end
    
    bananas = []      
    bananas << monkey.harvest(model, baton)
    STDERR << "Getting banana #{model.class}:#{model.id}\n" if baton[:debug]
    
    if baton[:level]
      baton[:current_level] -= 1
    end
    
    if !baton[:ignore_associations_for].include?(model.class) and baton[:current_level] >= 0
      model.class.reflect_on_all_associations.each do |assoc|
        assoc_value = model.send(assoc.name)
        if assoc_value
          unless assoc_value.is_a? Array
            leafs = [ assoc_value ]
          else
            leafs = assoc_value
          end
          leafs.each do |leaf|          
            bananas << TreeClimber.new(leaf, baton).climb_with(monkey)
          end
        end
      end
    end
    
    monkey.sort_out_bananas(bananas.flatten.compact)
  end
  
end