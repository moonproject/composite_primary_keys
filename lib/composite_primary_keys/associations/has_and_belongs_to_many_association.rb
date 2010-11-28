module ActiveRecord
  module Associations
    class HasAndBelongsToManyAssociation
      def construct_sql
        if @reflection.options[:finder_sql]
          @finder_sql = interpolate_sql(@reflection.options[:finder_sql])
        else
          # CPK
          # @finder_sql = "#{@owner.connection.quote_table_name @reflection.options[:join_table]}.#{@reflection.primary_key_name} = #{owner_quoted_id} "
          @finder_sql = full_columns_equals(@reflection.options[:join_table], @reflection.cpk_primary_key, owner_quoted_id)
          @finder_sql << " AND (#{conditions})" if conditions
        end

        join_condition = if composite?
          conditions = Array.new
          primary_keys.length.times do |i|
            conditions << "#{@reflection.quoted_table_name}.#{@reflection.klass.primary_key[i]} = #{@owner.connection.quote_table_name @reflection.options[:join_table]}.#{@reflection.association_foreign_key[i]}"
          end
          conditions.join(' AND ')
        else
          "#{@reflection.quoted_table_name}.#{@reflection.klass.primary_key} = #{@owner.connection.quote_table_name @reflection.options[:join_table]}.#{@reflection.association_foreign_key}"
        end
        #@join_sql = "INNER JOIN #{@owner.connection.quote_table_name @reflection.options[:join_table]} ON #{@reflection.quoted_table_name}.#{@reflection.klass.primary_key} = #{@owner.connection.quote_table_name @reflection.options[:join_table]}.#{@reflection.association_foreign_key}"
        @join_sql = "INNER JOIN #{@owner.connection.quote_table_name @reflection.options[:join_table]} ON (#{join_condition})"

        construct_counter_sql
      end
      
      def insert_record(record, force = true, validate = true)
        unless record.persisted?
          if force
            record.save!
          else
            return false unless record.save(:validate => validate)
          end
        end

        if @reflection.options[:insert_sql]
          @owner.connection.insert(interpolate_sql(@reflection.options[:insert_sql], record))
        else
          relation   = Arel::Table.new(@reflection.options[:join_table])
          timestamps = record_timestamp_columns(record)
          timezone   = record.send(:current_time_from_proper_timezone) if timestamps.any?

          # CPK
          #attributes = Hash[columns.map do |column|
          #  name = column.name
          #  value = case name.to_s
          #    when @reflection.primary_key_name.to_s
          #      @owner.id
          #    when @reflection.association_foreign_key.to_s
          #      record.id
          #    when *timestamps
          #      timezone
          #    else
          #      @owner.send(:quote_value, record[name], column) if record.has_attribute?(name)
          #  end
          #  [relation[name], value] unless value.nil?
          #end]

          # CPK
          attributes = Hash[columns.map do |column|
            name = column.name.to_sym
            value = case
              when @reflection.cpk_primary_key.include?(name)
                @owner[name]
              when @reflection.association_foreign_key.include?(name)
                record[name]
              when *timestamps
                timezone
              else
                @owner.send(:quote_value, record[name], column) if record.has_attribute?(name)
            end
            [relation[name], value] unless value.nil?
          end]

          relation.insert(attributes)
        end

        return true
      end
    end
  end
end