module ReactiveRecord
  
  # the point is to collect up a all records needed, with whatever attributes were required + primary key, and inheritance column
  # or get all scope arrays, with the record ids

  # the incoming vector includes the terminal method

  # output is a hash tree of the form
  # tree ::= {method => tree | [value]} |      method's value is either a nested tree or a single value which is wrapped in array
  #          {:id => primary_key_id_value} |   if its the id method we leave the array off because we know it must be an int
  #          {integer => tree}                 for collections, each item retrieved will be represented by its id
  # 
  # example
  # {
  #   "User" => {
  #     ["find", 12] => {
  #       :id => 12
  #       "email" => ["mitch@catprint.com"]
  #       "todos" => {
  #         "active" => {
  #           123 => 
  #             {
  #               id: 123,
  #               title: ["get fetch_records_from_db done"]
  #             },
  #           119 => 
  #             {
  #               id: 119
  #               title: ["go for a swim"]
  #             }
  #            ]
  #          }
  #        }
  #       }
  #     }
  #   }
  # }

  # To build this tree we first fill values for each individual vector, saving all the intermediate data
  # when all these are built we build the above hash structure
  
  # basic
  # [Todo, [find, 123], title]                                 
  # -> [[Todo, [find, 123], title], "get fetch_records_from_db done", 123]

  # [User, [find_by_email, "mitch@catprint.com"], first_name]  
  # -> [[User, [find_by_email, "mitch@catprint.com"], first_name], "Mitch", 12]
  
  # misses
  # [User, [find_by_email, "foobar@catprint.com"], first_name]
  #   nothing is found so nothing is downloaded
  # prerendering may do this
  # [User, [find_by_email, "foobar@catprint.com"]]
  #   which will return a cache object whose id is nil, and value is nil

  # scoped collection
  # [User, [find, 12], todos, active, *, title] 
  # -> [[User, [find, 12], todos, active, *, title], "get fetch_records_from_db done", 12, 123] 
  # -> [[User, [find, 12], todos, active, *, title], "go for a swim", 12, 119]    

  # collection with nested belongs_to
  # [User, [find, 12], todos, *, team]
  # -> [[User, [find, 12], todos, *, team, name], "developers", 12, 123, 252]
  #    [[User, [find, 12], todos, *, team, name], nil, 12, 119]  <- no team defined for todo<119> so list ends early
  
  # collections that are empty will deliver nothing
  # [User, [find, 13], todos, *, team, name]   # no todos for user 13
  #   evaluation will get this far: [[User, [find, 13], todos], nil, 13]
  #   nothing will match [User, [find, 13], todos, team, name] so nothing will be downloaded
  

  # aggregate
  # [User, [find, 12], address, zip_code]
  # -> [[User, [find, 12], address, zip_code]], "14622", 12] <- note parent id is returned

  # aggregate with a belongs_to
  # [User, [find, 12], address, country, country_code]
  # -> [[User, [find, 12], address, country, country_code], "US", 12, 342]

  # collection * (for iterators etc)
  # [User, [find, 12], todos, overdue, *all]
  # -> [[User, [find, 12], todos, active, *all], [119, 123], 12]  

  # [Todo, [find, 119], owner, todos, active, *all]
  # -> [[Todo, [find, 119], owner, todos, active, *all], [119, 123], 119, 12]
  

    class ServerDataCache
      
      def initialize
        @cache = []
        @requested_cache_items = []
      end
      
      if RUBY_ENGINE != 'opal'
      
        def [](*vector)
          vector.inject(CacheItem.new(@cache, vector[0])) { |cache_item, method| cache_item.apply_method method }
          vector[0] = vector[0].constantize
          new_items = @cache.select { | cache_item | cache_item.vector == vector}
          @requested_cache_items += new_items
          new_items.last.value if new_items.last
        end
      
        def self.[](vectors)
          cache = new
          vectors.each { |vector| cache[*vector] }
          cache.as_json
        end
        
        def clear_requests
          @requested_cache_items = []
        end
        
        def as_json
          @requested_cache_items.inject({}) do | hash, cache_item|
            hash.deep_merge! cache_item.as_hash
          end
        end
        
        def select(&block); @cache.select &block; end
        
        def detect(&block); @cache.detect &block; end
        
        def inject(initial, &block); @cache.inject(initial) &block; end
        
        class CacheItem

          attr_reader :vector
          attr_reader :record_chain

          def value 
            @ar_object
          end
          
          def method
            vector.last
          end
          
          def self.new(db_cache, klass)
            return existing if existing = db_cache.detect { |cached_item| cached_item.vector == [klass] }
            super
          end

          def initialize(db_cache, klass)
            klass = klass.constantize
            @db_cache = db_cache
            @vector = [klass]
            @ar_object = klass
            @record_chain = []
            @parent = nil
            db_cache << self
          end
          
          def apply_method_to_cache(method, &block)
            @db_cache.inject(nil) do | representative, cache_item |
              if cache_item.vector == vector
                cache_item.clone.instance_eval do
                  @vector = @vector + [method]  # don't push it on since you need a new vector!
                  @ar_object = yield cache_item
                  @db_cache << self
                  @parent = cache_item
                  self
                end
              else
                representative
              end
            end
          end

          def apply_method(method)
            new_vector = vector + [method]
            @db_cache.detect { |cached_item| cached_item.vector == new_vector} || build_new_instances(method)
          end
          
          def build_new_instances(method)
            if method == "*all" 
              apply_method_to_cache(method) { |cache_item| cache_item.value.collect { |record| record.id }}
            elsif method == "*" and @ar_object and @ar_object.length > 0
              @ar_object.inject(nil) do | value, record |  # just using inject so we will return the last value
                apply_method_to_cache(method) { record }
              end
            elsif @ar_object.respond_to? [*method].first  
              apply_method_to_cache(method) { |cache_item| 
                cache_item.value.send(*method)}
            else
              self
            end
          end
          
          def as_hash(children = [@ar_object])
            if @parent
              if method == "*"
                @parent.as_hash({@ar_object.id => children})
              elsif @ar_object.class < ActiveRecord::Base 
                @parent.as_hash({method => children.merge({
                  :id => [@ar_object.id], 
                  @ar_object.class.inheritance_column => [@ar_object[@ar_object.class.inheritance_column]],
                  })})
              elsif method == "*all"
                @parent.as_hash({method => children.first})
              else
                @parent.as_hash({method => children})
              end
            else
              {method.name => children}
            end
          end

        end
      
      end
              
      def self.load_from_json(tree, target = nil)
        tree.each do |method, value|
          method = JSON.parse(method) rescue method
          new_target = nil
          if !target
            load_from_json(value, Object.const_get(method))
          elsif method == "*all"
            target.replace value.collect { |id| target.proxy_association.klass.find(id) }
          elsif method.is_a? Integer or method =~ /^[0-9]+$/
            new_target = target.proxy_association.klass.find(method)
            target << new_target
          elsif method.is_a? Array
            new_target = target.send *method
          elsif value.is_a? Array
            target.send "#{method}=", value.first
          elsif value.is_a? Hash and value[:id] and value[:id].first
            new_target = target.class.reflect_on_association(method).klass.find(value[:id].first)
            target.send "#{method}=", new_target
          else
            new_target = target.send *method
            begin 
              new_target = target.send "#{method}=", new_target
            rescue Exception => e
              message = "FAILED #{target}.#{method} not set to #{new_target}"
              `console.error(message)`
            end
          end
          load_from_json(value, new_target) if new_target
        end
        target.save if target.respond_to? :save 
      end
      
      
    end
    
        
  end