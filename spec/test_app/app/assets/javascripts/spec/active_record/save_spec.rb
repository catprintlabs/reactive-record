require 'spec/spec_helper'
require 'user'
require 'todo_item'
require 'address'
require 'components/test'

describe "saving records" do

  it "passes" do
    expect(true).to be_truthy
  end

  async "can do a simple update and save a record" do
    `window.ReactiveRecordInitialData = undefined` rescue nil
    container = Element[Document.body].append('<div></div>').children.last
    complete = lambda do
      React::IsomorphicHelpers.load_context
      mitch = User.find_by_email("mitch@catprint.com")
      expect(mitch.changed?).to be_falsy
      expect(mitch.saving?).to be_falsy
      mitch.first_name = "Mitchell"
      expect(mitch.changed?).to be_truthy
      puts "passed all that stuff I think"
      mitch.save do
        puts "mitch has been saved"
        expect(mitch.changed?).to be_falsy
        expect(mitch.saving?).to be_falsy
        expect(mitch.first_name).to eq("Mitchell")
        begin
        `window.ReactiveRecordInitialData = undefined`
        React::IsomorphicHelpers.load_context
        puts "context reloaded"
      rescue Exception => e
        puts "something broke: #{e}"
      end
        ReactiveRecord.load do
          puts "************load em up again"
          mitch = User.find_by_email("mitch@catprint.com")
          puts "mitch = #{mitch.first_name}"
        end.then do
          puts "***********resolved!"
          expect(mitch.first_name).to eq("Mitchell")
          mitch.first_name = "Mitch"
          mitch.save do
            run_async do
              expect(mitch.first_name).to eq("Mitch")
            end
          end
        end
      end
      puts "mitch.saving? = #{mitch.saving?}"
      expect(mitch.saving?).to be_truthy
    end
    `container.load('/test', complete)`
  end

end
