
require 'java'

java_import java.util.TreeMap

class MultiRBTree 
  DEFAULT_CMP_PROC = Proc.new {|lhs,rhs| 
    cmp = lhs <=> rhs 
    raise ArgumentError.new("comparison of #{lhs} with #{rhs} failed") if cmp == nil
    cmp
  }        
  include Enumerable
        
  attr_accessor :default,:default_proc
  @@TreeMap = TreeMap.java_class.constructor(java::util::Comparator)

  def initialize( def_value=nil, &block )
    # p block_given?
    self.default = def_value
    self.default_proc = block_given? ? Proc.new(&block) : nil
    
    @cmp_proc = nil
    @dict = @@TreeMap.new_instance(DEFAULT_CMP_PROC).to_java
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

  def cmp_proc
    @cmp_proc
  end
                        
  def readjust(*args, &block)                             
    cmp_proc = if args.length == 1                                  
         proc = args.first
         raise TypeError.new("not a Proc") unless proc == nil or proc.is_a? Proc 
         raise ArgumentError.new("both proc and block specified") if block_given?
         proc                                                                    
       elsif args.length > 1
         raise ArgumentError.new("too many arguments")
       elsif block_given?
         raise ArgumentError.new("invalid proc") if block.arity != 2
         Proc.new(&block)
       elsif @cmp_proc != nil
         @cmp_proc
       else
         nil
       end

    
    new_map = @@TreeMap.new_instance(cmp_proc != nil ? cmp_proc : DEFAULT_CMP_PROC).to_java

    # note can't use putAll as there is an internal optization that short cuts the resorting
    # if the two maps share a common comparator
    self.each {|k,v| put_into k, v, new_map }
    @dict = new_map
    @cmp_proc = cmp_proc

    self
  end

  def default_value                                       
    default_proc != nil ? default_proc.call() : default
  end                                                  
  
  # def default 
  #   default_proc != nil ? default_proc.call() : @default
  # end
  # 
  # def default=(default_value)
  #   p "default=#{default_value}"
  #   @default = default_value
  # end
  # 
  # def default_proc
  #   @default_proc
  # end

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
          
  def keys
    r = []
    each_key { |key| r << key }
    r
  end
  
  def each_value( &block )
    self.each_entry(@dict) do |key,value|
      yield value
    end
  end
  
  def values
    r = []
    each_value {|value| r << value}
    r
  end         
  
  def values_at *keys
    keys.map{ |k| self[k] }
  end
  
  def []=(key,value)
    raise TypeError.new("currently iterating") if @iterating > 0
    put_into(key,value,@dict)
    @size += 1
  end

  def [](key)
    container = @dict.get(key)
    if container != nil
      container.first
    else
      default_value
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
                  
  def lower_bound(k)
    entry = @dict.ceilingEntry(k)
    array_of_entry entry, k, :first
  end     
  
  def upper_bound(k)
    entry = @dict.floorEntry(k)
    array_of_entry entry, k, :last
  end
  
  def bound( k1, k2 = k1, &block )
    return [] if compare(k1,k2) > 0
    selection = @dict.subMap(k1, true, k2, true)
    if block_given?
      each_entry selection, &block
      self
    else         
      result = []
      each_entry(selection) { |k,v| result << [k,v] }
      result
    end
  end       
  
  def size
    @size
  end
  alias :length :size
  
  def empty?
    size == 0
  end
                      
  def first        
    entry = @dict.firstEntry
    entry != nil ? array_of_entry(entry) : default_value
  end
  
  def last
    entry = @dict.lastEntry
    entry != nil ? array_of_entry(entry) : default_value
  end

  def index value
    key, value = find {|k,v| v == value}
    key
  end
  
  def clear
    @dict.clear
    @size = 0
  end
              
  def invert
    result = new_empty
    self.each {|key,value| result[value] = key}
    result
  end     
  
  def clone                    
    result = new_empty
    self.each {|key,value| result[key] = value}
    result
  end
  
  def to_a
    r = []
    self.each do |key,value|
      r << [key,value]
    end
    r
  end   
  
  def to_s
    self.to_a.to_s
  end
  
  def to_hash
    raise TypeError.new("cannot convert a MultiRBTree to a Hash")
  end                                                            
               
  def marshal_dump
    raise TypeError.new("default_proc is set: unable to dump Proc's") unless default_proc == nil
    raise TypeError.new("cmp_proc is set: unable to dump Proc's") unless @cmp_proc == nil
    [to_a, default]
  end                              
  
  def marshal_load data
    a, d = data
    initialize(d)
    a.each {|k,v| self[k]=v}
  end                              
  
  def ==( other )
    return true if self.equal?(other)
    return false unless other.is_a? MultiRBTree
    @dict.equals( other.dict )
  end
      
  def inspect
    "#<#{self.class.name}: {#{self.to_a.map{|p| p.map{|v| v.inspect}.join('=>')}.join(", ")}}, default=#{default.inspect}, cmp_proc=#{cmp_proc.inspect}>"
  end                    
        
  #----- Protected Methods --------
  protected
  def each_entry( map, &block )  
    if block_given?
      @iterating += 1
      begin               
        map.each do |key, values| 
          values.each do |value|
            yield [key, value]
          end             
        end                     
      ensure
        @iterating -= 1
      end
    else
      Enumerator.new(self, :each_entry, map)
    end
  end

  def dict
    @dict
  end
  
  def array_of_entry entry, key=nil, method=:first
    if entry == nil
      value = default
      # nested teneray... eek
      # the C implementation returns the teh default value on it's own 
      # when there isn't a key (think first/last) other methods return 
      # a pair
      (value == nil ? 
          nil : 
          ( key != nil ? 
              [key, value] :
              value ))
    else
      [entry.key, entry.value.send(method)]
    end
  end                         
  
  def compare(k1,k2)
    cp = cmp_proc
    if cp != nil 
      cp.call(k1,k2)
    else
      DEFAULT_CMP_PROC.call(k1,k2)
    end
  end        
            
  def new_empty
    result = self.class.new
    result.default=self.default  
    # todo pass cmp_proc over to new invert copy
    result
  end
  
  def put_into( key, value, dict)
    container = dict.get(key)
    if container == nil
      dict.put( key , [value] )
    else
      container << value
    end
    value
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

  def delete(key)
    @dict.remove(key)
    self
  end

  def size
    @dict.size
  end
        
  def to_hash
    result = Hash.new
    result.default= @default 
    if default_proc != nil
      result.default_proc = default_proc
    end
    self.each{|k,v| result[k] = v}
    result
  end
  
  def put_into( key, value, dict )
    dict.put key, [value]
    value
  end
