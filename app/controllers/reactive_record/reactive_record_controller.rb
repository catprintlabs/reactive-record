require 'reactive_record/cache'

module ReactiveRecord

  class ReactiveRecordController < ApplicationController

    #todo make sure this is right... looks like model.id always returns the attribute value of the primary key regardless of what the key is.

    def fetch
      @data = Hash.new {|hash, key| hash[key] = Hash.new}
      params[:pending_fetches].each do |fetch_item|
        if parent = Object.const_get(fetch_item[0]).send("find_by_#{fetch_item[1]}", fetch_item[2])
          @data[fetch_item[0]][parent.id] ||= ReactiveRecord.build_json_hash parent
          fetch_association(parent, fetch_item[3..-1])
        end
      end
      render :json => @data
    end

    def fetch_association(item, associations)
      @data[item.class.name][item.id] ||= ReactiveRecord.build_json_hash(item)
      unless associations.empty?
        association_value = item.send(associations.first)
        if association_value.respond_to? :each
          association_value.each do |item|
            fetch_association(item, associations[1..-1])
          end
        elsif association_value
          fetch_association(association_value, associations[1..-1])
        end
      end
    end

    def save
      attributes = params[:attributes]
      model = Object.const_get(params[:model])
      id = attributes[model.primary_key]
      begin
        if id
          record = model.find(id)
          keys = record.attributes.keys
          attributes.each do |key, value|
            record[key] = value if keys.include? key
          end
          record.save!
        else
          model.new(attributes).save!
        end
        render :json => {success: true, attributes: ReactiveRecord.build_json_hash(record)}
      rescue Exception => e
        render :json => {success: false, attributes: {}, message: e.message}
      end
    end

    def destroy
      attributes = params[:attributes]
      model = Object.const_get(params[:model])
      id = attributes[model.primary_key]
      begin
        record = model.find(id)
        record.destroy
        render :json => {success: true, attributes: {}}
      rescue Exception => e
        render :json => {success: false, record: record, message: e.message}
      end
    end

  end

end
