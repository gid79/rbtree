begin
  require "./rbtree"
rescue LoadError
  require "./jrbtree"
end

require 'benchmark'

k = 10000
ks = 8
n = 100
keys = (0..k).map { (0..8).map{ ('a'..'z').to_a[rand(26)] }.join }

Benchmark.bmbm do |x|
  x.report("set #{k} keys #{n} times") do
    n.times do
      m = RBTree.new
      keys.each { |v| m[v] = v }
    end
  end
  x.report("set/get #{k} keys #{n} times") do
    n.times do
      m = RBTree.new
      keys.each { |v| m[v] = v }
      keys.each { |v| raise Error unless m[v] == v }
    end
  end
  x.report("set/remove #{k} keys #{n} times") do
    n.times do
      m = RBTree.new
      keys.each { |v| m[v] = v }
      keys.each { |v| m.delete v }
    end
  end
  if defined? JRUBY_VERSION
    require 'java'
    x.report("java #{k} keys #{n}") do
      n.times do
        Java::TreeMapReference.insert(keys)
      end
    end
    x.report("java set/get #{k} keys #{n}") do
      n.times do
        m = Java::TreeMapReference.insert(keys)
        Java::TreeMapReference.get(m, keys)
      end
    end
    x.report("java set/remove #{k} keys #{n}") do
      n.times do
        m = Java::TreeMapReference.insert(keys)
        Java::TreeMapReference.remove(m, keys)
      end
    end
  end
end