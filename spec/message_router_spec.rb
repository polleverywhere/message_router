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
    MessageRouter::Matcher.default_param.should eql(:body)
  end
end

describe MessageRouter do
  
  class TwitterRouter < MessageRouter
    context :all_caps_with_numbers do
      # All caps without numbers... but in a proc
      context Proc.new{|r| r.message[:body] =~ /^[A-Z\s]+$/ } do
        match /.+/ do
          "STOP SHOUTING WITHOUT NUMBERS!"
        end
      end
      
      match /.+/ do
        "STOP SHOUTING WITH NUMBERS!"
      end
    end
    
    match /hi dude/ do
      "pleased to meet you"
    end
    
    match /hi (\w+)/ do |name|
      "how do you do #{name}"
    end
    
    match /hola (\w+)/, :from => 'bradgessler' do |name|
      "hello #{name} in spanish"
    end
    
  private
    def all_caps_with_numbers
      message[:body] =~ /^[A-Z0-9\s]+$/
    end
  end
  
  context "default matcher" do
    it "should capture regexps" do
      TwitterRouter.new({:body => 'hi dude'}).dispatch.should eql('pleased to meet you')
    end
    
    it "should pass regexp captures through blocks" do
      TwitterRouter.new({:body => 'hi brad'}).dispatch.should eql("how do you do brad")
    end
  end
  
  context "hash matcher" do
    it "should capture with default matcher" do
      TwitterRouter.new({:from => 'bradgessler', :body => 'hola jeannette'}).dispatch.should eql("hello jeannette in spanish")
    end
  end
  
  context "context" do
    it "should handle contexts and non-proc conditions" do
      TwitterRouter.new({:body => 'HI BRAD 90'}).dispatch.should eql("STOP SHOUTING WITH NUMBERS!")
    end
    
    it "should handle nested contexts and proc conditions" do
      TwitterRouter.new({:body => 'HI BRAD'}).dispatch.should eql("STOP SHOUTING WITHOUT NUMBERS!")
    end
  end
end