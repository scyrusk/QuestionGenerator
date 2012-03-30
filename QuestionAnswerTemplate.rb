class QuestionAnswerTemplate
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
    a.scan(/\w+@{\w+}/).map do |acond|
      type,btag = acond.split('@') #separate type from tag
      wqc = btag[1...btag.length-1] #eliminate { }s of tag
      tag,st = wqc.split(':')
      @aconds << { :type => type, :tag => tag, :subtag => st }
    end

    @text = text
  end

  #UNTESTED
  def matches(fact) 
    #construct a hashmap of the structure tag => { :subclass => counter }
    #the hashmap counts the number of each tag/subclass combo in the fact to check
    #against the needs of the question later
    matches = [] # will match question tags with corresponding fact tags

    workingTC = {}
    fact.tags.each do |tag,info|
      workingTC[tag] ||= {}
      workingTC[tag][:all] ||= []
      workingTC[tag][:numno] ||= 0
      info.each do |hash|
        workingTC[tag][hash[:subclass]] ||= []
        workingTC[tag][hash[:subclass] << hash[:index]
        workingTC[tag][:all] << hash[:index]
      end
    end

    possibleMacthes = Array.new(@qconds.length) { Array.new(fact.tags.length) {0} }
    matches = []
    @qconds.each.each_with_index do |hash,index|
      if hash[:subtag]
        possibleMatches[index].each_index { |i| possibleMathces[index][i] = 1 if workingTC[hash[:tag]][hash[:subtag]].include?(i) }
      else 
        possibleMatches[index].each_index { |i| possibleMathces[index][i] = 1 if workingTC[hash[:tag]][:all].include?(i) }
      end
    end

    multsidx = []
    mults = []

    #set all definite matches, or return false is no configuration is possible. Also, initialize multiples matrix
    possibleMatches.each.each_with_index do |row,index|
      qcond = @qconds[index]
      ones = []
      row.each_index { |i| ones << i if row[i] == 1 }
      if ones.length == 0 #if no possible matches for this condition
        return Array.new(@qconds.length) {-1}
      elsif ones.length == 1 #if exactly one match for this condition
        if qcond[:subtag]
          return false if not workingTC[qcond[:tag]] or workingTC[qcond[:tag]][qcond[:subtag]] <= 0 #no matches in fact
          tag_index_of_fact = workingTC[qcond[:tag]][qcond[:subtag]].first
          matches[index] = tag_index_of_fact
          workingTC[qcond[:tag]][qcond[:subtag]] = workingTC[qcond[:tag]][qcond[:subtag]] - [tag_index_of_fact]
          workingTC[qcond[:tag]][:all] = workingTC[qcond[:tag]][:all] - [tag_index_of_fact]
        else #if the match does not require a subtag
          return false if not workingTC[qcond[:tag]] #no matches in fact
          tag_index_of_fact = workingTC[qcond[:tag]][:all].first
          matches[index] = tag_index_of_fact
          #need to find which subtag the workingTC belonged to and reset it.
          workingTC[qcond[:tag]].each do |key,val|
            if val.include?(tag_index_of_fact)
              workingTC[qcond[:tag]][key] = workingTC[qcond[:tag]][key] - [tag_index_of_fact]
              break
            end
          end
          workingTC[qcond[:tag]][:all] = workingTC[qcond[:tag]][:all] - [tag_index_of_fact]
        end
      else #if multiple matches for this condition
        multsidx << index
        mults << ones
      end
    end

    #sort out mutliple matches, if possible
    minCounter = Array.new(mults.length) {0}
    currentRow = 0
    taken = []
    while minCounter[0] < mults[currentRow].length
      if minCounter[currentRow] >= mults[currentRow].length
        #need to reset
        taken.pop
        (currentRow...mults.length) do |cr|
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

      return matches if currentRow == mults.length
    end

    return false
  end

  #take in a fact, match fact tags to question tags and output filled in question text
  def generateQuestion(fact)

  end

  def to_s
    "#{@text},#{@qconds},#{@aconds}"
  end
end
