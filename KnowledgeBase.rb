require_relative 'KnowledgeFact'
DEBUG = true

class KnowledgeBase
  attr_reader :facts
  def initialize(facts=[])
    @facts ||= facts
  end

  def addFact(ts,text,tags)
    @facts << KnowledgeFact.new(ts,text,tags)
  end

  #elapsedTime -- all facts must be within a certain number of seconds of the present time
  #tagConds -- all facts must contain a certain set of tags and, optionally, a specific set of subclasses for those tags in the format root_tag,subclass_clause. Subclasses can be conditions if designated with | separators. These clauses can also be inverted if the ~ character is the first character of the clause. If the subclause is designated as a '*' character, any subclass or the root_tag will will satisfy the condition
  #timeStr -- all facts must have the same timestamp value as timeStr for non '*' values. Format as follows: mm/dd/yyyy,hh:mm,dow
  #pivotTime -- If not empty, will be used as the comparison time for the elapsedTime attribute. It is off the form mm/dd/yyyy,hh:mm . Note that mm/dd/yyyy and hh:mm can be stars '*'. If the mdy substring is a '*' and elapsedTime is less than a day, then the mdy will be calculated dynamically for every day such that any fact within a few hours of the hh:mm substring in pivotTime in any day will be selected. If mdy is '*' and elapsedTime is greater than one day, then mdy will be
  #set to the present day
  def getFacts(elapsedTime=-1,tagConds=[],timeStr="",pivotTime="")
    filtered=@facts.dup
    #filtering based on tag conditions
    if tagConds.length > 0
      tagConds.each do |query|
        root,subclause = query.split(',')
        if subclause  == '*'
          filtered.select! do |fact|
            fact.tags.keys.include?(root)
          end
        else
          invert = subclause[0] == '~' #will be xor'd with the conditional
          conditions = (invert ? subclause[1...subclause.length].split('|') : subclause.split('|'))
          filtered.select! do |fact|
            #(fact.tags.keys.include?(root) and (conditions.include?(fact.tags[root][:subclass]))) ^ invert COMMENT:this is for when root tag hashes weren't arrays
            (fact.tags.keys.include?(root) and (fact.tags[root].inject(false) { |cum,tg| (cum or conditions.include?(tg[:subclass])) })) ^ invert 
          end
        end
      end
    end

    #filtering based on time string
    if timeStr != ""
      mdy,tod,dow = timeStr.split(',')
      m,d,y = mdy.split('/')
      #TODO: currently searches for exact hours and minutes, but in the future it might be useful to create a pivot around the hour and minutes for more flexible searches
      h,mi = tod.split(':')
      checkConds = {dow => :dow,m => :month,d => :day,y => :year,h => :hour,mi => :minute}.select { |strk,strv| strk != '*' }

      filtered.select! do |fact|
        keep = true
        checkConds.each do |strk,strv|
          keep = (keep and fact.timestamp[strv] == strk)
        end
        keep
      end
    end

    #filtering based on elapsed time
    #must create a DateTime
    #then pivot around that DateTime
    if elapsedTime > 0
      now = Time.now
      mdy_star = false
      hmi_star = false
      if pivotTime != ""
        mdy,tod = pivotTime.split(',')
        m,d,y = (mdy == '*' ? [now.month,now.day,now.year] : mdy.split('/'))
        h,mi = (tod == '*' ? [0,0] : tod.split(':'))
        hmi_star = tod == '*'
        mdy_star = mdy == '*'
        now = Time.new(y,m,d,h,mi)
      end
      #TODO: note--currently only considers one timezone
      if mdy_star and not hmi_star and elapsedTime < 24 * 60 * 60
        filtered.select! do |fact|
          tmp = Time.new(fact.timestamp[:year],fact.timestamp[:month],fact.timestamp[:day],now.hour,now.min)
          (tmp - Time.new(fact.timestamp[:year],fact.timestamp[:month],fact.timestamp[:day],fact.timestamp[:hour],fact.timestamp[:minute])).abs <= elapsedTime
        end
      else
        filtered.select! do |fact|
          tmp = now - Time.new(fact.timestamp[:year],fact.timestamp[:month],fact.timestamp[:day],fact.timestamp[:hour],fact.timestamp[:minute])
          tmp.abs <= elapsedTime
        end
      end
    end

    return filtered
  end

  #Gets all facts within a certain period of time around the given fact with the same structure (e.g. all tags about the user being at a location within 5 minutes)
  def getSimilar(fact,elapsedTime=30*60,consider_sub=true)
    filtered = getFacts(elapsedTime=elapsedTime,[],"",pivotTime="#{fact.timestamp[:month]}/#{fact.timestamp[:day]}/#{fact.timestamp[:year]},#{fact.timestamp[:hour]}:#{fact.timestamp[:minute]}")
    filtered.select! do |candidate|
      fact.sameStruct(candidate,consider_sub)
    end
    return filtered - [fact]
  end
end
