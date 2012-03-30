class KnowledgeFact
  attr_reader :timestamp,:text,:tags
  def initialize(ts,text,tags)
    @timestamp = parseTS(ts)
    @text = text
    @tags = parseTags(tags)
    #puts "DEBUG from KnowledgeFact.initialize::: Fact initialized with timestamp #{@timestamp}" if DEBUG
    #puts "DEBUG from KnowledgeFact.initialize::: Fact initialized with tags #{@tags}" if DEBUG
  end

  def parseTS(ts)
    mdy,tod,dow = ts.split(',')
    m,d,y = mdy.split('/')
    h,mi = tod.split(':')
    return {:full => ts, :mdy => mdy, :month => m, :day => d, :year => y, :tod => tod, :hour => h, :minute => mi, :dow => dow}
  end

  def parseTags(taglist)
    tags = {}
    taglist.each.each_with_index do |tag,index|
      root,subcv = tag.split(':')
      subclass,subval = subcv.split('=')
      tags[root[1...root.length]] ||= []
      tags[root[1...root.length]] << {:subclass => (subval == nil ? subclass[0...subclass.length-1] : subclass), :subval => (subval == nil ? subval : subval[0...subval.length-1]), :index => index}
    end
    return tags
  end

  #determins if two facts have the same structure (in other words: do they have the same tags and the same number of each tag)
  #accomplishes this task by matching each tag in this fact with the other
  def sameStruct(ofact)
    return false if tags.length != ofact.tags.length
    tags.each do |k,v|
      if ofact.tags.keys.include?(k) and ofact.tags[k].length == v.length
        tmp = ofact.tags[k].dup
        success = []
        (0...v.length).each do |i|
          puts "checking for #{v[i][:subclass]} => #{v[i][:subval] if v[i][:subval]}" if false
          success.push(false)
          (0...tmp.length).each do |j|
            if v[i][:subclass] == tmp[j][:subclass] and v[i][:subval] == tmp[j][:subval]
              puts "match found for #{tmp[j][:subclass]} => #{tmp[j][:subval] if tmp[j][:subval]}" if false
              tmp.delete_at(j)
              success[-1] = true #problem here, just gets reset
              break
            end
          end
        end
        return false if not success.all? { |s| s } or tmp.length > 0 #matches found for all tags in this tag on the other fact, but also need to test that there are no more additional tags in the other fact
      else
        return false
      end
    end
    return true #passed all filters
  end

  def to_s
    text
  end
end
