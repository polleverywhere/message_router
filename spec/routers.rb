class SMS < MessageRouter
  
  context :group_session do |session|
    match /(\w)?\s(.*)/ do |keyword, value|
      "#{stats(keyword, value)} || #{session}"
    end
    
    match /leave/ do
      'leaaave'
    end
  end
  
  context :lists do
  end
  
  match /para(ms)/ do |m|
    message
  end
  
  match /ping/ do
    "PONG #{Time.now.to_s}"
  end
  
  match /(\w+)\s?(.*)/ do |keyword, text|
    stats(keyword, text)
  end
  
private
  def group_session
    true
  end
  
  def stats(keyword, text)
    "Global:#{keyword}"
  end
  
  def super_session
    true
  end
end