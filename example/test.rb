# -*- coding:utf-8 -*-
$:.unshift(File.dirname(__FILE__) + '/../lib')
require 'ja/complex_word'

text = 'ABC事件とは東京特許許可局でバスガス爆発が緊急発生した事件のことです'
jcw = Ja::ComplexWord.new
node_list = jcw.parse(text)
node_list.each do |node|
  if node.is_a?(Array)
    all = node.map{|n| n.surface }.join
    puts "#{all}\t複合語"
    node.each do |n|
      puts " - #{n.surface}\t#{n.feature}"
    end
  else
    puts "#{node.surface}\t#{node.feature}"
  end
end
