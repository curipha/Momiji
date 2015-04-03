#!/usr/bin/env ruby

require 'net/http'
require 'rubygems'
require 'nokogiri'

module Futaba

  class Base
    attr_reader :server

    def initialize(server)
      @server = server.downcase
    end

    def host
      return "#{@server}.2chan.net"
    end
    def port
      return '80'
    end
    def path
      return '/'
    end

    private

    def connect
      if @dom.nil?
        header = {
          'User-Agent' => 'Mozilla/5.0 (X11; Linux i686; rv:29.0) Gecko/20100101 Firefox/29.0', # Firefox29 on Linux x86
          'Accept'     => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language' => 'en-US,en;q=0.5',
        }
        header['Cookie'] = cookie if self.class.private_method_defined?(:cookie)

        Net::HTTP.start(host, port) {|http|
          http.request_get(path, header) {|responce|
            @dom = nokogiri(responce.body) if responce.code == '200'
          }
        }
      end

      return @dom
    end

    def nokogiri(str)
      if str.is_a?(String) && !str.strip.empty?
        return Nokogiri::HTML(str.encode(Encoding::UTF_8, Encoding::CP932)) {|config|
          config.options = Nokogiri::XML::ParseOptions::STRICT | Nokogiri::XML::ParseOptions::NONET
        }
      else
        return nil
      end
    end
  end

  class Catalog < Base
    attr_accessor :text, :img

    def path
      return URI::catalog
    end

    def getthreads
      html = connect

      threads = []
      unless html.nil?
        html.xpath('//td').each {|td|
          next unless td.xpath('a[1]/@href').to_s =~ %r!res/(\d+)\.html?!

          threads << Futaba::Thread.new(
            @server,
            $1.strip,
            td.xpath('font[@size="2"]/text()').to_s =~ %r!\(?(\d+)! ? $1.to_i : 0,
            @img  ? td.xpath('a[1]/img[1]/@src').to_s.strip : nil,
            @text ? td.xpath('small/text()').to_s.strip     : nil
          )
        }
      end

      return threads
    end

    private

    def cookie
      c  = "cxyl=100x100x#{@text || 0}"
      c += "x0x#{@img || 0}" if @server == 'may'

      return c
    end
  end

  class Thread < Base
    attr_reader :id, :rescount, :catalogimg, :catalogtext

    XPATH_IMG = 'a[contains(@href, "/b/src/")][./img]/@href'

    def initialize(server, id, rescount = nil, catalogimg = nil, catalogtext = nil)
      super(server)

      @id = id

      @rescount    = rescount
      @catalogimg  = catalogimg
      @catalogtext = catalogtext
    end

    def path
      return URI::thread(@id)
    end

    def getall
      return [ getfirst ] + getres
    end

    def getfirst
      return parse_post(connect.xpath('//form[2]'))
    end
    def getres
      res = []
      connect.xpath('//td[@bgcolor="#F0E0D6"][@class="rtd"]').each {|post|
        res << parse_post(post)
      }
      @rescount = res.length
      return res
    end

    def getimgs
      return connect.xpath('//' + XPATH_IMG).to_a.map(&:to_s)
    end

    private

    def parse_post(node)
      txtnode = node.xpath('text()').to_s

      return Futaba::Post.new(
        no:      node.xpath('input[@value="delete"]/@name').to_s.to_i,
        name:    node.xpath('font[@color="#117743"]/b/text()').to_s.strip,
        email:   node.xpath('font[@color="#117743"]/b/a[starts-with(@href, "mailto:")]/@href').to_s.strip,
        title:   node.xpath('font[@color="#cc1105"]/b/text()').to_s.strip,
        message: node.xpath('blockquote/node()').to_s.strip,
        img:     node.xpath(XPATH_IMG).to_s.strip,

        id:   txtnode =~ %r!ID:(^\s+)! ? $1.strip : '',
        ip:   txtnode =~ %r!IP:(^\s+)! ? $1.strip : '',

        date: txtnode =~ %r!(\d+)/(\d+)/(\d+)[^\d]+(\d+):(\d+):(\d+)! \
          ? Time.mktime($1.to_i < 100 ? $1.to_i + 2000 : $1.to_i, $2, $3, $4, $5, $6) \
          : Time.mktime(0)
      )
    end
  end

  class Post
    attr_reader :no, :name, :email, :title, :message, :img, :id, :ip, :date

    def initialize(post = {})
      @no      = post[:no]
      @name    = post[:name]
      @email   = post[:email]
      @title   = post[:title]
      @message = post[:message]
      @img     = post[:img]
      @id      = post[:id]
      @ip      = post[:ip]
      @date    = post[:date]
    end
  end

  module URI
    module_function

    def thread(id)
      return "/b/res/#{id}.htm"
    end
    def catalog
      return '/b/futaba.php?mode=cat'
    end
  end
end

