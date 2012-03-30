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

    tagCounter = {}
    fact.tags.each do |k,v|
      tagCounter[k] ||= {}
      v.each do |hash|
        tagCounter[k][hash[:subclass]] = (tagCounter[k].keys.include?(hash[:subclass]) ? tagCounter[k][hash[:subclass]] + 1 : 1); #nil is a valid key
      end
    end
    workingTC = tagCounter.dup
    
    minCounter = []
    (0...@qconds.length).each do |i|
      minCounter[i] = 0
    end

    currentRow = 0
    while minCounter[0] < @qconds[0].length #until we have exhausted all options
      #for the current row i and column minCounter[i], find a match in workingTC
      #if no match is found, decrement i and reset workingTC by looking at i,minCounter[i-1] and adding that back to workingTC
      # => also increment minCounter[i] for decremented i
      # => also reset minCounter[j] to 0 for all j > i
      nosubtags = {}
      matches = []

      #if we pushed back up to a row that has already been fully checked
      if minCounter[currentRow] >= @qconds[currentRow].length
        #reset workingTC
        hash = @qcond[currentRow][minCounter[currentRow]-1]
        if hash[:subtag]
          workingTC[hash[:tag]][hash[:subtag]] += 1
        else
          nosubtags[hash[:tag]].pop
        end
        matches.pop #remove match tag
        #reset counters
        (currentRow...@qconds.length).each do |cr|
          minCounter[cr] = 0
        end
        currentRow -= 1
        minCounter[currentRow] += 1
        next
      end
      
      #check the next available tag on the current row for a match
      qcond = @qconds[currentRow][minCounter[currentRow]]
      if qcond[:subtag]
        foundMatch = workingTC[qcond[:tag]][qcond[:subtag]]
        if foundMatch and foundMatch - 1 >= 0
          workingTC[qcond[:tag]][qcond[:subtag]] -= 1
          minCounter[currentRow] += 1
          matches.push({ :tag => qcond[:tag], :subtag => qcond[:subtag], :index => currentRow})
        else
          #reset
          matches.pop
          (currentRow...@qconds.length).each do |cr|
            minCounter[cr] = 0
          end
          currentRow -= 1 #reset currentRow back one
          #reset workingTC
          hash = @qcond[currentRow][minCounter[currentRow]] #reset workingTC for last added tag in previous row
          if hash[:subtag]
            workingTC[hash[:tag]][hash[:subtag]] += 1
          else
            nosubtags[hash[:tag]].pop
          end
          minCounter[currentRow] += 1
          end
        next
      else
        nosubtags[qcond[:tag]] ||= []
        nosubtags[qcond[:tag]] << currentRow
        matches.push(-1)
      end

      #do a no subtags check if we get to the last row
      if currentRow == @qconds.length - 1
        passed = true
        nosubtags.each do |tag,indices| #try and match all question tags with no specific subtag to any subtag combo
          if not workingTC.keys.include?(tag) or workingTC[tag].values.inject(0) { |cum,v| cum += v } < indices.length #if the fact does not have the tag at all, or the number of tags is not sufficient given the number of unmatched subtags that belong to that tag, then reset
            #reset for last row
            hash = @qcond[currentRow][minCounter[currentRow]]
            if hash[:subtag]
              workingTC[hash[:tag]][hash[:subtag]] += 1
            else
              nosubtags[hash[:tag]].pop
            end
            if minCounter[currentRow] >= @qconds[currentRow].length - 1
              minCounter[currentRow] = 0
              currentRow -= 1
              hash = @qcond[currentRow][minCounter[currentRow]]
              minCounter[currentRow] += 1
              if hash[:subtag]
                workingTC[hash[:tag]][hash[:subtag]] += 1
              else
                nosubtags[hash[:tag]].pop
              end
            else
              minCounter[currentRow] += 1
            end
            passed = false
            break
          else #if the number of nosubtag tags in the fact at least equal the number of remaining tags required by the question 
            #here we assign matches
            #must be careful of temporal ordering since matches is an array. Thus, first need to find 'tag index' of the nosubtag tag
            indices.each do |ind|
              if matches[ind] != -1
                puts "Weird Bug Alert! There's a nosubtag match for a tag that has already been matched with a specific tag-subtag pair"
              else
                tqc = @qconds[ind][minCounter(ind)]
                matches[ind] = { :tag => tqc[:tag], :subtag => tqc[:subtag], :index => ind }
              end
            end
          end
        end
        #if it passes nosubtags check then return true
        return true if passed
      else
        currentRow += 1
      end
    end
    
    return false

    ##TODO: Still need to figure out what to do with matches for nosubtag cases! Also, need to change return values to matches instead of true/false
  end

  #take in a fact, match fact tags to question tags and output filled in question text
  def generateQuestion(fact)

  end

  def to_s
    "#{@text},#{@qconds},#{@aconds}"
  end
end
