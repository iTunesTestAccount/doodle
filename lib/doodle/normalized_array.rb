require 'enumerator'

module ArraySentence
  def join_with(sep = ', ', last = ' and ')
    if self.size > 1
      self[0..-2].join(sep) + last + self[-1].to_s
    else
      self[0].to_s
    end
  end
end

module NormalizedArrayMethods
  module InstanceMethods
    include ArraySentence

    #   def &(other)
    #     super
    #   end

    #   def *(other)
    #     super
    #   end

    #   def +(other)
    #     super
    #   end

    #   def -(other)
    #     super
    #   end

    def initialize(*args, &block)
      #p [:init, 1, args, block]
      if block_given?
        #p [:init, 2]
        original_block = block
        block = proc { |index|
          #p [:init, 3, index]
          normalize_value(original_block[normalize_index(index)])
        }
        #p [:init, 4, block]
      end
      replace(super(*args, &block))
    end

#     def initialize(*args, &block)
#       replace(super)
#     end

    def normalize_index(index)
      index
    end

    def normalize_value(value)
      #p [self.class, :normalize_value, value]
      value
    end

    # convenience method to check indices
    def normalize_indices(*indices)
      indices.map{ |index| normalize_index(index) }
    end

    # convenience method to check values
    def normalize_values(*values)
      if values.empty?
        values = self
      end
      values.map{ |value| normalize_value(value) }
    end

    def <<(value)
      super(normalize_value(value))
    end

#     def <=>(other)
#       super(normalize_values(*other))
#     end

#     def ==(other)
#       super(normalize_values(*other))
#     end

    def [](index)
      super(normalize_index(index))
    end

    def []=(index, value)
      super(normalize_index(index), normalize_value(value))
    end

    #   def assoc(key)
    #     super
    #   end

    def at(index)
      super(normalize_index(index))
    end

    #   def clear()
    #     super
    #   end

    #   def collect(&block)
    #     #FIXME
    #   end

    def collect!(&block)
      super() {|x| normalize_value(block.call(x))}
    end

    #   def compact()
    #     super
    #   end

    #   def compact!()
    #     super
    #   end

    def concat(other)
      super(normalize_values(*other))
    end

    def delete(value)
      super(normalize_value(value))
    end

    def delete_at(index)
      super(normalize_index(index))
    end

    #   def delete_if(&block)
    #     super
    #   end

    #   def each(&block)
    #     super
    #   end

    #   def each_index(&block)
    #     super
    #   end

    #   def empty?()
    #     super
    #   end

#     def eql?(other)
#       super(normalize_values(*other))
#     end

    def fetch(index)
      super(normalize_index(index))
    end

    # array.fill(obj)                                -> array
    # array.fill(obj, start [, length])              -> array
    # array.fill(obj, range )                        -> array
    # array.fill {|index| block }                    -> array
    # array.fill(start [, length] ) {|index| block } -> array
    # array.fill(range) {|index| block }             -> array
    def fill(*args, &block)
      # TODO: check value
      # check start, length
      replace(super)
    end

    def first(count = 1)
      # TODO: check count
      super
    end

    #   def flatten()
    #     super
    #   end

    #   def flatten!()
    #     super
    #   end

    #   def frozen?()
    #     super
    #   end

    #   def hash()
    #     super
    #   end

    def include?(value)
      super(normalize_value(value))
    end

    def index(value)
      super(normalize_value(value))
    end

    def insert(index, *values)
      super(normalize_index(index), normalize_values(*values))
    end

    #   def inspect()
    #     super
    #   end

    #   def join(sep = $,)
    #     super
    #   end

    def last(count = 1)
      # TODO: check count
      super
    end

    #   def length()
    #     super
    #   end

    #   def map(&block)
    #     super
    #   end

    def map!(&block)
      collect!(&block)
    end

    #   def nitems()
    #     super
    #   end

    #   def pack()
    #     super
    #   end

    #   def pop()
    #     super
    #   end

    def push(*values)
      super(normalize_values(*values))
    end

    #   def rassoc(key)
    #     super
    #   end

    #   def reject(&block)
    #     super
    #   end

    def reject!(&block)
      super() {|x| normalize_value(block.call(x))}
    end

    def replace(other)
      #p [:replace, other]
      super(other.to_enum(:each_with_index).map{ |v, i|
              #p [:replace_norm, i, v]
              normalize_index(i);
              normalize_value(v)
            })
    end

    #   def reverse()
    #     super
    #   end

    #   def reverse!()
    #     super
    #   end

    #   def reverse_each(&block)
    #     super
    #   end

    def rindex(value)
      super(normalize_value(value))
    end

    #   def select(&block)
    #     super
    #   end

    #   def shift()
    #     super
    #   end

    #     alias :size :length

    # array[index]                -> obj      or nil
    # array[start, length]        -> an_array or nil
    # array[range]                -> an_array or nil
    # array.slice(index)          -> obj      or nil
    # array.slice(start, length)  -> an_array or nil
    # array.slice(range)          -> an_array or nil
    def slice(*args)
      # TODO: check indices
      super
    end

    def slice!(*args)
      # TODO: check indices
      super
    end

    #   def sort(&block)
    #     super
    #   end

    #   def sort!(&block)
    #     super
    #   end

    #   def to_a()
    #     super
    #   end

    #   def to_ary()
    #     super
    #   end

    #   def to_s()
    #     super
    #   end

    #   def transpose()
    #     super
    #   end

    #   def uniq()
    #     super
    #   end

    #   def uniq!()
    #     super
    #   end

    def unshift(*values)
      super(normalize_values(*values))
    end

    def values_at(*indices)
      super(normalize_indices(*indices))
    end
    # deprecated - use values_at
    alias :indexes :values_at
    alias :indices :values_at

    # should this be normalized?
    #     def zip(other)
    #       super(normalize_values(*other))
    #     end

    #     def |(other)
    #       super(other.map{ |x| normalize_value(x)})
    #     end

  end

  module ClassMethods
    def [](*args)
      super.normalize_values
    end
  end
