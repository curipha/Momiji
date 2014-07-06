#!/usr/bin/ruby

require 'strscan'
require 'net/http'

class Futaba
  ENCODE = 'CP932'  # a.k.a Windows-31J. Not Shift_JIS.

  def initialize(server)
    @server = server.downcase
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

  def parse(str, opt = {})
    threads = []

    ss = StringScanner.new(str)
    until ss.skip_until(%r!<td><a href='!).nil?
      ss.scan(%r!res/([0-9]+)\.html?!)

      if ss.matched?
        thread = { thread: ss[1] }

        initpos = ss.pos

        thrend = ss.exist?(%r!</td>!)         || 0
        resnum = ss.exist?(%r!<font size=2>!) || 0

        if resnum < thrend
          ss.pos = initpos + resnum
          ss.scan(%r!\(?([0-9]+)!)

          thread[:res] = ss[1].to_i
        end

        if opt[:img]
          ss.pos = initpos
          imgstart = ss.exist?(%r!<img src='!) || 0

          if ss.matched? && imgstart < thrend
            ss.pos += imgstart
            thread[:img] = ss.scan(%r![^']+!)
          end
        end

        if opt[:text]
          ss.pos = initpos
          textstart = ss.exist?(%r!<small>!)  || 0
          textend   = ss.exist?(%r!</small>!) || 0
          textend  -= ss.matched_size || 0    # Offset position of match string

          if textstart < thrend && textend < thrend && textend > textstart
            ss.pos += textstart
            thread[:text] = ss.peek(textend - textstart).strip
          end
        end

        threads << thread
      end
    end

    return threads
  end
end

class FutabaThread < Futaba
  def parse(str, opt)
    return []
  end
end

#f = FutabaCatalog.new('may')
#puts f.getthreads({img:nil, text:100})

