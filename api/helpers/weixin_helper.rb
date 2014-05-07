module WeixinHelper

  def respond_weixin account, params
    case params["MsgType"]
    when "event"
      respond_event account, params
    when ""

    end
  end

  def respond_event account, params
    case params["Event"]
    when "CLICK", "VIEW"
      response_menu_event account, params
    when "subscribe"
      account.try(:weixin_welcome)
    end
  end

  def response_menu_event account, params
    case params["EventKey"]
    when "vip_card"
      format_resources_to_news account, account.vip_cards
    when "cleaning"
      format_resources_to_news account, account.cleanings
    when "mending"
      format_to_news ::Tips::Mending.model_name.human, 
        "点击查看#{::Tips::Mending.model_name.human}详细资料", 
        account.avatar, 
        "weixin/dealers/#{account.id}/mending"
    when "bulk_purchasing"
      format_resources_to_news account, account.bulk_purchasings
    when "activity"
      format_resources_to_news account, account.activities
    when "dealer_description"
      format_to_news "商家介绍", 
        account.description, 
        account.avatar, 
        "weixin/dealers/#{account.id}"
    when "mine"
      generate_mine
    end
  end

  def format_to_news title, description, image, url
    {
      news: {
        Title: title,
        Description: description,
        PicUrl: absolute_url(image.url(:medium)),
        Url: absolute_url(url)
      }
    }
  end

  def format_resources_to_news account, resources
    resource = resources.first
    format_to_news resource.class.model_name.human, 
      "点击查看#{resource.class.model_name.human}详细资料", 
      resource.image, 
      "weixin/dealers/#{account.id}/#{resource.class.name.demodulize.tableize}"
  end

  def initialize_weixin_account account
    Thread.new do
      sleep 5
      create_menu account, WeixinMenu if account.weixin_app_id
    end
  end

  def set_account
    params[:account] ||= ::Accounts::Account.find(params[:id])
  end

  def check_signature
    account = params[:account]
    token = account.weixin_token
    array = [token, params[:timestamp], params[:nonce]].sort
    params[:signature] == Digest::SHA1.hexdigest(array.join)
  end

  def access_token account
    # Rails.cache.fetch :access_token, expires_in: 1.hours do
      app_id = account.try(:weixin_app_id)
      app_secret = account.try(:weixin_app_secret)
      response = RestClient.get "https://api.weixin.qq.com/cgi-bin/token?grant_type=client_credential&appid=#{app_id}&secret=#{app_secret}"
      JSON.parse(response.to_str)["access_token"]
    # end
  end
  
  def create_menu account, menu=generate_menu(account)
    request_weixin account, 'menu/create', menu
  end

  def request_weixin account, command, data
    backup_escape = ActiveSupport::JSON::Encoding.escape_html_entities_in_json
    ActiveSupport::JSON::Encoding.escape_html_entities_in_json = false
    response = RestClient.post "https://api.weixin.qq.com/cgi-bin/#{command}?access_token=#{access_token(account)}", data.to_json
    ActiveSupport::JSON::Encoding.escape_html_entities_in_json = backup_escape
    response
  end

  def generate_menu account
    { 
      button: [{
        name: "项目菜单",
        sub_button: [{
          type: "click",
          name: "会员卡",
          key: "vip_card"
        }, {
          type: "click",
          name: "服务项目",
          key: "cleaning"
        }]
      }, {
        name: "发现",
        sub_button: [{
          type: "click",
          name: "近期团购",
          key: "bulk_purchasing"
        }, {
          type: "click",
          name: "近期活动",
          key: "activity"
        }]
      }, {
        name: "在下",
        sub_button: [{
          type: "click",
          name: "商家介绍",
          key: "dealer_description"
        }, {
          type: "view",
          name: "提醒服务",
          url: absolute_url("weixin/current_user/sales_cases?dealer_id=#{account.id}")
        }, {
          type: "view",
          name: "违章查询",
          url: "http://sms100.sinaapp.com/all/"
        }, {
          type: "view",
          name: "我的",
          url: absolute_url("weixin/current_user/mine?dealer_id=#{account.id}")
        }, {
          type: "view",
          name: "手机会员卡",
          url: "http://a.app.qq.com/o/simple.jsp?pkgname=com.kapp.net.carhall&g_f=991653"
        }]
      }]
    }
  end

  def generate_mine
    {
      news: [
        {
          Title: "个人资料",
          Description: "点击查看我的详细资料",
          PicUrl: absolute_url("weixin/current_user.png"),
          Url: absolute_url("weixin/current_user")
        }, {
          Title: "会员卡",
          Description: "点击查看我的会员卡详细资料",
          PicUrl: absolute_url("weixin/vip_cards.png"),
          Url: absolute_url("weixin/current_user/vip_card_orders")
        }, {
          Title: "消费记录",
          Description: "点击查看我的消费记录详细资料",
          PicUrl: absolute_url("weixin/operating_records.png"),
          Url: absolute_url("weixin/current_user/consumption_records")
        }
      ]
    }
  end

end