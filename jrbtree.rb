
require 'java'
java_import java.util.TreeMap

#
class RBTreeDefaultCompare
  java_implements java.util.Comparator

  java_signature 'int compare(java.lang.Object,java.lang.Object)'
  def compare(lhs, rhs)
    cmp = lhs <=> rhs
    if cmp == nil then raise ArgumentError.new("comparison of #{lhs} with #{rhs} failed") end
    cmp
  end
end

class MultiRBTree

  DEFAULT_CMP_PROC = RBTreeDefaultCompare.new
  include Enumerable
        
  @@TreeMap = TreeMap.java_class.constructor(java::util::Comparator)

  def initialize(*args, &block )
    raise ArgumentError if args.length > 1 or (args.length == 1 and block_given?)
    def_value = args.length == 1 ? args.first : nil
    self.default= def_value
    if block_given?
      self.default=Proc.new(&block)
    end

    @cmp_proc = nil
    @dict = create_tree_map DEFAULT_CMP_PROC
    @size = 0
    @iterating = 0
  end

  def self.[](*args)
    result = self.new
    if args.length == 1
      input = args.first
      if self == RBTree and input.class == MultiRBTree
        raise TypeError.new("can't convert MultiRBTree to RBTree")
      end
      if input.is_a? MultiRBTree
        result.update!(input)
        return result
      end

      tmp = Hash.try_convert(input)
      if tmp != nil
        tmp.each { |k,v| result[k] = v }
        return tmp
      end

      tmp = Array.try_convert(input)
      if tmp != nil
        tmp.each do |v|
          v = Array.try_convert v
          if v == nil
            continue
          end
          case v.length
            when 1
              result[v[0]] = nil
            when 2
              result[v[0]] = v[1]
            else
              continue
          end
        end
        return tmp
      end
    end

    if args.length % 2 != 0
      raise ArgumentError.new("odd number of arguments for #{self.name}[]")
    end
    args.each_slice(2) { |k,v| result[k] = v }
    result
  end

  def default(*args)
    args_c = args.length
    key = nil
    if args_c == 1
      key = args.first
    elsif args_c > 1
      raise ArgumentError.new("unexpected number of arguments")
    end

    df = @default
    if is_callable?(df)
      return args_c == 0 ? nil : df.call(self, key)
    end
    df
  end

  def default=(value)
    @default=value
  end

  def default_proc
    is_callable?(@default) ? @default : nil
  end

  # call-seq:
  #   rbtree.cmp_proc => proc
  #
  # Returns the comparison block that is given by MultiRBTree#readjust.
  def cmp_proc
    @cmp_proc
  end

  # call-seq:
  #   rbtree.readjust                      => rbtree
  #   rbtree.readjust(nil)                 => rbtree
  #   rbtree.readjust(proc)                => rbtree
  #   rbtree.readjust {|key1, key2| block} => rbtree
  #
  # Sets a proc to compare keys and readjusts elements using the given
  # block or a Proc object given as the argument. The block takes two
  # arguments of a key and returns negative, 0, or positive depending
  # on the first argument is less than, equal to, or greater than the
  # second one. If no block is given it just readjusts elements using
  # current comparison block. If nil is given as the argument it sets
  # default comparison block.
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

    
    new_map = create_tree_map(cmp_proc)

    # note can't use putAll as there is an internal optization that short cuts the resorting
    # if the two maps share a common comparator
    self.each {|k,v| put_into k, v, new_map }
    @dict = new_map
    @cmp_proc = cmp_proc

    self
  end

  # call-seq:
  #   rbtree.each {|key, value| block} => rbtree
  #
  # Calls block once for each key in order, passing the key and value
  # as a two-element array parameters.
  def each(&block)
    self.each_entry(@dict, &block)
  end

  alias :each_pair :each

  # call-seq:
  #  rbtree.reverse_each {|key, value| block} => rbtree
  #
  # Calls block once for each key in reverse order, passing the key and
  # value as parameters.
  def reverse_each(&block)
    self.each_entry(@dict.descendingMap, &block)
  end

  # call-seq:
  #  rbtree.each_key {|key| block} => rbtree
  #
  # Calls block once for each key in order, passing the key as
  # parameters.
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

  # call-seq:
  #  rbtree.each_value {|value| block} => rbtree
  #
  # Calls block once for each key in order, passing the value as
  # parameters.
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

  alias :store :[]=

  def [](key)
    container = @dict.get(key)
    if container != nil
      container.first
    else
      default key
    end
  end

  def delete key, &block
    remove key, :shift, &block
  end
                        
  def delete_if &block
    raise ArgumentError.new("block expected") unless block_given?

    find_all(&block).each {| k,v | delete k }

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

  # call-seq:
  #   rbtree.lower_bound(key) => array
  #
  # Returns key-value pair corresponding to the lowest key that is
  # equal to or greater than the given key(inside of lower
  # boundary). If there is no such key, returns nil.
  def lower_bound(k)
    entry = @dict.ceilingEntry(k)
    array_of_entry entry, k, :first
  end     

  # call-seq:
  #   rbtree.upper_bound(key) => array
  #
  # Returns key-value pair corresponding to the greatest key that is
  # equal to or lower than the given key(inside of upper boundary). If
  # there is no such key, returns nil.
  def upper_bound(k)
    entry = @dict.floorEntry(k)
    array_of_entry entry, k, :last
  end

  # call-seq:
  #   rbtree.bound(key1, key2 = key1)                      => array
  #   rbtree.bound(key1, key2 = key1) {|key, value| block} => rbtree
  #
  # Returns an array containing key-value pairs between the result of
  # MultiRBTree#lower_bound and MultiRBTree#upper_bound. If a block is
  # given it calls the block once for each pair.
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

  # call-seq:
  #   rbtree.first => array or object
  #
  # Returns the first(that is, the smallest) key-value pair.
  def first        
    entry = @dict.firstEntry
    entry != nil ? array_of_entry(entry) : default(nil)
  end

  # call-seq:
  #   rbtree.last => array of object
  #
  # Returns the last(that is, the biggest) key-value pair.
  def last
    entry = @dict.lastEntry
    entry != nil ? array_of_entry(entry, :last) : default(nil)
  end

  # call-seq:
  #   rbtree.shift => array or object
  #
  # Removes the first(that is, the smallest) key-value pair and returns
  # it as a two-item array.
  def shift
    entry = @dict.firstEntry
    if entry != nil
      remove entry.key, :shift
      array_of_entry entry
    else
      default(nil)
    end
  end  

  # call-seq:
  #   rbtree.pop => array or object
  #
  # Removes the last(that is, the biggest) key-value pair and returns
  # it as a two-item array.
  def pop
    entry = @dict.lastEntry
    if entry != nil
      remove entry.key, :pop
      array_of_entry entry
    else
      default(nil)
    end
  end 
                
  def index value
    key, value = find {|k,v| v == value}
    key
  end
                   
  def replace tree
    raise TypeError.new("wrong argument type #{tree.class} expecting #{self.class}") unless tree.is_a? self.class
    new_map = create_tree_map tree.cmp_proc
    size = 0
    tree.each do |k,v| 
      put_into k,v,new_map
      size += 1
    end                                    
    self.default = tree.default
    @dict = new_map
    @cmp_proc = tree.cmp_proc
    @size = size
    self
  end
  
  def update(tree)
    raise TypeError.new("wrong argument type #{tree.class} expecting #{self.class}") unless tree.is_a? self.class
    new_tree = self.clone
    new_tree.update!(tree)
    new_tree
  end

  alias :merge :update

  def update!(tree)
    raise TypeError.new("wrong argument type #{tree.class} expecting #{self.class}") unless tree.is_a? self.class
    tree.each do |k,v|
      self[k] = v
    end
    self
  end

  alias :merge! :update!

  def reject &block
    self.clone.reject! &block
  end

  def reject! &block
    count = size
    delete_if &block
    count == size ? nil : self
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

  def to_rbtree
    self
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
    return false unless other.cmp_proc == cmp_proc
    to_a == other.to_a
  end
      
  def inspect
    dict_str = self.to_a.map{
        |p| p.map { |v| v != self ? v.inspect : "#<#{self.class.name}: ...>"}
            .join('=>')
    }.join(", ")
    "#<#{self.class.name}: {#{dict_str}}, default=#{default.inspect}, cmp_proc=#{cmp_proc.inspect}>"
  end

  #----- Internal Methods --------
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
      value = default(key)
      # the C implementation returns the teh default value on it's own
      # when there isn't a key (think first/last) other methods return 
      # a pair
      if value == nil then
        nil
      else
        key != nil ?
            [key, value] :
            value
      end
    else
      [entry.key, entry.value.send(method)]
    end
  end                         
  
  def compare(k1,k2)
    cp = cmp_proc
    if cp != nil 
      cp.call(k1,k2)
    else
      DEFAULT_CMP_PROC.compare(k1,k2)
    end
  end        
            
  def new_empty
    result = self.class.new
    result.default= default_proc != nil ? default_proc : default
    if cmp_proc
      result.readjust cmp_proc
    end
    # todo pass cmp_proc over to new invert copy etc
    result
  end
  
  def put_into( key, value, dict )
    container = dict.get(key)
    if container == nil
      dict.put( key, [value] )
    else
      container << value
    end
    value
  end
  
  def remove(key, operation = :shift, &block)
    raise TypeError.new("currently iterating") if @iterating > 0
    container = @dict.get(key)
    if container == nil
      if block_given?
        return yield key
      else
        return nil
      end
    end
    @size -= 1
    value = container.first
    if container.length > 1
      value = container.send(operation)
    else
      @dict.remove(key)
    end
    value
  end                                 
  
  def create_tree_map cmp_proc
    @@TreeMap.new_instance(cmp_proc != nil ? cmp_proc : DEFAULT_CMP_PROC).to_java
  end

  def is_callable?(value)
    # coded as
    #if (FL_TEST(self, RBTREE_PROC_DEFAULT))
    # in rbtree.c
    value != nil and value.respond_to? :call
  end
