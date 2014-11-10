=begin //comment
/**
 * Project:     DocodocoJP: どこどこJP アクセスライブラリー
 * File:        docodocoJP.rb
 * 
 * @link        http://www.docodoco.jp
 * @copyright   2011 - Cyber Area Research,Inc.
 * @support     support@arearesearch.co.jp
 * @author      Ken Nakanishi <ken@arearesearch.co.jp>
 * @package     DocodocoJP
 * @version     1.0.0
 * @last update 2011/08/29
 * @ruby version 1.8.5
 * @license     GNU Lesser General Public License (LGPL)
 */
=end //comment

require 'net/http'
require 'rexml/document'
require 'kconv'

HTTP_HOST = 'api.docodoco.jp'
HTTP_PORT = 80
USER_AGENT = "moduleRuby/#{RUBY_VERSION}"

class DocodocoJP
  #--------------------------------------------------
  public

  # コンストラクタ
  #
  # @param string apikey1
  # @param string apikey2
  # @return object instance
  # @access public
  #
  def initialize( apikey1, apikey2 )
    @apikey1 = ""
    @apikey2 = ""
    @targetIP = ""
    @hashResult = Hash.new
    @hashStatus = {"code"=>"", "message"=>""}
    @charset = "UTF-8"

    request_path = "/v3/user_info?key1=#{apikey1}&key2=#{apikey2}"
    xmldoc = api_access( request_path )
    if( xmldoc.elements['/docodoco/user_status'].get_text != "201" ) then
      raise xmldoc.elements['/docodoco/user_status_message'].get_text.to_s
    end

    @apikey1 = apikey1
    @apikey2 = apikey2
    return( TRUE )
  end

  # どこどこJPの値をハッシュで取得
  #
  # @return mixed 成否/検索結果hash
  # @access public
  #
  def GetAttribute()
    return( FALSE )  if( @apikey1.length * @apikey2.length == 0 )

    request_path  = "/v3/search?key1=#{@apikey1}&key2=#{@apikey2}"
    if( @targetIP != "" ) then
      request_path += "&ip=#{@targetIP}"
    end
    xmldoc = api_access( request_path )
    @hashResult = xml2hash( xmldoc.elements['/docodoco'] )

    if( @hashResult.key?('IP') ) then
      @hashStatus = {"code"=>"200", "message"=>"OK"}
    else
      if( @hashResult.key?('status') ) then
        @hashStatus = {"code"=>@hashResult['status'], "message"=>@hashResult['message']}
      else
        @hashStatus = {"code"=>"404", "message"=>"Not Found"}
      end
      @hashResult = {}
    end
      
    return( @hashResult )
  end


  # getter methods

  # 直前の検索結果をハッシュで取得
  #
  # @return hash 検索結果hash
  # @access public
  #
  def GetHash()
    return( @hashResult )
  end
  # for compatibility
  def GetArray()
    return( @hashResult )
  end

  # 検索結果ステータスをハッシュで取得
  #
  # @return hash 検索結果ステータスhash
  # @access public
  #
  def GetStatus()
    return( @hashStatus )
  end


  # setter methods

  # APIキー1をセット
  #
  # @param string strAPIkey APIキー1
  # @return boolean 成否
  # @access public
  #
  def SetKey1( strAPIkey )
    return( FALSE )  if( strAPIkey == "")

    @apikey1 = strAPIkey
    return( TRUE )
  end

  # APIキー2をセット
  #
  # @param string strAPIkey APIキー2
  # @return boolean 成否
  # @access public
  #
  def SetKey2( strAPIkey )
    return( FALSE )  if( strAPIkey == "")

    @apikey2 = strAPIkey
    return( TRUE )
  end

  # 検索対象IPアドレスをセット
  #
  # @param string strIPaddr IPアドレス
  # @return boolean 成否
  # @access public
  #
  def SetIP( strIPaddr )
    #-------  parse IPv4 address ------
    return( FALSE )  if( strIPaddr !~ /^([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$/ )

    #---- check for each octets ----
    return( FALSE )  if( $1.to_i<0 or $1.to_i>255 )
    return( FALSE )  if( $2.to_i<0 or $2.to_i>255 )
    return( FALSE )  if( $3.to_i<0 or $3.to_i>255 )
    return( FALSE )  if( $4.to_i<0 or $4.to_i>255 )
    #-------

    @targetIP = strIPaddr
    return( TRUE )
  end

  # 結果文字列の文字コードのセット
  #
  # @param string strCharSet 文字コード(JIS,Shift_JIS,EUC-JP,UTF-8)
  # @return boolean 成否
  # @access public
  #
  def SetChar( strCharSet )
    return( FALSE )  if( strCharSet !~ /^(JIS|Shift_JIS|EUC\-JP|UTF\-8)$/ )

    @charset = strCharSet
    return( TRUE )
  end


  #--------------------------------------------------
  private

  # APIサーバーにアクセスする
  #
  # @param string request_path APIに対するリクエストパス(各パラメータを含む)
  # @return XMLDocument APIサーバーからのレスポンスをXML化したもの
  # @access private
  #
  def api_access( request_path )
    response_body = ""
    begin
      req = Net::HTTP::Get.new( request_path )
      req['User-Agent'] = ENV['HTTP_USER_AGENT'].to_s + "(#{USER_AGENT})"
      referer = ( ENV.key?('HTTPS') ? "https://" : "http://" ) + ENV['HTTP_HOST'].to_s + ENV['REQUEST_URI'].to_s
      req.add_field('Referer', referer)

      Net::HTTP.start( HTTP_HOST, HTTP_PORT ) { |http|
        response = http.request( req )

        if( response.code!="200" ) then
          raise "API server response error"
        end

        response_body = response.body
        #print "----\n#{response_body}\n----\n"
      }
    rescue
      raise "API server response error"
    end
    return( REXML::Document.new( response_body ) )
  end

  # XML文書をハッシュに展開する。文字コード変換も行う
  #
  # @param XMLDocument xmldoc XML文書
  # @return hash ハッシュ
  # @access private
  #
  def xml2hash( xmldoc )
    hResult = Hash.new
    return hResult if xmldoc.nil?

    xmldoc.root.elements.each{|elem|
      #elem.name = elem.name.to_s     ... no need to do this
       elem.text = elem.text.to_s

      case @charset
      when "JIS"
        elem.name = elem.name.tojis
        elem.text = elem.text.tojis
      when "Shift_JIS"
        elem.name = elem.name.tosjis
        elem.text = elem.text.tosjis
      when "EUC-JP"
        elem.name = elem.name.toeuc
        elem.text = elem.text.toeuc
      end

      hResult[elem.name] = elem.text
    }
    return( hResult )
  end

end

