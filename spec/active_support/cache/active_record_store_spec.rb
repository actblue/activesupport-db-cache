require 'spec_helper.rb'
require 'ostruct'

include ActiveSupport::Cache

describe ActiveRecordStore do
  def meta_info_for(key)
    OpenStruct.new(ActiveRecordStore::CacheItem.find_by_key(key).meta_info)
  end

  before do
    @store = ActiveRecordStore.new
  end

  [true, false].each do |debug_mode|
    describe "cache use when debug_mode='#{debug_mode}'" do
      before do
        allow(@store).to receive_message_chain(:debug_mode?).and_return(debug_mode)
      end

      it "should store numbers" do
        @store.write("foo", 123)
        expect(@store.read("foo")).to eq(123)
      end

      it "should store strings" do
        @store.write("foo", "bar string")
        expect(@store.read("foo")).to eq("bar string")
      end

      it "should store hash" do
        @store.write("foo", { :a => 123 })
        expect(@store.read("foo").keys).to include(:a)
        expect(@store.read("foo")[:a]).to eq(123)
      end

      it "should expire entries" do
        @store.write :foo, 123, :expires_in => 5.minutes
        expect(@store.read(:foo)).to eq(123)
        Timecop.travel 6.minutes.since do
          expect(@store.read(:foo)).to be_blank
        end
      end

      it "should use ITEMS_LIMIT" do
        silence_warnings { ActiveRecordStore.const_set(:ITEMS_LIMIT, 10) }
        @store.clear

        15.times do |i|
          @store.write(i, 123)

          ActiveRecordStore::CacheItem.count
        end

        expect(ActiveRecordStore::CacheItem.count).to be <= 10
      end

      describe "#read" do
        before do
          @store.write("foo", 123)
        end

        it "should return nil if missed" do
          expect(@store.read("bar")).to be_nil
        end

        it "should read data if hit" do
          expect(@store.read("foo")).to eq(123)
        end

        it "should return nil if there is a problem with de-marshalling data" do
          entry = double
          allow(@store).to receive_message_chain(:debug_mode?).and_return(false)
          allow(ActiveRecordStore::CacheItem).to receive_message_chain(:find_by_key).with("foo").and_return(entry)
          expect(entry).to receive(:value).and_raise('cannot de-marshall data')
          expect(@store.read("foo")).to be_nil
        end
      end

      describe "#fetch" do
        it "should return calculate if missed" do
          @store.delete(:foo)
          obj = double(:obj)
          expect(obj).to receive(:func).and_return(123)

          expect(@store.fetch(:foo) { obj.func }).to eq(123)
        end

        it "should read data from cache if hit" do
          @store.write(:foo, 123)
          obj = double(:obj)
          expect(obj).not_to receive(:func)

          expect(@store.fetch(:foo) { obj.func }).to eq(123)
        end
      end

      describe "#clear" do
        it "should clear cache" do
          @store.write("foo", 123)
          @store.write("bar", "blah data")
          @store.clear
          expect(@store.read("foo")).to be_blank
          expect(@store.read("bar")).to be_blank
        end
      end

      describe "#delete" do
        it "should delete entry" do
          @store.write("foo", 123)
          @store.delete("foo")
          expect(@store.read("foo")).to be_blank
        end
      end

      describe "cache item meta info" do
        before { @store.clear }

        describe "item version" do
          it "should be 1 for a new cache item", :filter => true do
            @store.write(:foo, "foo")
            expect(meta_info_for(:foo).version).to eq(1)
          end

          it "should be incremented after cache update" do
            @store.write(:foo, "bar")
            expect(meta_info_for(:foo).version).to eq(1)

            @store.write(:foo, "123")
            expect(meta_info_for(:foo).version).to eq(2)

            @store.write(:foo, "hoo")
            expect(meta_info_for(:foo).version).to eq(3)
          end

          it "should not be incremented if no data change" do
            @store.write(:foo, "bar")
            @store.write(:foo, "bar")
            expect(meta_info_for(:foo).version).to eq(1)
          end
        end
      end

      describe 'configure database via new' do
        before do
          @store_a = ActiveRecordStore.new database_configuration: {adapter: 'sqlite3', database: 'db/test.sqlite3'}
          @store_a.write('foo a', 'something')
          expect(@store_a.read('foo a')).to eq('something')
        end
        describe 'use a different database' do
          before do
            @store_b = ActiveRecordStore.new database_configuration: {adapter: 'sqlite3', database: 'db/test_alternate.sqlite3'}
            @store_b.write('foo b', 'something')
          end
          it 'should see values from second database only' do
            expect(@store_b.read('foo a')).to be_nil
            expect(@store_b.read('foo b')).to eq('something')
          end
        end
      end

      describe 'configure table name via new' do
        before do
          @store_a = ActiveRecordStore.new cache_store_table: 'another_table'
        end
        # because we assign the table name with ActiveSupport::Cache::ActiveRecordStore::CacheItem
        # this is global for all instances.
        after do
          @store_a = ActiveRecordStore.new cache_store_table: 'cache_items'
        end
        it 'should raise exception' do
          expect { @store_a.write('foo a', 'something') }.to raise_error(NameError)
        end
      end
    end
  end
end

