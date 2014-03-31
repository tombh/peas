module Peas
  module Entities
    class Tool < Grape::Entity
      root "tools", "tool"
      expose :id
      expose :length, documentation: { type: String, desc: "length of the tool" }
      expose :weight, documentation: { type: String, desc: "weight of the tool" }
      expose :foo, documentation: { type: String, desc: "foo" }, if: lambda { |tool, options| options[:foo] } do |tool, options|
        # p options[:env].keys
        options[:foo]
      end
    end

    class API < Grape::API
      format :json
      content_type :xml, 'application/xml'
      formatter :xml, proc { |object|
        object[object.keys.first].to_xml root: object.keys.first
      }
      desc "Exposes an entity"
      namespace :entities do
        desc "Expose a tool", params: Peas::Entities::Tool.documentation
        get ':id' do
          present OpenStruct.new(id: params[:id], length: 10, weight: "20kg"), with: Peas::Entities::Tool, foo: params[:foo]
        end
      end
    end
  end
end
