#!/usr/bin/ruby

require 'nokogiri'
require 'net/http'

class Futaba
  ENCODE = 'CP932'  # a.k.a Windows-31J. Not Shift_JIS.

  def initialize(server)
    # Server host name
    @server = server.downcase

    # Nokogiri object
    @noko = nil
  end

  def host()
    return "#{@server}.2chan.net"
  end
  def thread(id)
    return "/b/res/#{id}.htm"
  end
  def catalog()
    return '/b/futaba.php?mode=cat'
  end

  def connect(addr, cookie = nil)
    # Firefox29 on Linux x86
    header = {
      'User-Agent' => 'Mozilla/5.0 (X11; Linux i686; rv:29.0) Gecko/20100101 Firefox/29.0',
      'Accept'     => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language' => 'en-US,en;q=0.5',
      'Accept-Encoding' => 'gzip, deflate'
    }
    header['Cookie'] = cookie unless cookie.nil?

    body = ''
    Net::HTTP.start(host()) {|http|
      http.request_get(addr, header) {|responce|
        case responce
        when Net::HTTPOK  # 200 OK
          body = responce.body.strip
        else
          body = ''
        end
      }
    }

    return body
  end

  def parse_file(path, opt = {})
    return File.readable?(path) \
      ? parse(IO.read(path, { encoding: ENCODE }), opt) \
      : []
  end
  def parse(str = '', opt = {})
    # Override me!
    return []
  end

  private
  def getnoko(str)
    return @noko if str.empty? && ! @noko.nil?

    n = Nokogiri::HTML(str, nil, ENCODE) {|cfg| cfg.nonet }
    @noko = n

    return n
  end
end

class FutabaCatalog < Futaba
  # Option parameter (common)

  # opt[:text]
  #   if nil or not defined, 1's text will not shown.
  #   if integer, it treats as text length
  # opt[:img]
  #   if nil or not defined, 1's image URI will not shown.
  #   if 0, it displays as smallest size URI.
  #   if 1-6, it displays as bigger size URI. (may only)

  def getthreads(opt = {})
    return parse(connect(catalog(), cookie(opt)), opt)
  end

  def cookie(opt = {})
    text = opt[:text] || 0
    c  = "cxyl=100x100x#{text}"

    if @server == 'may'
      size = opt[:img] || 0
      c += "x0x#{size}"
    end

    return c
  end

  def parse(str = '', opt = {})
    threads = []

    getnoko(str).xpath('//td').each {|td|
      next unless td.xpath('a[1]/@href').to_s =~ %r!res/(\d+)\.html?!

      threads << {
        thread: $1.to_i,
        res:    td.xpath('font[@size="2"]/text()').to_s =~ %r!\(?(\d+)! ? $1.to_i : 0,

        img:    opt[:img]  ? td.xpath('a[1]/img[1]/@src').to_s.strip : '',
        text:   opt[:text] ? td.xpath('small/text()').to_s.strip     : ''
      }
    }

    return threads
  end
end

class FutabaThread < Futaba
  XPATH_IMG = 'a[contains(@href, "/b/src/")][./img]/@href'

  def initialize(server)
    super

    # Thread ID
    @thread = nil
  end

  def parse(str = '', opt = {})
    noko = getnoko(str)

    thread = [ parse_node(noko.xpath('//form[2]')) ]
    noko.xpath('//td[@bgcolor="#F0E0D6"][@class="rtd"]').each {|res|
      thread << parse_node(res)
    }

    return thread
  end
  def parse_thread(id)
    @thread = id
    return parse(connect(thread(id)))
  end

  def getimgs(str = '')
    return getnoko(str).xpath('//' + XPATH_IMG).to_a
  end


  private
  def parse_node(node)
    txtnode = node.xpath('text()').to_s.strip

    return {
      no:      node.xpath('input[@value="delete"]/@name').to_s.to_i,
      name:    node.xpath('font[@color="#117743"]/b/text()').to_s.strip,
      email:   node.xpath('font[@color="#117743"]/b/a[starts-with(@href, "mailto:")]/@href').to_s.strip,
      title:   node.xpath('font[@color="#cc1105"]/b/text()').to_s.strip,
      comment: node.xpath('blockquote/node()').to_s.gsub(%r!<br(\s+/)?>!, "\n").strip,
      img:     node.xpath(XPATH_IMG).to_s.strip,

      id:   txtnode =~ %r!ID:(^\s+)! ? $1.strip : '',
      ip:   txtnode =~ %r!IP:(^\s+)! ? $1.strip : '',

      date: txtnode =~ %r!(\d+)/(\d+)/(\d+)[^\d]+(\d+):(\d+):(\d+)! \
             ? Time.mktime($1.to_i < 100 ? $1.to_i + 2000 : $1.to_i, $2, $3, $4, $5, $6) \
             : Time.mktime(0)
    }
  end
end

#f = FutabaCatalog.new('may')
#puts f.getthreads({img:nil, text:100})

#f = FutabaThread.new('jun')
#f.parse_file('./path_to_local.html')
#p f.parse_thread(19599717)
#puts f.getimgs

