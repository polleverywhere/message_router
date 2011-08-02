require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe MessageRouter::Matcher do
  context "regexp expressions" do
    it "should return captures" do
      match = MessageRouter::Matcher.new({:body => /(\w+) (\w+) (\w+)/}).match({:body => 'hi there dude'})
      match[:body].should eql(%w(hi there dude))
    end
  end
  
  context "string expressions" do
    it "should return capture" do
      match = MessageRouter::Matcher.new({:body => 'testing'}).match({:body => 'testing'})
      match[:body].should eql(['testing'])
    end
  end
  
  it "should return captures if all matchers have captures" do
    match = MessageRouter::Matcher.new({:body => 'testing', :carrier => 'att'}).match({:body => 'testing', :carrier => 'att'})
    match.should_not be_nil
  end
  
  it "should not return captures if some matchers have captures" do
    match = MessageRouter::Matcher.new({:body => 'testing', :carrier => 'att'}).match({:body => 'testing', :carrier => 'verizon'})
    match.should be_nil
  end
  
  it "should not return captures of params are missing" do
    match = MessageRouter::Matcher.new({:body => 'testing', :carrier => 'att'}).match({:body => 'testing'})
  end
  
  it "should default matcher param to :body" do
    MessageRouter::Matcher.default_key.should eql(:body)
  end
end

describe MessageRouter do
  class CrazyTimesRouter < MessageRouter
    match /^crazy$/ do
      halt "factory blow out sales are awesome"
    end
  end

  # Test case router
  class TwitterRouter < MessageRouter
    context :all_caps_with_numbers do |funny_word, high_def_resolution|
      match /FUNNYWORD/i do
        halt "#{funny_word}-#{high_def_resolution}"
      end

      # All caps without numbers... but in a proc
      context Proc.new{|r| r.message[:body] =~ /^[A-Z\s]+$/ } do
        match /.+/ do
          halt "STOP SHOUTING WITHOUT NUMBERS!"
        end
      end

      match /.+/ do
        halt "STOP SHOUTING WITH NUMBERS!"
      end
    end

    mount CrazyTimesRouter

    match /hi dude/ do
      halt "pleased to meet you"
    end

    match /hi halt (\w+)/ do |word|
      halt word
    end

    match /hi halt/ do
      halt
    end
    
    match /hi (\w+)/ do |name|
      halt "how do you do #{name}"
    end
    
    match /hola (\w+) (\w+)/, :from => 'bradgessler' do |first_name, last_name|
      halt "hello #{first_name} #{last_name} in spanish"
    end
    
  private
    def all_caps_with_numbers
      if message[:body] =~ /^[A-Z0-9\s]+$/
        ["Zeldzamar", 1080]
      end
    end
  end

  def dispatch(*args)
    reply = TwitterRouter.dispatch(*args)
    reply ? reply[:body] : nil
  end

  it "should return nil if there are no matches" do
    dispatch("bums").should be_nil
  end

  it "should have default key" do
    TwitterRouter.new.default_key.should eql(:body)
  end

  context "mounted router" do
    it "should process message" do
      dispatch("crazy").should eql("factory blow out sales are awesome")
    end
  end

  context "should halt" do
    it "without value" do
      dispatch("hi halt").should be_nil
    end

    it "with value" do
      dispatch("hi halt narf").should eql("narf")
    end
  end
  
  context "default matcher" do
    it "should capture regexps" do
      dispatch('hi dude').should eql('pleased to meet you')
    end
    
    it "should pass regexp captures through blocks" do
      dispatch('hi brad').should eql("how do you do brad")
    end
  end
  
  context "hash matcher" do
    it "should capture with default matcher" do
      dispatch('hola jeannette gessler', :from => 'bradgessler').should eql("hello jeannette gessler in spanish")
    end

    it "should capture with an explicit hash" do
      dispatch(:body => 'hola jeannette gessler', :from => 'bradgessler').should eql("hello jeannette gessler in spanish")
    end
  end
  
  context "context" do
    it "should handle contexts and non-proc conditions" do
      dispatch('HI BRAD 90').should eql("STOP SHOUTING WITH NUMBERS!")
    end
    
    it "should handle nested contexts and proc conditions" do
      dispatch('HI BRAD').should eql("STOP SHOUTING WITHOUT NUMBERS!")
    end
    
    it "should pass arguments into contexts" do
      dispatch('FUNNYWORD').should eql("Zeldzamar-1080")
    end
  end
end