class KnowledgeFact
  attr_reader :timestamp,:text,:tags,:ordered_tags
  def initialize(ts,text,tags)
    @timestamp = parseTS(ts)
    @autotime = Time.new(@timestamp[:year],@timestamp[:month],@timestamp[:day],@timestamp[:hour],@timestamp[:minute])
    @text = text
    @ordered_tags = []
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
      @ordered_tags.push({:class => root[1...root.length],:subclass => (subval == nil ? subclass[0...subclass.length-1] : subclass), :subval => (subval == nil ? subval : subval[0...subval.length-1])})
      tags[root[1...root.length]] ||= []
      tags[root[1...root.length]] << {:subclass => (subval == nil ? subclass[0...subclass.length-1] : subclass), :subval => (subval == nil ? subval : subval[0...subval.length-1]), :index => index}
    end
    return tags
  end

  #determins if two facts have the same structure (in other words: do they have the same tags and the same number of each tag)
  #accomplishes this task by matching each tag in this fact with the other
  def sameStruct(ofact,consider_sub=true)
    return false if tags.length != ofact.tags.length
    if consider_sub
      tags.each do |k,v|
        if ofact.tags.keys.include?(k) and ofact.tags[k].length == v.length
          tmp = ofact.tags[k].dup
          success = []
          (0...v.length).each do |i|
            #puts "checking for #{v[i][:subclass]} => #{v[i][:subval] if v[i][:subval]}" if false
            success.push(false)
            (0...tmp.length).each do |j|
              if v[i][:subclass] == tmp[j][:subclass]
                #puts "match found for #{tmp[j][:subclass]} => #{tmp[j][:subval] if tmp[j][:subval]}" if false
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
    else #if we are not considering subtags
      tags.each do |k,v|
        unless ofact.tags.keys.include?(k) and ofact.tags[k].length == v.length
          return false
        end
      end
    end
    return true #passed all filters
  end

  def to_s
    text
  end

  def time(format="%m/%d/%Y")
    @autotime.strftime(format)
  end

  def getAttrFromLink(attr,tag_num=-1)
    if tag_num >= 0
      return eval "@ordered_tags[#{tag_num}][:#{attr}]"
    else
      return eval "self.#{attr.to_s}"
    end
  end
end