end

class NormalizedArray < Array
  include NormalizedArrayMethods::InstanceMethods
  extend NormalizedArrayMethods::ClassMethods
end

if __FILE__ == $0
  require 'rubygems'
  require 'doodle/assertion'

  class StringArray < NormalizedArray
    def normalize_value(v)
      #p [self.class, :normalize_value, v]
      v.to_s
    end
  end

  def BoundedArray(upper_bound)
    typed_class = Class.new(NormalizedArray) do
      define_method :normalize_index do |index|
        raise IndexError, "index #{index} out of range" if !(0..upper_bound).include?(index)
        index
      end
    end
    typed_class
  end

  def TypedArray(*klasses)
    typed_class = Class.new(NormalizedArray) do
      define_method :normalize_value do |v|
        if !klasses.any?{ |klass| v.kind_of?(klass) }
          raise TypeError, "#{self.class}: #{v.class}(#{v.inspect}) is not a kind of #{klasses.map{ |c| c.to_s }.join(', ')}", [caller[-1]]
        end
        v
      end
    end
    typed_class
  end
  TypedStringArray = TypedArray(String)

#   na = Array.new(4) { |i|
#     p [:in_block, i]
#     42
#   }
#   p na[1]
#   p na[1] == 42

  sa = StringArray.new(3) { |i|
    #p [:in_block, i]
    42
  }
  assert { sa[1] == "42" }
  assert_error { sa[1] == 42 }
  assert_error { sa.values == ["42"] * 3 }
  assert_error { sa.values == [42] }

  sa = nil
  assert_ok {  sa = StringArray.new([1,2,3]) }
  assert { sa == ["1", "2", "3"] }
  assert { (sa | ["4", "5", "6"]) == ["1", "2", "3", "4", "5", "6"] }
  assert { (sa | [4, 5, 6]) == ["1", "2", "3", 4, 5, 6] }
  assert { (sa | [4, 5, 6]).class == Array }

  # equality
  assert { sa == ["1", "2", "3"] }
  assert { ["1", "2", "3"] == sa }

  ## -FIXME: not sure about this coercion- FIXED
  assert_error { sa.eql?( [1, 2, 3] )}

  ## -FIXME: equality should not be non-commutative- FIXED
  assert_error { sa == [1, 2, 3] }
  assert_error { [1, 2, 3] == sa }

  BoundedArray4 = BoundedArray(4)
  ca = BoundedArray4.new([1,2,3])
  assert { ca == [1, 2, 3] }
  assert { ca[4] = 42 }
  expect_error(IndexError) { ca[5] = 42 }
  expect_error('out of range') { ca[5] = 42 }
  expect_error { ca[5] = 42 }
  #expect_ok { false }
  #expect_error { true }
  #assert_ok { true }

  assert_ok { ca = BoundedArray4.new([1,2,3,4,5]) }
  assert_error { ca = BoundedArray4.new([1,2,3,4,5,6]) }

  assert_error { sa = TypedStringArray.new([1,2,3]) }
  assert_ok { sa = TypedStringArray.new(["1","2","3"]) }

  #   ca = BoundedArray.new([1,2,3,4,5])
  #   pp ca

  TypedIntegerArray = TypedArray(Integer)
  ia = TypedIntegerArray.new([1,2,3])
  expect_error { ia[1] = "hello" }

  StringOrIntegerArray = TypedArray(Integer, String)
  ma = nil
  expect_ok { ma = StringOrIntegerArray.new([1,"2",3]) }
  expect_ok { ma[0] = "hello" }
  expect_error { ma[1] = Date.new }

  assert {
    ma = [].extend(ArraySentence)
    ma.join_with(', ', ' and ') == ""
  }

  assert {
    ma = [nil].extend(ArraySentence)
    ma.join_with(', ', ' and ') == ""
  }

  assert {
    ma = [nil, nil].extend(ArraySentence)
    ma.join_with(', ', ' and ') == " and "
  }

  assert {
    ma = [nil, nil, nil].extend(ArraySentence)
    ma.join_with(', ', ' and ') == ",  and "
  }

  assert {
    ma = [1].extend(ArraySentence)
    ma.join_with(', ', ' and ') == "1"
  }

  assert {
    ma = [1, 2].extend(ArraySentence)
    ma.join_with(', ', ' and ') == "1 and 2"
  }

  assert {
    ma = [1, 2, 3].extend(ArraySentence)
    ma.join_with(', ', ' or ') == "1, 2 or 3"
  }

  assert {
    ma = [1, 2, 3].extend(ArraySentence)
    ma.join_with(', ', ' and ') == "1, 2 and 3"
  }

  expect_error("Fixnum(1) is not a kind of String") { TypedStringArray[1,2,3] }
  expect_error(TypeError) { TypedStringArray[1,2,3] }

end
