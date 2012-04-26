require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

# TODO: Maybe move this into a sub-directory
describe MessageRouter::Router do
  describe ".build" do
    it "returns a Router" do
      r = MessageRouter::Router.build {}
      r.should be_kind_of MessageRouter::Router
    end
  end

  describe "#call" do
    it "returns nil with no rules" do
      r = MessageRouter::Router.build {}
      r.call({}).should be_nil
    end

    context 'a rule matches' do
      subject do
        MessageRouter::Router.build do
          match(true, lambda { $did_it_run = true } )
        end
      end

      it "returns true when a rule matches" do
        subject.call({}).should be_true
      end

      it "calls the matcher's code" do
        subject.call({})
        $did_it_run.should be_true
      end
    end
  end
end
