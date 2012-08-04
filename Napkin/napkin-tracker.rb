require 'yaml'
require 'rss/2.0'

#
require 'rubygems'
require 'neo4j'
require 'open-uri/cached'

#
require 'napkin-config'
require 'napkin-node-util'
require 'napkin-handlers'

module Napkin
  module Handlers
    FEED_PROPS = Napkin::NodeUtil::PropertyMapper.new(
    "feed",
    ['name',
      'url',
      'refresh_enabled',
      'refresh_in_minutes'])

    class FeedHandler < HttpMethodHandler
      def handle
        @request.body.rewind
        body_text = @request.body.read
        body_hash = FEED_PROPS.yaml_to_hash(body_text)

        output_text = subclass_handle(body_hash)
        if (output_text.nil?)
          filtered_text = FEED_PROPS.hash_to_yaml(body_hash)
          "!!! HTTP - #{@method}: '#{get_segment}', #{@nn[:id]}\n#{body_text}\n!-->\n#{filtered_text}"
        else
          return output_text
        end
      end

      def subclass_handle(body_hash)
        return nil
      end
    end

    class FeedPostHandler < FeedHandler
      def subclass_handle(body_hash)
        name = body_hash['name']
        return nil if name.nil?

        nn = @nn.dup
        return nil unless nn.go_sub!(name)

        FEED_PROPS.hash_to_node(nn.node, body_hash)

        rehash = FEED_PROPS.node_to_hash(nn.node)
        FEED_PROPS.hash_to_yaml(rehash)
      end
    end

    class FeedPutHandler < FeedHandler
      def subclass_handle(body_hash)
        ""
      end
    end
  end

  class Tracker
    def init_nodes
      nn = Napkin::NodeUtil::NodeNav.new
      nn.go_sub_path!('tracker/feed')
      nn['HTTP-handler-post'] = "FeedPostHandler"
      nn.reset

      nn.go_sub_path!('tracker/cycle')
      nn.get_or_init('cycle_count',0)
      nn.get_or_init('pre_cycle_delay_seconds',9)
      nn.get_or_init('mid_cycle_delay_seconds',5)
      nn.get_or_init('post_cycle_delay_seconds',1)
    end

    def cycle
      @enabled = true
      @thread = Thread.new do
        begin
          puts "Tracker thread started..."

          # Some sleepage seems to be necessary to avoid strange Neo4J exceptions...
          sleep 1

          init_nodes
          init_git

          puts "Tracker thread initialized..."
          while (next_cycle)
            puts "Tracker thread - cycle: #{@cycle_count}"
            sleep @pre_cycle_delay_seconds
            if (@enabled)
              refresh_feeds
              puts "Tracker thread refreshed..."
            else
              puts "Tracker thread disabled..."
            end
            # do_git_stuff()

            sleep @post_cycle_delay_seconds
          end
          puts "Tracker thread stopped..."
        rescue StandardError => err
          puts "Error in Tracker thread: #{err}\n#{err.backtrace}"
        end
      end
    end

    def next_cycle
      cycle_start_time = Time.now

      nn = Napkin::NodeUtil::NodeNav.new
      nn.reset
      nn.go_sub_path('tracker/cycle')

      @cycle_count = nn['cycle_count']
      @cycle_count += 1
      nn['cycle_count']= @cycle_count

      @pre_cycle_delay_seconds = nn['pre_cycle_delay_seconds']
      @mid_cycle_delay_seconds = nn['mid_cycle_delay_seconds']
      @post_cycle_delay_seconds = nn['post_cycle_delay_seconds']

      nn.go_sub!("#{@cycle_count}")

      nn['cycle_start_time'] = "#{cycle_start_time}"
      nn['cycle_start_time_i'] = cycle_start_time.to_i

      #
      puts ">>> CYCLE: #{nn.get_path} / #{nn['cycle_count']}"

      return true
    end

    def refresh_feeds
      nn_cycle = Napkin::NodeUtil::NodeNav.new
      nn_cycle.go_sub_path("tracker/cycle/#{@cycle_count}")

      nn_feeds = Napkin::NodeUtil::NodeNav.new
      nn_feeds.go_sub_path("tracker/feed")
      nn_feeds.node.outgoing(:sub).each do |sub|
        if sub['feed.refresh_enabled']
          puts "Feed: #{sub[:id]} / #{sub['name']} refreshing..."
          refresh_feed(sub)
          puts "Feed: #{sub[:id]} / #{sub['name']} refreshed..."
          sleep @mid_cycle_delay_seconds
        else
          puts "Feed: #{sub[:id]} / #{sub['name']} refresh disabled..."
        end
      end
    end

    def refresh_feed(feed_node)
      begin
        feed_url=feed_node['feed.url']

        rss_file_meta_hash = nil
        rss_text = nil
        open(feed_url) do |rss_file|
          rss_file_meta_hash = file_meta_to_hash(rss_file.meta)
          rss_text = rss_file.read
        end

        puts "RSS file meta:\n#{YAML.dump(rss_file_meta_hash)}"

        # TODO:
        # invalidate cache at refresh time
        #   OpenURI::Cache.invalidate(@feed_url)
        # ... and open/read again
        # ... update file meta in db

        rss = RSS::Parser.parse(rss_text, false)

        rss_channel_hash = channel_to_hash(rss.channel)
        # TODO: compare with existing / update
        puts "RSS Channel:\n#{YAML.dump(rss_channel_hash)}"

        rss.items.each do |item|
          rss_item_hash = item_to_hash(item)
          puts "  RSS Item:\n#{YAML.dump(rss_item_hash)}"
          # TODO: compare with existing / update
        end
      rescue StandardError => err
        puts "Error in refresh_feed: #{err}\n#{err.backtrace}"
      end
    end

    def file_meta_to_hash(file_meta)
      return {
        'etag' => file_meta['etag'],
        'last-modified' => file_meta['last-modified'],
        'date' => file_meta['date'],
        'expires' => file_meta['expires'],
      }
    end

    def channel_to_hash(rss_channel)
      return {
        'title' => rss_channel.title,
        'link'=> rss_channel.link,
        'description' => rss_channel.description,
        'pubDate' => rss_channel.pubDate,
        'lastBuildDate' => rss_channel.pubDate
      }
    end

    def item_to_hash(rss_item)
      return {
        'title' => rss_item.title,
        'link'=> rss_item.link,
        # 'description' => rss_item.description,
        'guid' => rss_item.guid.content,
        'pubDate' => rss_item.pubDate
      }
    end

    #  def puts_meta(meta, attr)
    #    # pd = ParseDate.parsedate(meta[attr])
    #    # puts pd
    #    d = DateTime.parse(meta[attr])
    #    d2 = DateTime.now - d
    #    puts attr + ": " + meta[attr]
    #    puts (d2 * 24 * 60).to_i
    #  end

    #
    # Git stuff
    #

    def init_git
      @cache_dir = Napkin::Config::OPEN_URI_CACHE_PATH
      git_command("init")
      git_command("config --file #{@cache_dir}/.git/config user.name #{Napkin::Config::GIT_USER_NAME}")
      git_command("config --file #{@cache_dir}/.git/config user.email #{Napkin::Config::GIT_USER_EMAIL}")
    end

    def do_git_stuff()
      git_command("status -s")
      git_command("add .")
      git_command("commit -m \"...\"")
      git_command("status -s")
      git_command("tag -a cycle_#{@cycle_count} -m \"...\"")
    end

    def git_command(command, cache_dir=@cache_dir, git_dir=@cache_dir + "/.git")
      command_text = "git --git-dir=#{git_dir} --work-tree=#{cache_dir} #{command}"
      result_text = `#{command_text}`
      result_status = $?
      puts "[exec] git ... #{command}\n  -> #{result_status}\n#{result_text}"
    end
  end

end