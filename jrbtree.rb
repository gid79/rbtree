
require 'java'

java_import java.util.TreeMap

class MultiRBTree

  class ComparatorWrapper
    java_implements 'java.util.Comparator'
    def initialize( block )
      @block = block
    end

    java_signature 'int compare(Object,Object)'
    def compare( lhs, rhs )
      @block.call(lhs, rhs)
    end
  end

  include Enumerable

  @@TreeMap = TreeMap.java_class.constructor(java::util::Comparator)

  def initialize( *args )
    # p args
    raise ArgumentError.new("odd number of arguments for #{self.class.name}") if args.length % 2 != 0
    @dict = @@TreeMap.new_instance(self.default_proc).to_java
    @size = 0
    args.each_slice(2) { |k,v| self[k] = v}
  end

  def default_proc()
    Proc.new {|lhs,rhs| lhs <=> rhs }
  end

  def each(&block)
    self.each_entry(@dict, &block)
    self
  end                 
  
  alias :each_pair :each
  
  def reverse_each(&block)
    self.each_entry(@dict.descendingMap, &block)
    self
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
      nil      
    end
  end    
  
  def delete key
    container = @dict.get(key)
    if container == nil
      return yield key if block_given? else nil
    end
    container.delete_at(0)
    @size -= 1
    if container.empty?
      dict.remove(key)
    end  
    self
  end

  def has_key? key
    @dict.containsKey key
  end     
  
  alias :include? :has_key?

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

  def self.[](*args)
    MultiRBTree.new(*args)
  end

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
      self[entry.get_key]
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
  
  protected
  def each_entry( map, &block )
    iter = map.entrySet.iterator
    while( iter.hasNext() )
      entry = iter.next
      key = entry.get_key
      values = entry.get_value
      values.each do |value|
        yield(key, value)
      end
    end
  end

end

class RBTree < MultiRBTree

  def initialize( *args )
    super( *args )
  end

  def []=(key,value)
    @dict.put key, value
    value
  end

  def delete(key)
    @dict.remove(key)
    self
  end   
  
  def [] (key)
    return @dict.get(key)
  end
  
  def self.[](*args)
    RBTree.new(*args)
  end

  def size
    @dict.size
  end

  protected
  def each_entry( map, &block )
    iter = map.entrySet.iterator
    while( iter.hasNext() )
      entry = iter.next
      yield(entry.get_key, entry.get_value)
    end
  end

end
# p "--------------"
# MultiRBTree[*%w(1 2 1 3 3 4 5 6)].each_pair {| k,v | p "#{k} -> #{v}"}
# p MultiRBTree[1,2,1,3,3,4,5,6].fetch(1)
# p MultiRBTree[1,2,1,3,3,4,5,6].fetch(6,7)
# p MultiRBTree[1,2,1,3,3,4,5,6].fetch(6) {|key| "wibble - #{6}" }        
# 
# p "--------------"
# RBTree[*%w(1 2 1 3 3 4 5 6)].each {| k,v | p "#{k} -> #{v}"}
# RBTree[*%w(1 2 1 3 3 4 5 6)].reverse_each {| k,v | p "#{k} -> #{v}"}
# 
# 
# p RBTree[1,2,1,3,3,4,5,6].fetch(1)
# p RBTree[1,2,1,3,3,4,5,6].fetch(6,7)
# p RBTree[1,2,1,3,3,4,5,6].fetch(6) {|key| "wibble - #{6}" }        