end
# p "--------------"
# p MultiRBTree[*%w(1 2 1 3 3 4 5 6)].inspect
# MultiRBTree[*%w(1 2 1 3 3 4 5 6)].each_pair {| k,v | p "#{k} -> #{v}"}
# p MultiRBTree[1,2,1,3,3,4,5,6].fetch(1)
# p MultiRBTree[1,2,1,3,3,4,5,6].fetch(6,7)
# p MultiRBTree[1,2,1,3,3,4,5,6].fetch(6) {|key| "wibble - #{6}" }
# p "--------------"
# p MultiRBTree.new("d")[1]
# p MultiRBTree.new{25}[1]
# p MultiRBTree.new()[1]
# m = MultiRBTree[1,2,1,3,3,4,5,6]
# m.delete_if {|k,v| v > 3}
# p m
# p "--------------"
# RBTree[*%w(1 2 1 3 3 4 5 6)].each {| k,v | p "#{k} -> #{v}"}
# RBTree[*%w(1 2 1 3 3 4 5 6)].reverse_each {| k,v | p "#{k} -> #{v}"}
# 
# 
# p RBTree[1,2,1,3,3,4,5,6].fetch(1)
# p RBTree[1,2,1,3,3,4,5,6].fetch(6,7)
# p RBTree[1,2,1,3,3,4,5,6].fetch(6) {|key| "wibble - #{6}" }
# 
# p "--------------"
# p RBTree.new("d")[1]
# p RBTree.new{25}[1]
# p RBTree.new()[1]           
# 
# p RBTree[1,2,1,3,3,4,5,6] == RBTree[1,2,1,3,3,4,5,6]
# p RBTree[*%w(a A)] == MultiRBTree[*%w(a A)]        
# 
# e = RBTree[1,2,3,4].each
# p e
# a,b = e.next              
# p a
# p b

# p RBTree.new("e").default