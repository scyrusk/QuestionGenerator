class QuestionAnswerTemplate
  attr_reader :qconds,:aconds
  #text should be of the form 'Question=>Answer'
  #An example Question: 'What {tag:subtag|tag:subtag} did {tag}?'
  #An example of Answer: 'Type@{tag:subtag}'
  def initialize(text)
    q,a = text.split('=>')
    @qconds = [] #contains all tags in questions
    q.scan(/{\w+}/).each.each_with_index do |qcond,i|
      wqc = qcond[1...qcond.length-1] #eliminate { }s of tags
      wqc.split('|').each do |tagst| #allows for multiple tags in a location joined with |
        @qconds[i] ||= []
        tag,st = tagst.split(':')
        @qconds[i] << { :tag => tag, :subtag => st }
      end
    end

    @aconds = []
    if a.include? '@'
      a.scan(/[\w,]*@?{\w+:?\w+}/).each do |acond|
        type,btag = acond.split('@') #separate type from tag
        atype = type.split(',')
        wqc = btag[1...btag.length-1] #eliminate { }s of tag
        wqc.split('|').each do |tagst| #allows for multiple tags in a location joined with |
          tag,st = wqc.split(':')
          @aconds << { :type => type, :tag => tag, :subtag => st }
        end
      end
    else
      a.scan(/{\w+}/).each do |acond|
        wqc = acond[1...acond.length-1] #eliminate { }s of tag
        wqc.split('|').each do |tagst| #allows for multiple tags in a location joined with |
          tag,st = wqc.split(':')
          @aconds << { :type => nil, :tag => tag, :subtag => st}
        end
      end
    end

    #substructs are attributes of a Question-Answer Template that are dynamically replaced by elements of a fact. Examples include <time> and subclass placeholders, such as <acond:*>
    #The substructs hash map contains links between the cueing text in the QAT and the corresponding attribute in the fact
    @substructs = {}
    q.scan(/<[\w-]+>/).each do |tcue|
      cue = tcue[1...-1] #remove <,>s
      main,mod = cue.split('-')
      if not mod
        @substructs[tcue] = {:attr => main.to_sym}
      else
        @substructs[tcue] = {:obj => main, :attr => mod.to_sym}
      end
    end

    @text = text
  end

  #Seems to work
  def matches(fact) 
    allconds = (@qconds.dup + @aconds.map { |acond| { :tag => acond[:tag], :subtag => acond[:subtag] } }).flatten
    #construct a hashmap of the structure tag => { :subclass => counter }
    #the hashmap counts the number of each tag/subclass combo in the fact to check
    #against the needs of the question later
    matches = Array.new(allconds.length) { -1 }
 # will match question tags with corresponding fact tags

    workingTC = {}
    fact.tags.each do |tag,info|
      workingTC[tag] ||= {}
      workingTC[tag][:all] ||= []
      workingTC[tag][:numno] ||= 0
      info.each do |hash|
        workingTC[tag][hash[:subclass]] ||= []
        workingTC[tag][hash[:subclass]] << hash[:index]
        workingTC[tag][:all] << hash[:index]
      end
    end


    allconds.each do |hash|
      return false if not workingTC[hash[:tag]]
    end

    possibleMatches = Array.new(allconds.length) { Array.new(fact.tags.length) {-1} }
    allconds.each.each_with_index do |hash,index|
      if hash[:subtag]
        possibleMatches[index].each_index { |i| possibleMathces[index][i] = 1 if workingTC[hash[:tag]][hash[:subtag]] and workingTC[hash[:tag]][hash[:subtag]].include?(i) }
      else 
        possibleMatches[index].each_index { |i| possibleMatches[index][i] = 1 if workingTC[hash[:tag]][:all] and workingTC[hash[:tag]][:all].include?(i) }
      end
    end

    multsidx = []
    mults = []

    #set all definite matches, or return false is no configuration is possible. Also, initialize multiples matrix
    possibleMatches.each.each_with_index do |row,index|
      cond = allconds[index]
      ones = []
      row.each_index { |i| ones << i if row[i] == 1 }
      if ones.length == 0 #if no possible matches for this condition
        return false
      elsif ones.length == 1 #if exactly one match for this condition
        if cond[:subtag]
          return false if not workingTC[cond[:tag]] or workingTC[cond[:tag]][cond[:subtag]] <= 0 #no matches in fact
          tag_index_of_fact = workingTC[cond[:tag]][cond[:subtag]].first
          matches[index] = tag_index_of_fact
          workingTC[cond[:tag]][cond[:subtag]] = workingTC[cond[:tag]][cond[:subtag]] - [tag_index_of_fact]
          workingTC[cond[:tag]][:all] = workingTC[cond[:tag]][:all] - [tag_index_of_fact]
        else #if the match does not require a subtag
          return false if not workingTC[cond[:tag]] #no matches in fact
          tag_index_of_fact = workingTC[cond[:tag]][:all].first
          matches[index] = tag_index_of_fact
          #need to find which subtag the workingTC belonged to and reset it.
          workingTC[cond[:tag]].each do |key,val|
            if val.include?(tag_index_of_fact)
              workingTC[cond[:tag]][key] = workingTC[cond[:tag]][key] - [tag_index_of_fact]
              break
            end
          end
          workingTC[cond[:tag]][:all] = workingTC[cond[:tag]][:all] - [tag_index_of_fact]
        end
      else #if multiple matches for this condition
        multsidx << index
        mults << ones
      end
    end

    if mults.length == 0 and matches.all? { |match| match >= 0 }
      return [self,matches]
    end
    #sort out mutliple matches, if possible
    minCounter = Array.new(mults.length) {0}
    currentRow = 0
    taken = []
    while minCounter[0] < mults[0].length
      if minCounter[currentRow] >= mults[currentRow].length
        #need to reset
        taken.pop
        (currentRow...mults.length).each do |cr|
          minCounter[cr] = 0
        end
        currentRow -= 1
        minCounter[currentRow] += 1
        next
      end

      tag_index_of_fact = mults[minCounter[currentRow]]
      if taken.include? tag_index_of_fact
        minCounter[currentRow] += 1
        next
      else 
        matches[multsidx[currentRow]] = tag_index_of_fact 
        taken.push(tag_index_of_fact)
        currentRow += 1
      end


      return [self,matches] if currentRow == mults.length
    end

    return false
  end


  def generateQuestionAnswerPair(fact,matchesArr)
    q,a = @text.split('=>')
    if @qconds.length > 0
      matchesArr.first(@qconds.length).each do |idx|
        q.sub!("{#{fact.ordered_tags[idx][:tag]}}",fact.ordered_tags[idx][:subval])
      end
    end

    @substructs.each do |cue,sub| 
      if sub[:obj]
        if sub[:obj] == 'acond'
          q.sub!(cue,fact.getAttrFromLink(sub[:attr],matchesArr.last(matchesArr.length-@qconds.length).first))
        end
      else
        q.sub!(cue,fact.getAttrFromLink(sub[:attr]))
      end
    end
    #q.sub!('<time>',"#{fact.timestamp[:month]}/#{fact.timestamp[:day]}/#{fact.timestamp[:year]}")

    if @aconds.length > 0
      matchesArr.last(matchesArr.length-@qconds.length).each do |idx|
        type,a = a.split('@') if a.include? '@'
        a.sub!("{#{fact.ordered_tags[idx][:class]}}",fact.ordered_tags[idx][:subval])
      end
    end
    return [q,a]
  end

  def to_s
    allconds = (@qconds.dup + @aconds.map { |acond| { :tag => acond[:tag], :subtag => acond[:subtag] } }).flatten
    "#{@text},#{@qconds},#{@aconds},#{allconds}"
  end
end
