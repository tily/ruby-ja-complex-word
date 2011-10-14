# -*- coding: utf-8 -*-
require 'MeCab'
require 'ostruct'

class Ja
  class ComplexWord
    DEFAULT_UNKNOWN = '未知語'
    RULE_BASE = {:noun1 => false, :noun2 => false, :verb => false}

    # コンストラクタ。オプションを指定することができる。
    def initialize(opts={})
      @opts = opts
    end

    # 入力されたオブジェクトを複合語考慮した配列にパースして返す。
    # 引数には下記オブジェクトを取ることができる。
    #
    # * IO オブジェクト (#read で日本語テキストを返すもの)
    # * String オブジェクト (日本語テキスト)
    # * MeCab::Node オブジェクト
    # * Array オブジェクト (各要素は文字列を返す surface, feature メソッドを持つ必要がある)
    def parse(arg)
      unk = @opts[:unk] || DEFAULT_UNKNOWN
      nodes = []
      if arg.respond_to?(:read)
        nodes = to_nodes(arg.read)
      elsif arg.is_a?(String)
        nodes = to_nodes(arg)
      elsif arg.is_a?(MeCab::Node)
        node = arg
        nodes = []
        while node
          nodes << OpenStruct.new(:surface => node.surface, :feature => node.feature)
          node = node.next
        end
      elsif arg.is_a?(Array)
        nodes = arg
      else
        raise ArgumentError, 'Error: arg1 must be either an IO, String or Array.'
      end
      parse_nodes(nodes)
    end

    # MeCab を用いて日本語テキストを解析し MeCab::Node 風の OpenStruct オブジェクトを含む配列にして返す。
    # 形態素が未知の場合には :unk オプションに指定された文字列 (デフォルトは「未知語」) を利用し、
    # 素性を '未知語,' に設定する。
    def to_nodes(text)
      list = []
      tagger = MeCab::Tagger.new("-U %M\\t#{@opts[:unk]},\\n")
      result = tagger.parse(text)
      result.split("\n").each do |line|
        surface, feature = line.chomp.split("\t")
        list << OpenStruct.new(:surface => surface, :feature => feature || '')
      end
      list
    end

    # Array オブジェクト (各要素は文字列を返す surface, feature メソッドを持つ) を受け取り、
    # 複合語と思われる連続を Array 内の Array にパースして返却する。
    def parse_nodes(nodes)
      rule = RULE_BASE
      rule.update(@opts[:rule]) if @opts[:rule]
      terms = []    # 複合語リスト作成用の作業用配列
      unknown = []  # 「未知語」整形用作業変数
      must  = false # 次の語が名詞でなければならない場合は真
      result = []

      nodes.each do |node|
        # 記号・数値で区切られた「未知語」は、１つのまとまりにしてから処理
        if node.feature[/^#{@opts[:unk]},/u] && !node.surface[/^[\(\)\[\]\<\>|\"\'\;\,]/]
          if unknown.empty?
            unknown << node
            next
          end
          # 「未知語」が記号・数値で結びつかない
          unless unknown.last[/[A-Za-z]/] && node.surface[/^[A-Za-z]/]
            unknown << node # 「未知語」をひとまとめにする
            next
          end
        end
        # ひとまとめにした「未知語」を蓄積する
        while !unknown.empty?
          if unknown.last =~ /^[\x21-\x2F]|[{|}:\;\<\>\[\]]$/
            unknown.pop
          else
            break
          end
        end
        terms.concat(unknown) if !unknown.empty?
        unknown = []
  
        # 基本ルール
        if node.feature[/^名詞,(一般|サ変接続|固有名詞),/u] ||
           node.feature[/^名詞,接尾,(一般|サ変接続),/u]     ||
           node.feature[/^名詞,固有名詞,/u]                 ||
           node.feature[/^記号,アルファベット,/u]           ||
           node.feature[/^m語,/u] && node.surface !~ /^[\x21-\x2F]|[{|}:\;\<\>\[\]]$/
          terms << node
          must = false
          next
        # 名詞ルール1
        elsif node.feature[/^名詞,(形容動詞語幹|ナイ形容詞語幹),/u]
          terms << node
          must = rule[:noun1]
          next
        # 名詞ルール2
        elsif node.feature[/^名詞,接尾,形容動詞語幹,/u]
          terms << node
          must = rule[:noun2]
          next
        end

        # 動詞ルール
        must = rule[:verb] if node.feature[/^動詞,/u]

        if must || terms.size == 1
          result += terms if !terms.empty?
        else
          result << terms if !terms.empty?
        end

        terms = []
        must = false
        result << node
      end
      result
    end
  end
end
