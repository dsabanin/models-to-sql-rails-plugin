class Array
  
  def to_sql(*anything)
    map do |m|
      m.to_sql(*anything)
    end #.compact.join(";\n")
  end
  
end

class TreeClimber
  
  def initialize(model, baton)
    @model = model
    @baton = baton
    initialize_baton
  end
  
  def initialize_baton
  end
  
end

module ActiveRecord
  class Base
    
    def convert_itself_to_insert_sql
      quoted_attributes = attributes_with_quotes
      "INSERT INTO #{self.class.quoted_table_name} " +
      "(#{quoted_column_names.join(', ')}) " +
      "VALUES(#{quoted_attributes.values.join(', ')})"
    end
    
    def convert_itself_to_delete_sql
      "DELETE FROM #{self.class.quoted_table_name} WHERE #{connection.quote_column_name(self.class.primary_key)} = #{quoted_id}"
    end
    
    def to_sql(baton={})
      baton[:ignore_associations_for] ||= []
      baton[:ignore_models] ||= []
      baton[:ignore_tables] ||= []
      baton[:dumped_ids] ||= Hash.new { |hsh,key| hsh[key] = Array.new }
      baton[:current_level] ||= baton[:level].to_i
      baton[:debug] ||= false
      baton[:add_deletes] ||= false
      
      return if baton[:ignore_models].include?(self.class)
      return if baton[:ignore_tables].include?(self.class.table_name)
      
      if baton[:dumped_ids][self.class].include?(id)
        return
      else
        baton[:dumped_ids][self.class] << id
      end
      dumped_sql = []      
      dumped_sql << convert_itself_to_delete_sql if baton[:add_deletes]
      dumped_sql << convert_itself_to_insert_sql
      STDERR << "Dumping #{self.class}:#{id}\n" if baton[:debug]
      
     if baton[:level]
        baton[:current_level] -= 1
      end
      if !baton[:ignore_associations_for].include?(self.class) and baton[:current_level] >= 0
        self.class.reflect_on_all_associations.each do |assoc|
          assoc_value = self.send(assoc.name)
          dumped_sql << assoc_value.to_sql(baton) if assoc_value
        end
      end
      dumped_sql.flatten.compact.join(";\n")
    end
  
    def to_sql_file(filepath, options={})
      File.open(filepath, "w") do |fp|
        fp << to_sql(options)
      end
    end
    
  end
end