
require 'java'

java_import java.util.TreeMap

class MultiRBTree
  DEFAULT_CMP_PROC = Proc.new {|lhs,rhs| lhs <=> rhs }
  include Enumerable

  @@TreeMap = TreeMap.java_class.constructor(java::util::Comparator)

  def initialize( *args, &block )
    # p block_given?
    self.default= if block_given?
      Proc.new( &block )
    elsif args.length == 1
      Proc.new {args[0]}
    else
      Proc.new {nil}
    end

    @cmp_proc = DEFAULT_CMP_PROC
    @dict = @@TreeMap.new_instance(@cmp_proc).to_java
    @size = 0
    @iterating = 0
  end

  def self.[](*args)
    if( args.length == 1 )
      raise Exception.new("not implemented yet")
    end

    if args.length % 2 != 0
      raise ArgumentError.new("odd number of arguments for #{self.name}[]")
    end
    r = MultiRBTree.new
    args.each_slice(2) { |k,v| r[k] = v }
    r
  end

  def cmp_proc()
    @cmp_proc
  end

  def default
    default_proc.call()
  end

  def default= default_value
    @default = default_value
  end

  def default_proc
    @default
  end

  def each(&block) 
    self.each_entry(@dict, &block)
  end

  alias :each_pair :each

  def reverse_each(&block)
    self.each_entry(@dict.descendingMap, &block)
  end

  def each_key( &block )
    self.each_entry(@dict) do |key,value|
      yield key
    end
  end

  def each_value( &block )
    self.each_entry(@dict) do |key,value|
      yield value
    end
  end

  def []=(key,value)
    raise TypeError.new("currently iterating") if @iterating > 0
    dict = @dict
    container = dict.get(key)
    if container == nil
      dict.put( key , [value] )
    else
      container << value
    end
    @size += 1
    value
  end

  def [](key)
    container = @dict.get(key)
    if container != nil
      container.first
    else
      default
    end
  end

  def delete key    
    raise TypeError.new("currently iterating") if @iterating > 0  
    container = @dict.get(key)
    if container == nil
      return yield key if block_given? else nil
    end
    container.delete_at(0)
    @size -= 1
    if container.empty?
      @dict.remove(key)
    end
    self
  end
                        
  def delete_if &block
    raise ArgumentError.new("block expected") unless block_given?
    iter = @dict.entrySet.iterator
    
    while( iter.hasNext )
      entry = iter.next   
      key = entry.key
      deleted = entry.value.delete_if { |value| yield key,value }
      @size -= deleted.length
      if entry.value.empty?
        iter.remove
      end
    end                   
    self
  end   
  
  def has_key? key
    @dict.containsKey key
  end

  alias :include? :has_key?
  alias :key? :has_key?

  def fetch( *args )
    raise ArgumentError.new "wrong number of arguments" if( args.length == 0 || args.length > 2 )
    if args.length == 2 && block_given?
      warn 'warning: block supersedes default value argument'
    end

    key = args[0]

    return self[key] if self.has_key? key

    if block_given?
      return yield key
    end
    if args.length == 1
      raise IndexError.new "key not found"
    else
      args[1]
    end
  end

  def has_value? value
    found = false
    self.each do |k,v|
      if value == v
        found = true
        break
      end
    end
    found
  end

  alias :value? :has_value?

  def size
    @size
  end

  def empty?
    size == 0
  end

  def first
    entry = @dict.firstEntry
    if entry == nil
      nil
    else
      [entry.get_key, self[entry.get_key]]
    end
  end

  def clear
    @dict.clear
    @size = 0
  end

  def to_a
    r = []
    self.each do |key,value|
      r << [key,value]
    end
    r
  end

  def ==( other )
    return true if self.equal?(other)
    return false unless other.is_a? MultiRBTree
    @dict.equals( other.dict )
  end

  protected
  def each_entry( map, &block )
    iter = map.entrySet.iterator
    @iterating += 1
    begin
      while( iter.hasNext() )
        entry = iter.next
        key = entry.get_key
        values = entry.get_value
        values.each do |value|
          yield(key, value)
        end
      end  
    ensure
      @iterating -= 1
    end
  end

  def dict
    @dict
  end
end

class RBTree < MultiRBTree

  def initialize( *args, &block )
    super( *args, &block )
  end

  def self.[](*args)
    if( args.length == 1 )
      raise Exception.new("not implemented yet")
    end

    if args.length % 2 != 0
      raise ArgumentError.new("odd number of arguments for #{self.name}[]")
    end
    r = RBTree.new
    args.each_slice(2) { |k,v| r[k] = v }
    r
  end

  def []=(key,value)
    @dict.put key, [value]
    value
  end

  def delete(key)
    @dict.remove(key)
    self
  end

  def size
    @dict.size
  end

end
p "--------------"
MultiRBTree[*%w(1 2 1 3 3 4 5 6)].each_pair {| k,v | p "#{k} -> #{v}"}
p MultiRBTree[1,2,1,3,3,4,5,6].fetch(1)
p MultiRBTree[1,2,1,3,3,4,5,6].fetch(6,7)
p MultiRBTree[1,2,1,3,3,4,5,6].fetch(6) {|key| "wibble - #{6}" }
p "--------------"
p MultiRBTree.new("d")[1]
p MultiRBTree.new{25}[1]
p MultiRBTree.new()[1]
m = MultiRBTree[1,2,1,3,3,4,5,6]
m.delete_if {|k,v| v > 3}
p m
p "--------------"
RBTree[*%w(1 2 1 3 3 4 5 6)].each {| k,v | p "#{k} -> #{v}"}
RBTree[*%w(1 2 1 3 3 4 5 6)].reverse_each {| k,v | p "#{k} -> #{v}"}


p RBTree[1,2,1,3,3,4,5,6].fetch(1)
p RBTree[1,2,1,3,3,4,5,6].fetch(6,7)
p RBTree[1,2,1,3,3,4,5,6].fetch(6) {|key| "wibble - #{6}" }

p "--------------"
p RBTree.new("d")[1]
p RBTree.new{25}[1]
p RBTree.new()[1]           

p RBTree[1,2,1,3,3,4,5,6] == RBTree[1,2,1,3,3,4,5,6]
p RBTree[*%w(a A)] == MultiRBTree[*%w(a A)]        

p RBTree.new.each
