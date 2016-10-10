# Implementation courtesy of db-charmer.
module DbCache
  module AbstractAdapter
    module DbCacheShard
      class InstrumenterDecorator < ActiveSupport::ProxyObject
        def initialize(adapter, instrumenter)
          @adapter = adapter
          @instrumenter = instrumenter
        end

        def instrument(name, payload = {}, &block)
          payload[:db_cache] ||= 'db_cache'
          @instrumenter.instrument(name, payload, &block)
        end

        def method_missing(meth, *args, &block)
          @instrumenter.send(meth, *args, &block)
        end
      end

      def self.included(base)
        base.alias_method_chain :initialize, :dbcache_shard
      end

      def initialize_with_dbcache_shard(*args)
        initialize_without_dbcache_shard(*args)
        @instrumenter = InstrumenterDecorator.new(self, @instrumenter)
      end
    end
  end
end

ActiveRecord::ConnectionAdapters::AbstractAdapter.send(:include, DbCache::AbstractAdapter::DbCacheShard)
