####
# Copyright (c) 2013 Chris J Daly (github user cjdaly)
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
#
# Contributors:
#   cjdaly - initial API and implementation
####
require 'rubygems'
require 'rest_client'
require 'json'
require 'napkin-util'

module Napkin
  module Neo4jUtil
    SR = "http://localhost:7474/db/data"
    SRN = SR + "/node"
    SRB = SR + "/batch"
    SRC = SR + "/cypher"
    #
    Pinned = {}

    #
    def Neo4jUtil.pin!(node_key, node_id)
      Pinned[node_key] = node_id
    end

    def Neo4jUtil.pin(node_key)
      return Pinned[node_key]
    end

    def Neo4jUtil.node_url(node_id)
      return "#{SRN}/#{node_id}"
    end

    def Neo4jUtil.node_properties_url(node_id)
      return "#{SRN}/#{node_id}/properties"
    end

    def Neo4jUtil.get(url)
      response = RestClient.get(url, :accept=>:json)
      response_json_object = JSON.parse(response.to_s)
      return response_json_object
    end

    def Neo4jUtil.post(url, json_object)
      json = json_object.to_json
      response = RestClient.post(url, json, :content_type=>:json, :accept=>:json)
      response_json_object = JSON.parse(response.to_s)
      return response_json_object
    end

    def Neo4jUtil.get_node_properties(node_id)
      return Neo4jUtil.get("#{SRN}/#{node_id}/properties")
    end

    def Neo4jUtil.get_node_properties_text(node_id)
      node_properties = Neo4jUtil.get_node_properties(node_id)

      properties_text = "ID=#{node_id}\n"
      node_properties.each do |key, value|
        properties_text << "#{key}=#{value}\n"
      end
      return properties_text
    end

    def Neo4jUtil.get_node_property(key, node_id)
      return nil unless Neo4jUtil.valid_segment?(key)

      cypher_get_node_property = {
        "query" => "START n=node({node_id}) RETURN n.`#{key}`",
        "params" => {
        "node_id" => node_id,
        }
      }
      value = Neo4jUtil.cypher_query(cypher_get_node_property, true)
      return value
    end

    def Neo4jUtil.set_node_property(key, value, node_id)
      return nil unless Neo4jUtil.valid_segment?(key)

      cypher_set_node_property = {
        "query" => "START n=node({node_id}) SET n.`#{key}`={value} RETURN null",
        "params" => {
        "node_id" => node_id,
        "value" => value,
        }
      }
      raw = Neo4jUtil.post(SRC, cypher_set_node_property)
      return nil
    end

    def Neo4jUtil.increment_counter(key, node_id)
      return nil unless Neo4jUtil.valid_segment?(key)

      cypher_increment_counter = {
        "query" => "START n=node({node_id}) SET n.`#{key}` = COALESCE(n.`#{key}`, 0) + 1 RETURN n.`#{key}`",
        "params" => {
        "node_id" => node_id,
        }
      }
      value = Neo4jUtil.cypher_query(cypher_increment_counter, true)
      return value
    end

    def Neo4jUtil.next_sub_id!(sup_node_id)
      sub_count = Neo4jUtil.increment_counter('napkin.sub_count', sup_node_id)
      return nil if sub_count.nil?
      sub_node_id =  Neo4jUtil.get_sub_id!(sub_count.to_s, sup_node_id)
      return sub_node_id
    end

    SEGMENT_MATCH = /^[-_.a-zA-Z0-9~]+$/

    def Neo4jUtil.valid_segment?(node_segment)
      return false if node_segment.nil?
      return false unless node_segment.is_a? String
      match = SEGMENT_MATCH.match(node_segment)
      return !match.nil?
    end

    def Neo4jUtil.get_sub_id!(sub_node_segment, sup_node_id)
      return nil unless Neo4jUtil.valid_segment?(sub_node_segment)

      cypher_create_unique = {
        "query" => 'START sup=node({sup_node_id}) CREATE UNIQUE sup-[:NAPKIN_SUB]->(sub:NAPKIN {`napkin.segment` : {sub_node_segment}}) RETURN ID(sub)',
        "params" => {
        "sup_node_id" => sup_node_id,
        "sub_node_segment" => sub_node_segment
        }
      }
      value = Neo4jUtil.cypher_query(cypher_create_unique, true)
      return value
    end

    def Neo4jUtil.get_sub_id(sub_node_segment, sup_node_id)
      return nil unless Neo4jUtil.valid_segment?(sub_node_segment)

      cypher_get_sub = {
        "query" => 'START sup=node({sup_node_id}) MATCH sup-[:NAPKIN_SUB]->(sub:NAPKIN) WHERE sub.`napkin.segment` = {sub_node_segment} RETURN ID(sub)',
        "params" => {
        "sup_node_id" => sup_node_id,
        "sub_node_segment" => sub_node_segment
        }
      }
      value = Neo4jUtil.cypher_query(cypher_get_sub, true)
      return value
    end

    def Neo4jUtil.get_sub_ids(sup_node_id)
      cypher_get_subs = {
        "query" => 'START sup=node({sup_node_id}) MATCH sup-[:NAPKIN_SUB]->(sub:NAPKIN) RETURN ID(sub)',
        "params" => {
        "sup_node_id" => sup_node_id,
        }
      }
      raw =  Neo4jUtil.post(SRC, cypher_get_subs)
      sub_ids = []
      raw['data'].each do |data|
        sub_ids << data[0]
      end
      return sub_ids
    end

    def Neo4jUtil.get_sub_segments(sup_node_id)
      cypher_get_subs = {
        "query" => 'START sup=node({sup_node_id}) MATCH sup-[:NAPKIN_SUB]->(sub:NAPKIN) RETURN sub.`napkin.segment` ORDER BY sub.`napkin.segment`',
        "params" => {
        "sup_node_id" => sup_node_id,
        }
      }
      raw =  Neo4jUtil.post(SRC, cypher_get_subs)
      sub_segments = []
      raw['data'].each do |data|
        sub_segments << data[0]
      end
      return sub_segments
    end

    def Neo4jUtil.get_root_node_id(napkin_root_segment = "NAPKIN_ROOT//")

      cypher_create_root_node = {
        "query" => "MERGE (root:NAPKIN {`napkin.ROOT_NODE` : true}) RETURN ID(root)",
        "params" => {
        "napkin_root_segment" => napkin_root_segment
        }
      }
      root_node_id = Neo4jUtil.cypher_query(cypher_create_root_node, true)

      puts "Napkin root node ID: #{root_node_id}"

      return root_node_id
    end

    CREATE_UNIQUE_REF_CYPHER ='
    START from_node=node({from_node_id}), to_node=node({to_node_id})
    CREATE UNIQUE from_node-[r:NAPKIN_REF]->to_node
    RETURN ID(r)
    '

    def Neo4jUtil.set_ref!(from_node_id, to_node_id)
      cypher_create_unique_ref = {
        "query" => CREATE_UNIQUE_REF_CYPHER,
        "params" => {
        "from_node_id" => from_node_id,
        "to_node_id" => to_node_id
        }
      }
      value = Neo4jUtil.cypher_query(cypher_create_unique_ref, true)
      return value
    end

    def Neo4jUtil.set_ref_property(key, value, ref_id)
      return nil unless Neo4jUtil.valid_segment?(key)

      cypher_hash = {
        "query" => "START r=rel({ref_id}) SET r.`#{key}`={value} RETURN null",
        "params" => {
        "ref_id" => ref_id,
        "value" => value,
        }
      }
      raw = Neo4jUtil.post(SRC, cypher_hash)
      return nil
    end

    def Neo4jUtil.create_napkin_index()
      cypher_create_index = {
        "query" => 'CREATE INDEX ON :NAPKIN(`napkin.segment`)',
        "params" => {
        }
      }
      value = nil
      begin
        value = Neo4jUtil.cypher_query(cypher_create_index, true)
      rescue StandardError => err
        puts "TODO: create_napkin_index - index already exists"
      end
      return value
    end

    def Neo4jUtil.create_napkin_root_constraint()
      cypher_create_root_constraint = {
        "query" => 'CREATE CONSTRAINT ON (root:NAPKIN) ASSERT root.`napkin.ROOT_NODE` IS UNIQUE',
        "params" => {
        }
      }
      value = nil
      begin
        value = Neo4jUtil.cypher_query(cypher_create_root_constraint, true)
      rescue StandardError => err
        puts "TODO: create_napkin_root_constraint - constraint already exists"
      end
      return value
    end

    def Neo4jUtil.cypher_query(cypher_hash, extract_single_result = false)
      raw = Neo4jUtil.post(SRC, cypher_hash)
      raw_data = raw['data']

      if (extract_single_result) then
        return nil if (raw_data.length == 0)
        return nil if (raw_data[0].length == 0)
        return raw_data[0][0]
      else
        return raw_data
      end
    end

    class SubList
      include ConversionUtil
      def initialize(sup_node_id)
        @sup_node_id = sup_node_id
      end

      NEXT_SUB_CYPHER ='
      START sup=node({sup_node_id})
      CREATE UNIQUE sup-[:NAPKIN_SUB]->
        (millions:NAPKIN {`napkin.segment` : {millions_segment}})-[:NAPKIN_SUB]->
        (thousands:NAPKIN {`napkin.segment` : {thousands_segment}})-[:NAPKIN_SUB]->
        (ones:NAPKIN {`napkin.segment` : {ones_segment}, `napkin.sublist_position` : {sublist_position}})
      RETURN ID(ones)'

      GET_SUB_CYPHER ='
      START sup=node({sup_node_id})
      MATCH sup-[:NAPKIN_SUB]->
        (millions:NAPKIN)-[:NAPKIN_SUB]->
        (thousands:NAPKIN)-[:NAPKIN_SUB]->
        (ones:NAPKIN)
      WHERE ((millions.`napkin.segment` = {millions_segment})
        AND (thousands.`napkin.segment` = {thousands_segment})
        AND (ones.`napkin.segment` = {ones_segment}))
      RETURN ID(ones)
      '

      def get_count
        sublist_count = Neo4jUtil.get_node_property('napkin.sublist_count', @sup_node_id)
        return 0 if sublist_count.nil?
        return sublist_count
      end

      def next_sub_id!
        sublist_count = Neo4jUtil.increment_counter('napkin.sublist_count', @sup_node_id)
        # sublist_index is zero-based storage scheme
        sublist_index = sublist_count-1
        # sublist_position is one-based for REST API
        sublist_position = sublist_count
        millions, thousands, ones = get_segment_values(sublist_index)
        cypher_hash = {
          "query" => NEXT_SUB_CYPHER,
          "params" => {
          "sup_node_id" => @sup_node_id,
          "millions_segment" => millions.to_s,
          "thousands_segment" => thousands.to_s,
          "ones_segment" => ones.to_s,
          "sublist_position" => sublist_position
          }
        }
        value = Neo4jUtil.cypher_query(cypher_hash, true)
        return value
      end

      def get_sub_id(sublist_position)
        if (sublist_position.is_a? String) then
          sublist_position = parse_int(sublist_position)
        end
        return nil unless sublist_position.is_a?(Integer)
        sublist_index = sublist_position - 1
        millions, thousands, ones = get_segment_values(sublist_index)
        cypher_hash = {
          "query" => GET_SUB_CYPHER,
          "params" => {
          "sup_node_id" => @sup_node_id,
          "millions_segment" => millions.to_s,
          "thousands_segment" => thousands.to_s,
          "ones_segment" => ones.to_s
          }
        }
        value = Neo4jUtil.cypher_query(cypher_hash, true)
        return value
      end

      def get_segment_values(sublist_index)
        # rollover at 1 billion
        sublist_index %= 1000000000

        millions = sublist_index / 1000000
        thousands = (sublist_index % 1000000) / 1000
        ones = sublist_index % 1000
        return millions, thousands, ones
      end

    end
  end
end