end

class RBTree < MultiRBTree

  def initialize( *args, &block )
    super( *args, &block )
  end

  def size
    @dict.size
  end

  def [](key)
    value = @dict.get(key)
    if value == nil
      # have to use containsKey as the map can contain nil as a valid value
      @dict.containsKey(key) ? value : default(key)
    else
      value
    end
  end

  def remove(key, operation = :shift, &block)
    raise TypeError.new("currently iterating") if @iterating > 0
    unless @dict.containsKey(key)
      if block_given?
        return yield key
      else
        return nil
      end
    end

    @dict.remove(key)
  end

  def update tree, &block
    raise TypeError.new("wrong argument type #{tree.class} expecting #{self.class}") unless tree.is_a? self.class
    tree.each do |k,v|
      if key? k and block_given?
        self[k] = yield(k, self[k], v)
      else
        self[k] = v
      end
    end
    self
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


  protected
  def each_entry( map, &block )
    if block_given?
      @iterating += 1
      begin
        map.each do |key, value|
          yield [key, value]
        end
      ensure
        @iterating -= 1
      end
    else
      Enumerator.new(self, :each_entry, map)
    end
  end

  def array_of_entry entry, key=nil, method=:ignored
    if entry == nil
      value = default(key)
      # the C implementation returns the teh default value on it's own
      # when there isn't a key (think first/last) other methods return
      # a pair
      if value == nil then
        nil
      else
        key != nil ?
            [key, value] :
            value
      end
    else
      [entry.key, entry.value]
    end
  end

  def put_into( key, value, dict )
    dict.put( key, value )
    value
  end
end

if __FILE__ == $0
  a = [%w(a A), %w(b B), %w(c C), %w(d D)]
  t = RBTree[[%w(a A), %w(b B), %w(c C), %w(d D)]]
  p t["a"]
  p t["b"]
  p "--------------"
  p MultiRBTree[*%w(1 2 1 3 3 4 5 6)].inspect
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

  e = RBTree[1,2,3,4].each
  p e
  a,b = e.next
  p a
  p b
end