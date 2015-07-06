ActiveRecord::Base.send(:define_method, :react_serializer) do 
  serializable_hash
end

ActiveRecord::Relation.send(:define_method, :react_serializer) do
  all.react_serializer
end