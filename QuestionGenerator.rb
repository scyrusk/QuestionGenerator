FACT_EXAMPLE = '1/27/2012,17:40,Friday|<person:User> was at <location:GPS=>33.64,71.89>'
KB_FILE = 'assets/KnowledgeBaseExample.txt'
TAGS_FILE = 'assets/TagsExample.txt'
QAT_FILE = 'assets/QATExample.txt'
DEBUG = false

#time multipliers
HOUR_TO_SECONDS = 60 * 60
DAY_TO_SECONDS = 24 * HOUR_TO_SECONDS
WEEK_TO_SECONDS = 7 * DAY_TO_SECONDS


require_relative 'KnowledgeBase'
require_relative 'KnowledgeFact'
require_relative 'QuestionAnswerTemplate'

class QuestionGenerator
  def self.generateQuestion(kb,difficultyScore=1.0)
    #filter knowledgebase according to time (for now -- in the future also tags)
    #pick a random fact out of the filtered based (for now -- in the future also according to context/difficulty score)
    #find all Q/A templates that fit the information in this knowledge base
    #pick a question at random (for now -- in the future also according to context/difficulty score)
    #fill out question with knowledge base fact tags. also fill out answer
    #return Q/A pair
  end
end


class RiskAssesser
  def self.makeRiskAssesment(kb)
    #filter knowledgebase according to time
    #based on factors such as current location and use patterns, return a risk score. Lower score means less risky
  end
end

class Authenticator
  AUTH_THRESHOLD = 1.0
  TIME_FILTER = 2*DAY_TO_SECONDS
  TMP_NUM_QUESTIONS = 3
  attr_reader :tags,:qat,:kb

  def initialize
    @tags = Authenticator.readLineByLine(TAGS_FILE)
    @qat = Authenticator.readQAT
    @kb = Authenticator.readKnowledgeBase(@tags)
    @state = { :authscore => 0.0, :knowledge => [] }
    #@kb.facts.each do |fact|
    #  puts "FACT:: #{fact}"
    #end
  end

  #Reads in knowledge base
  def self.readKnowledgeBase(alltags)
    kb = KnowledgeBase.new
    file = File.open(KB_FILE, "r") do |infile|
      while (line = infile.gets) #assumes fact every line
        line = line[0...line.length-1]
        timestamp,fact = line.split('|')
        tags = fact.scan(/<\w*:[^>]*>/)
        filtered = tags.select do |tag|
          root,subclass = tag.split(':')
          alltags.include?(root[1...root.length])
        end
        kb.addFact(timestamp,line,filtered)
        #puts "DEBUG from Authenticator.readKnowledgeBase::: Fact components are (timestamp,text,tags) #{[timestamp,line,filtered]}" if DEBUG
      end
    end
    return kb
  end

  def self.readQAT
    qat = []
    file = File.open(QAT_FILE, "r") do |infile|
      while (line = infile.gets)
        qat << QuestionAnswerTemplate.new(line)
      end
    end
    return qat
  end

  def self.readLineByLine(filename)
    arr = []
    file = File.open(filename, 'r') do |infile|
      while (line = infile.gets)
        arr << line[0...line.length-1]
      end
    end
    #puts "DEBUG from Authenticator.readLineByLine::: Array is #{arr}" if DEBUG
    return arr
  end

  def authenticate
    #make a context-based assesment of the difficulty score
    #n <- based risk assesment, determine the number of questions to ask
    #n.times do
      #generate question/answer tuple by passing in difficulty score
      #present question to user, wait for input
      #if input matches filled answer template, user passes this challenge.
      #update authenticator's knowledge of the user based on response,
    #if authscore > threshold return positive authentication
    #if authscore < threshold return negative authentication
    working_kb = @kb.getFacts(elapsedTime=TIME_FILTER)
    TMP_NUM_QUESTIONS.times do 
      qat = @qat.sample

    end
    reset
  end

  def reset
    @state[:authscore] = 0.0
    @state[:knowledge] = []
  end
end

#Test fact filtering
def testFiles(authenticator)
  puts "Tags"
  authenticator.tags.each do |tag|
    puts tag.to_s
  end
  puts ""
  puts "Question-Answer Templates"
  authenticator.qat.each do |qat|
    puts qat.to_s
  end
end

def testFilter(authenticator)
  #authenticator.kb.getFacts(-1,tagConds=[],timeStr='*/*/2012,*:*,*').each do |fact|
  #authenticator.kb.getFacts(13*DAY_TO_SECONDS,tagConds=[],timeStr='').each do |fact|
  #authenticator.kb.getFacts(4*DAY_TO_SECONDS,tagConds=[],timeStr='',pivotTime="01/31/2012,*").each do |fact|
  #authenticator.kb.getFacts(3*HOUR_TO_SECONDS,tagConds=[],timeStr='*/*/*,*:*,Monday',pivotTime="*,09:30").each do |fact|
  authenticator.kb.getFacts(elapsedTime=2*DAY_TO_SECONDS,[],"",pivotTime="1/27/2012,*:*").each do |fact|
    puts fact.to_s
  end
end


authenticator = Authenticator.new
#testFiles(authenticator)
#testFilter(authenticator)
authenticator.kb.getSimilar(authenticator.kb.facts.last,elapsedTime=7*DAY_TO_SECONDS).each do |fact|
  puts fact
end
authenticator.qat.each do |qat|
  puts qat
end
