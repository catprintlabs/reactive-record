class TestContext

  attr_reader :last_hello_data
  
  def initialize
    puts "initialized TestContext #{self}"
    @hello_count = 0
  end
  
  def hello(data)
    puts "called #{self}.hello(#{data})  hello_count = #{@hello_count}"
    @last_hello_data = data
    @hello_count += 1
    puts "returning new hello_count of #{@hello_count}"
    @hello_count.to_s
  end
  
end